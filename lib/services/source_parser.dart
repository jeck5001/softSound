
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:json_path/json_path.dart';
import 'package:logger/logger.dart';

import '../data/models/source_rule.dart';
import '../theme/playback_settings.dart';
import '../data/models/book.dart';
import '../data/models/chapter.dart';
import 'js_executor.dart';
import 'huanting_captcha_handler.dart';
import 'typed_sources/typed_source_registry.dart';

/// 书源解析服务
/// 负责根据书源规则解析网页内容，获取书籍、章节、音频信息
class SourceParser {
  final Dio _dio;
  final Logger _logger = Logger();
  final JsExecutor _jsExecutor = JsExecutor();
  final HuantingCaptchaHandler _huantingHandler = HuantingCaptchaHandler();

  SourceParser({Dio? dio}) : _dio = dio ?? Dio();

  /// 根据书源规则搜索书籍
  Future<List<Book>> search(SourceRule source, String keyword) async {
    final typedAdapter = typedSourceRegistry.adapterFor(source.sourceId);
    if (typedAdapter != null) {
      return typedAdapter.search(source, keyword);
    }

    try {
      String? response;
      
      // 幻听网需要特殊处理验证码
      if (source.sourceId == 'huanting') {
        _logger.d('Using HuantingCaptchaHandler for search');
        response = await _huantingHandler.search(keyword, source.header);
      } else {
        final searchUrlPath = source.search.url.replaceAll('{{keyword}}', Uri.encodeComponent(keyword));
        final searchUrl = _buildUrl(source.sourceUrl, searchUrlPath);
        if (searchUrl == null) return [];

        response = await _request(
          searchUrl,
          method: source.search.method,
          body: source.search.body?.replaceAll('{{keyword}}', keyword),
          headers: source.header,
        );
      }

      if (response == null) return [];

      // Check for JSON
      if (source.search.bookList.startsWith('json:')) {
        try {
          final jsonData = jsonDecode(response);
          final bookElements = _queryJson(jsonData, source.search.bookList);

          final books = <Book>[];
          for (final element in bookElements) {
            final name = _parseJsonRule(element, source.search.bookName);
            final url = _parseJsonRule(element, source.search.bookUrl);

            if (name == null || url == null) continue;

            // For JSON sources like NetEase, the URL might be an ID. 
            // We can store it as detailUrl. 
            // If skipDetail is true, this URL (ID) is used directly for chapter/audio.
            final bookId = _generateBookId(source.sourceId, url);

            books.add(Book(
              bookId: bookId,
              sourceId: source.sourceId,
              name: name,
              author: _parseJsonRule(element, source.search.author),
              narrator: _parseJsonRule(element, source.search.narrator),
              coverUrl: _parseJsonRule(element, source.search.cover), // Usually direct URL in JSON
              intro: _parseJsonRule(element, source.search.intro),
              detailUrl: url, // Store original ID/URL
            ));
          }
          return books;
        } catch (e) {
            _logger.e('JSON search failed', error: e);
            return [];
        }
      }

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
    final typedAdapter = typedSourceRegistry.adapterFor(source.sourceId);
    if (typedAdapter != null) {
      return typedAdapter.getBookDetail(source, book);
    }

    // If skipDetail is true, we assume the book info from search is sufficient.
    // The chapter list will be generated based on the book info (likely single chapter).
    if (source.skipDetail) {
      return book;
    }

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
    final typedAdapter = typedSourceRegistry.adapterFor(source.sourceId);
    if (typedAdapter != null) {
      return typedAdapter.getChapterList(source, book);
    }

    // If skipDetail is true, return a single chapter using the book info
    if (source.skipDetail) {
      return [
        Chapter(
          chapterId: book.bookId,
          bookId: book.bookId,
          index: 0,
          name: book.name,
          url: book.detailUrl,
          isVip: false,
        ),
      ];
    }

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

  /// 获取章节字幕（LRC 文本）。仅 typed 适配器支持；JSON 规则源返回 null。
  ///
  /// 契约来源：聆阅字节码 #18026/#18028 —— `kuwo-play` 响应
  /// `{url, lyric, quality}`，`lyric` 为 LRC 文本。
  Future<String?> getLyric(SourceRule source, Chapter chapter) async {
    final typedAdapter = typedSourceRegistry.adapterFor(source.sourceId);
    if (typedAdapter == null) return null;
    return typedAdapter.getLyric(source, chapter);
  }

  /// 获取音频URL
  ///
  /// [quality] 为可选音质偏好，会透传给支持音质选择的适配器
  /// （如酷我按 br 参数切换码率）；不支持者忽略。
  Future<String?> getAudioUrl(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  }) async {
    final typedAdapter = typedSourceRegistry.adapterFor(source.sourceId);
    if (typedAdapter != null) {
      return typedAdapter.getAudioUrl(source, chapter, quality: quality);
    }

    try {
      String? audioUrl;

      final chapterFullUrl = _buildUrl(source.sourceUrl, chapter.url) ?? chapter.url;

      // 构建请求头，支持动态Referer
      Map<String, String> requestHeaders = {
        ...?source.header,
      };
      if (source.audio.header != null) {
        source.audio.header!.forEach((key, value) {
          if (value.contains('{{chapterUrl}}')) {
            requestHeaders[key] = value.replaceAll('{{chapterUrl}}', chapterFullUrl);
          } else {
            requestHeaders[key] = value;
          }
        });
      }

      String requestUrl = chapterFullUrl;
      
      // 当 audioUrl 规则是 'api' 时，需要先请求章节页面获取 meta 参数
      // 所以不要将 requestUrl 替换为 API URL
      final audioRule = source.audio.audioUrl;
      if (audioRule != 'api' && source.audio.apiUrl != null && source.audio.apiUrl!.isNotEmpty) {
        String apiUrl = source.audio.apiUrl!;
        if (apiUrl.contains('{{bookId}}')) {
             apiUrl = apiUrl.replaceAll('{{bookId}}', chapter.url);
        }
        requestUrl = _buildUrl(source.sourceUrl, apiUrl) ?? requestUrl;

        // 对于iframe类型的API（如幻听网的PTaudio2.php），使用章节URL作为Referer
        if (!requestHeaders.containsKey('Referer') || 
            requestHeaders['Referer'] == source.sourceUrl ||
            requestHeaders['Referer'] == '${source.sourceUrl}/') {
          requestHeaders['Referer'] = chapterFullUrl;
        }
      }

      // Check if we need WebView for JS-based audio extraction
      if (source.audio.audioUrl.startsWith('js:')) {
        // Will be handled below in the main audioUrl extraction
      } else if (source.audio.apiUrl != null && source.audio.apiResponseRule != null && source.audio.apiResponseRule!.startsWith('js:')) {
         // Only use WebView if the response rule explicitly requires JS execution
         _logger.d('Using WebView for JS-based API response rule');
         audioUrl = await _jsExecutor.fetchAudioUrlInWebView(
           pageUrl: chapter.url,
           apiEndpoint: source.audio.apiUrl!,
           apiMethod: source.audio.apiMethod,
           apiBody: source.audio.apiBody,
           apiHeader: source.audio.apiHeader,
           apiResponseRule: source.audio.apiResponseRule,
           headers: source.header,
         );
         if (audioUrl != null) return _buildUrl(source.sourceUrl, audioUrl);
      }

      _logger.d('Requesting audio from: $requestUrl');
      _logger.d('With headers: $requestHeaders');

      final response = await _request(
        requestUrl,
        headers: requestHeaders,
      );

      if (response == null) return null;


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

      if (audioUrl == null) {
        if (source.sourceId == 'huanting') {
          _logger.d('Huanting audio extraction failed, trying to unlock session...');
          final unlocked = await _huantingHandler.unlockSession(source.header);
          if (unlocked) {
            _logger.d('Session unlocked, retrying audio request...');
            if (_huantingHandler.sessionCookie != null) {
              requestHeaders['Cookie'] = _huantingHandler.sessionCookie!;
              
              final retriedResponse = await _request(
                requestUrl,
                headers: requestHeaders,
              );
              
              if (retriedResponse != null) {
                 if (audioRule == 'api') {
                   audioUrl = await _getAudioUrlFromApi(source, retriedResponse);
                 } else if (!audioRule.startsWith('js:')) {
                   audioUrl = _parseAudioUrl(retriedResponse, audioRule);
                 }
              }
            }
          }
        }
        
        if (audioUrl == null) return null;
      }

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

      _logger.d('Extracted values: $metaValues');

      if (source.audio.apiUrl == null) return null;
      String apiUrl = _buildUrl(source.sourceUrl, source.audio.apiUrl!)!;
      
      String? body = source.audio.apiBody;
      _logger.d('Original API Body template: $body');
      if (body != null) {
        metaValues.forEach((key, value) {
          body = body!.replaceAll('{{$key}}', value);
        });
      }

      _logger.d('API URL: $apiUrl, body: $body');

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
          String? audioUrl = jsonData[responseRule]?.toString();
          
          if (audioUrl == null || audioUrl.isEmpty) {
            for (final key in ['url', 'ourl', 'plink', 'play_url', 'audioUrl', 'audio_url', 'src', 'mp3']) {
              final val = jsonData[key]?.toString();
              if (val != null && val.isNotEmpty) {
                audioUrl = val;
                _logger.d('Found audio URL in fallback key "$key": $audioUrl');
                break;
              }
            }
          }
          
          _logger.d('Extracted audio URL: $audioUrl');
          if (audioUrl != null && audioUrl.isNotEmpty) {
            return audioUrl;
          }
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
  String? _parseAudioUrl(String content, String rule) {
    if (rule.startsWith('css:')) {
      final document = html_parser.parse(content);
      return _parseCssRule(document.documentElement!, rule.substring(4));
    } else if (rule.startsWith('regex:')) {
      return _parseRegexRule(content, rule.substring(6));
    } else if (rule.startsWith('json:')) {
       try {
         final json = jsonDecode(content);
         return _parseJsonRule(json, rule);
       } catch (e) {
         _logger.w('JSON parse failed in parseAudioUrl', error: e);
         return null;
       }
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

  /// 查询JSON路径
  List<dynamic> _queryJson(dynamic json, String rule) {
    if (json == null || rule.isEmpty) return [];

    String path = rule;
    if (path.startsWith('json:')) {
      path = path.substring(5);
    }
    
    // If path is just $, return the root object in a list
    if (path == r'$') {
      return [json];
    }

    try {
      final matches = JsonPath(path).read(json);
      return matches.map((match) => match.value).toList();
    } catch (e) {
      _logger.w('JSON Path query failed: $path', error: e);
      return [];
    }
  }

  /// 解析JSON规则
  String? _parseJsonRule(dynamic element, String? rule) {
    if (element == null || rule == null || rule.isEmpty) return null;

    String path = rule;
    if (path.startsWith('json:')) {
      path = path.substring(5);
    }
    
    // If the path is just "$", return the element itself (if it's a primitive or we want to convert to string)
    if (path == r'$') {
      return element.toString();
    }

    try {
      // If the element is a Map, we can query it
      if (element is Map || element is List) {
         final matches = JsonPath(path).read(element);
         if (matches.isNotEmpty) {
           final value = matches.first.value;
           return value?.toString();
         }
      }
      return null;
    } catch (e) {
      // _logger.w('JSON Path parse failed: $path', error: e);
      return null;
    }
  }
}
