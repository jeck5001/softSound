
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:logger/logger.dart';

import '../data/models/source_rule.dart';
import '../data/models/book.dart';
import '../data/models/chapter.dart';
import 'js_executor.dart';

/// 书源解析服务
/// 负责根据书源规则解析网页内容，获取书籍、章节、音频信息
class SourceParser {
  final Dio _dio;
  final Logger _logger = Logger();
  final JsExecutor _jsExecutor = JsExecutor();

  SourceParser({Dio? dio}) : _dio = dio ?? Dio();

  /// 根据书源规则搜索书籍
  Future<List<Book>> search(SourceRule source, String keyword) async {
    try {
      final searchUrlPath = source.search.url.replaceAll('{{keyword}}', Uri.encodeComponent(keyword));
      final searchUrl = _buildUrl(source.sourceUrl, searchUrlPath);
      if (searchUrl == null) return [];

      final response = await _request(
        searchUrl,
        method: source.search.method,
        body: source.search.body?.replaceAll('{{keyword}}', keyword),
        headers: source.header,
      );

      if (response == null) return [];

      final document = html_parser.parse(response);
      final bookElements = _querySelectorAll(document, source.search.bookList);

      final books = <Book>[];
      for (final element in bookElements) {
        final name = _parseRule(element, source.search.bookName);
        final url = _parseRule(element, source.search.bookUrl);

        if (name == null || url == null) continue;

        final fullUrl = _buildUrl(source.sourceUrl, url);
        if (fullUrl == null) continue;
        final bookId = _generateBookId(source.sourceId, fullUrl);

        books.add(Book(
          bookId: bookId,
          sourceId: source.sourceId,
          name: name,
          author: _parseRule(element, source.search.author),
          narrator: _parseRule(element, source.search.narrator),
          coverUrl: _buildUrl(source.sourceUrl, _parseRule(element, source.search.cover)),
          intro: _parseRule(element, source.search.intro),
          detailUrl: fullUrl,
        ));
      }

      return books;
    } catch (e) {
      _logger.e('Search failed', error: e);
      return [];
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookDetail(SourceRule source, Book book) async {
    try {
      final response = await _request(
        book.detailUrl,
        headers: source.header,
      );

      if (response == null) return null;

      final document = html_parser.parse(response);

      return book.copyWith(
        name: _parseRule(document.documentElement, source.detail.bookName) ?? book.name,
        author: _parseRule(document.documentElement, source.detail.author) ?? book.author,
        narrator: _parseRule(document.documentElement, source.detail.narrator) ?? book.narrator,
        coverUrl: _buildUrl(source.sourceUrl, _parseRule(document.documentElement, source.detail.cover)) ?? book.coverUrl,
        intro: _parseRule(document.documentElement, source.detail.intro) ?? book.intro,
      );
    } catch (e) {
      _logger.e('Get book detail failed', error: e);
      return null;
    }
  }

  /// 获取章节列表
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    try {
      String detailUrl = book.detailUrl;
      if (source.detail.chapterListUrl != null && source.detail.chapterListUrl!.isNotEmpty) {
        final chapterListUrl = _buildUrl(source.sourceUrl, source.detail.chapterListUrl!);
        if (chapterListUrl != null) {
          detailUrl = chapterListUrl;
        }
      }

      final response = await _request(
        detailUrl,
        headers: source.header,
      );

      if (response == null) return [];

      final document = html_parser.parse(response);
      final chapterElements = _querySelectorAll(document, source.detail.chapterList);

      final chapters = <Chapter>[];
      for (int i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final name = _parseRule(element, source.chapter.chapterName);
        final url = _parseRule(element, source.chapter.chapterUrl);

        if (name == null || url == null) continue;

        final fullUrl = _buildUrl(source.sourceUrl, url);
        if (fullUrl == null) continue;
        final chapterId = _generateChapterId(book.bookId, i);

        chapters.add(Chapter(
          chapterId: chapterId,
          bookId: book.bookId,
          index: i,
          name: name,
          url: fullUrl,
          isVip: _parseRule(element, source.chapter.isVip) == 'true',
        ));
      }

      return chapters;
    } catch (e) {
      _logger.e('Get chapter list failed', error: e);
      return [];
    }
  }

  /// 获取音频URL
  Future<String?> getAudioUrl(SourceRule source, Chapter chapter) async {
    try {
      String? audioUrl;

      if (source.audio.apiUrl != null && source.audio.apiUrl!.isNotEmpty) {
        _logger.d('Using WebView to fetch audio URL for: ${chapter.url}');
        audioUrl = await _jsExecutor.fetchAudioUrlInWebView(
          pageUrl: chapter.url,
          apiEndpoint: source.audio.apiUrl!,
          apiMethod: source.audio.apiMethod,
          apiBody: source.audio.apiBody,
          apiHeader: source.audio.apiHeader,
          apiResponseRule: source.audio.apiResponseRule,
          headers: source.header,
        );
        
        if (audioUrl != null) {
          _logger.d('Got audio URL from WebView: $audioUrl');
          if (audioUrl.startsWith('//')) {
            audioUrl = 'http:$audioUrl';
          }
          return audioUrl;
        }
      }

      final response = await _request(
        chapter.url,
        headers: source.header,
      );

      if (response == null) return null;

      final audioRule = source.audio.audioUrl;
      if (audioRule.startsWith('js:')) {
        audioUrl = await _parseJsAudioUrl(
          chapter.url,
          audioRule.substring(3),
          source.header,
        );
      } else if (audioRule == 'api') {
        audioUrl = await _getAudioUrlFromApi(source, response);
      } else {
        audioUrl = _parseAudioUrl(response, audioRule);
      }

      if (audioUrl == null) return null;

      if (audioUrl.startsWith('//')) {
        audioUrl = 'http:$audioUrl';
      }

      return _buildUrl(source.sourceUrl, audioUrl);
    } catch (e) {
      _logger.e('Get audio url failed', error: e);
      return null;
    }
  }

  /// 从动态接口获取音频地址
  Future<String?> _getAudioUrlFromApi(SourceRule source, String pageHtml) async {
    try {
      final document = html_parser.parse(pageHtml);
      final metaTags = document.querySelectorAll('meta');
      
      final metaValues = <String, String>{};
      
      // 1. 从 meta 标签提取
      for (final meta in metaTags) {
        final name = meta.attributes['name'] ?? meta.attributes['property'];
        final content = meta.attributes['content'];
        if (name != null && content != null) {
          metaValues[name] = content;
          // 同时存入去掉前缀或带下划线的版本以增加兼容性
          if (name.startsWith('_')) {
            metaValues[name.substring(1)] = content;
          } else {
            metaValues['_$name'] = content;
          }
        }
      }

      // 2. 从 HTML 源码中提取变量 (针对一些直接卸载脚本里的变量)
      // 常见的模式如 var _b = "xxx"; 或 window._c = "yyy";
      final variableRegex = RegExp(r'(?:var|window|let|const)\s+(_?[a-zA-Z0-9]+)\s*=\s*["'']([^"'']+)["'']');
      final matches = variableRegex.allMatches(pageHtml);
      for (final match in matches) {
        final key = match.group(1);
        final value = match.group(2);
        if (key != null && value != null) {
          metaValues[key] = value;
          if (key.startsWith('_')) {
            metaValues[key.substring(1)] = value;
          } else {
            metaValues['_$key'] = value;
          }
        }
      }

      _logger.d('Extracted values: ${metaValues.keys.join(', ')}');

      if (source.audio.apiUrl == null) return null;
      String apiUrl = _buildUrl(source.sourceUrl, source.audio.apiUrl!)!;
      
      String? body = source.audio.apiBody;
      if (body != null) {
        metaValues.forEach((key, value) {
          body = body!.replaceAll('{{$key}}', value);
        });
      }

      _logger.d('API URL: $apiUrl');
      _logger.d('API Body: $body');

      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '${source.sourceUrl}/',
        ...?source.header,
      };

      if (source.audio.apiHeader != null) {
        source.audio.apiHeader!.forEach((key, value) {
          String headerValue = value;
          metaValues.forEach((metaKey, metaValue) {
            headerValue = headerValue.replaceAll('{{$metaKey}}', metaValue);
          });
          headers[key] = headerValue;
        });
      }

      _logger.d('API Headers: $headers');

      final apiResponse = await _request(
        apiUrl,
        method: source.audio.apiMethod ?? 'POST',
        body: body,
        headers: headers,
      );

      if (apiResponse == null) {
        _logger.e('API response is null');
        return null;
      }

      _logger.d('API Response: ${apiResponse.substring(0, apiResponse.length > 200 ? 200 : apiResponse.length)}');

      final responseRule = source.audio.apiResponseRule ?? 'ourl';
      
      try {
        final jsonData = jsonDecode(apiResponse);
        if (jsonData is Map) {
          final audioUrl = jsonData[responseRule]?.toString();
          _logger.d('Extracted audio URL: $audioUrl');
          return audioUrl;
        }
      } catch (e) {
        _logger.d('JSON parse failed, trying regex');
        final regex = RegExp('"$responseRule"\\s*:\\s*"([^"]+)"');
        final match = regex.firstMatch(apiResponse);
        if (match != null) {
          final audioUrl = match.group(1);
          _logger.d('Regex extracted audio URL: $audioUrl');
          return audioUrl;
        }
      }

      _logger.e('Could not extract audio URL from response');
      return null;
    } catch (e) {
      _logger.e('Get audio url from API failed', error: e);
      return null;
    }
  }

  /// 使用 JS 解析音频地址
  Future<String?> _parseJsAudioUrl(
    String pageUrl,
    String jsCode,
    Map<String, String>? headers,
  ) async {
    return await _jsExecutor.getAudioUrlByJs(
      pageUrl: pageUrl,
      jsCode: jsCode,
      headers: headers,
    );
  }

  /// 发送HTTP请求
  Future<String?> _request(
    String url, {
    String method = 'GET',
    String? body,
    Map<String, String>? headers,
  }) async {
    try {
      String? contentType;
      if (headers != null && headers.containsKey('Content-Type')) {
        contentType = headers['Content-Type'];
      }

      final options = Options(
        method: method,
        contentType: contentType,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          ...?headers,
        },
      );

      _logger.d('Request: $method $url');
      _logger.d('Headers: ${options.headers}');
      if (body != null) {
        _logger.d('Body: $body');
      }

      final response = await _dio.request<String>(
        url,
        data: body,
        options: options,
      );

      _logger.d('Response status: ${response.statusCode}');
      _logger.d('Response data length: ${response.data?.length ?? 0}');

      return response.data;
    } catch (e) {
      _logger.e('Request failed: $url', error: e);
      return null;
    }
  }

  /// 根据规则解析内容
  String? _parseRule(Element? element, String? rule) {
    if (element == null || rule == null || rule.isEmpty) return null;

    if (rule.startsWith('css:')) {
      return _parseCssRule(element, rule.substring(4));
    } else if (rule.startsWith('regex:')) {
      return _parseRegexRule(element.outerHtml, rule.substring(6));
    } else if (rule.startsWith('js:')) {
      _logger.w('JS rules not yet implemented');
      return null;
    } else {
      return _parseCssRule(element, rule);
    }
  }

  /// 解析CSS选择器规则
  String? _parseCssRule(Element element, String rule) {
    final parts = rule.split('@');
    final selector = parts[0].trim();
    final attr = parts.length > 1 ? parts[1].trim() : 'text';

    Element? target = element;
    if (selector.isNotEmpty) {
      target = element.querySelector(selector);
    }

    if (target == null) return null;

    switch (attr) {
      case 'text':
        return target.text.trim();
      case 'html':
        return target.innerHtml;
      case 'outerHtml':
        return target.outerHtml;
      default:
        return target.attributes[attr]?.trim();
    }
  }

  /// 解析正则表达式规则
  String? _parseRegexRule(String content, String pattern) {
    final regex = RegExp(pattern);
    final match = regex.firstMatch(content);
    return match?.group(1);
  }

  /// 解析音频URL
  String? _parseAudioUrl(String html, String rule) {
    if (rule.startsWith('css:')) {
      final document = html_parser.parse(html);
      return _parseCssRule(document.documentElement!, rule.substring(4));
    } else if (rule.startsWith('regex:')) {
      return _parseRegexRule(html, rule.substring(6));
    } else if (rule.startsWith('js:')) {
      _logger.w('JS rules require WebView, not yet implemented');
      return null;
    }
    return null;
  }

  /// 查询所有匹配元素
  List<Element> _querySelectorAll(Document document, String? rule) {
    if (rule == null || rule.isEmpty) return [];

    String selector = rule;
    if (selector.startsWith('css:')) {
      selector = selector.substring(4);
    }

    return document.querySelectorAll(selector);
  }

  /// 构建完整URL
  String? _buildUrl(String baseUrl, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$path';
    }
    return '$baseUrl/$path';
  }

  /// 生成书籍ID
  String _generateBookId(String sourceId, String url) {
    final hash = url.hashCode.toRadixString(16);
    return '${sourceId}_$hash';
  }

  /// 生成章节ID
  String _generateChapterId(String bookId, int index) {
    return '${bookId}_$index';
  }
}
