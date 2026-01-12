import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';

/// JavaScript 执行服务
/// 使用隐藏的 WebView 执行 JavaScript 代码获取动态内容
class JsExecutor {
  static final JsExecutor _instance = JsExecutor._internal();
  factory JsExecutor() => _instance;
  JsExecutor._internal();

  final Logger _logger = Logger();
  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _webViewController;
  bool _isReady = false;
  Completer<void>? _loadCompleter;

  /// 初始化 WebView
  Future<void> init() async {
    if (_isReady) return;
    if (kIsWeb) {
      _logger.w('JsExecutor is not supported on web platform');
      return;
    }

    final readyCompleter = Completer<void>();

    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('about:blank')),
      initialSettings: InAppWebViewSettings(
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        javaScriptEnabled: true,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _isReady = true;
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
      },
      onLoadStop: (controller, url) {
        if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
          _loadCompleter!.complete();
        }
      },
    );

    await _headlessWebView!.run();
    await readyCompleter.future;
  }

  /// 加载页面并执行 JavaScript
  Future<String?> executeJs({
    required String url,
    required String jsCode,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kIsWeb) {
      _logger.w('JsExecutor is not supported on web platform');
      return null;
    }

    if (!_isReady) {
      await init();
    }

    if (_webViewController == null) {
      _logger.e('WebViewController is not ready');
      return null;
    }

    try {
      _loadCompleter = Completer<void>();

      await _webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(url),
          headers: headers,
        ),
      );

      await _loadCompleter!.future.timeout(timeout);

      await Future.delayed(const Duration(milliseconds: 500));

      final result = await _webViewController!.evaluateJavascript(source: jsCode);

      return result?.toString();
    } catch (e) {
      _logger.e('Execute JS failed', error: e);
      return null;
    }
  }

  /// 从页面 HTML 中执行 JavaScript 获取音频地址
  Future<String?> getAudioUrlByJs({
    required String pageUrl,
    required String jsCode,
    Map<String, String>? headers,
  }) async {
    final result = await executeJs(
      url: pageUrl,
      jsCode: '''
        (function() {
          try {
            $jsCode
          } catch(e) {
            return null;
          }
        })()
      ''',
      headers: headers,
    );

    if (result != null && result != 'null' && result.isNotEmpty) {
      String audioUrl = result.replaceAll('"', '').replaceAll("'", '');
      return audioUrl;
    }
    return null;
  }

  /// 使用 WebView 在页面内执行 AJAX 请求获取音频地址
  /// 这可以绕过服务器的反爬检测
  Future<String?> fetchAudioUrlInWebView({
    required String pageUrl,
    required String apiEndpoint,
    String? apiMethod,
    String? apiBody,
    Map<String, String>? apiHeader,
    String? apiResponseRule,
    Map<String, String>? headers,
  }) async {
    if (kIsWeb) {
      _logger.w('JsExecutor is not supported on web platform');
      return null;
    }

    if (!_isReady) {
      await init();
    }

    if (_webViewController == null) {
      _logger.e('WebViewController is not ready');
      return null;
    }

    try {
      _loadCompleter = Completer<void>();

      _logger.d('Loading page in WebView: $pageUrl');

      await _webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(pageUrl),
          headers: headers,
        ),
      );

      await _loadCompleter!.future.timeout(const Duration(seconds: 15));

      await Future.delayed(const Duration(milliseconds: 2000));
      
      _logger.d('Page loaded, now executing JavaScript...');

      final jsCode = '''
        (function() {
          var b = document.querySelector("meta[name='_b']");
          var c = document.querySelector("meta[name='_c']");
          var cp = document.querySelector("meta[name='_cp']");
          var p = document.querySelector("meta[name='_p']");
          var l = document.querySelector("meta[name='_l']");
          
          if (!b || !c || !cp) {
            return JSON.stringify({error: 'Missing meta tags', found: {b: !!b, c: !!c, cp: !!cp}});
          }
          
          var bVal = b.getAttribute('content');
          var cVal = c.getAttribute('content');
          var cpVal = cp.getAttribute('content');
          var pVal = p ? p.getAttribute('content') : '0';
          var lVal = l ? l.getAttribute('content') : '1';
          
          return JSON.stringify({
            b: bVal,
            c: cVal,
            cp: cpVal,
            p: pVal,
            l: lVal
          });
        })()
      ''';

      final metaResult = await _webViewController!.evaluateJavascript(source: jsCode);
      _logger.d('Meta tags result: $metaResult');

      if (metaResult == null || metaResult == 'null') {
        _logger.e('Failed to get meta tags');
        return null;
      }

      String metaStr = metaResult.toString();
      if (metaStr.startsWith('"') && metaStr.endsWith('"')) {
        metaStr = metaStr.substring(1, metaStr.length - 1);
        metaStr = metaStr.replaceAll(r'\"', '"');
      }

      final metaData = jsonDecode(metaStr) as Map<String, dynamic>;
      
      // 提取所有变量，增加兼容性
      final Map<String, String> variables = {};
      metaData.forEach((key, value) {
        final val = value.toString();
        variables[key] = val;
        if (key.startsWith('_')) {
          variables[key.substring(1)] = val;
        } else {
          variables['_${key}'] = val;
        }
      });

      String getValue(String key) {
        return variables[key] ?? '';
      }

      // 处理请求体模板
      String processedBody = apiBody ?? '';
      variables.forEach((key, value) {
        processedBody = processedBody.replaceAll('{{$key}}', value);
      });

      // 处理请求头模板
      final Map<String, String> processedHeaders = {
        'X-Requested-With': 'XMLHttpRequest',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Referer': pageUrl,
      };

      if (apiHeader != null) {
        apiHeader.forEach((key, value) {
          String val = value;
          variables.forEach((vKey, vValue) {
            val = val.replaceAll('{{$vKey}}', vValue);
          });
          processedHeaders[key] = val;
        });
      }

      final fetchJsCode = '''
        window._audioResult = null;
        window._audioError = null;
        fetch('$apiEndpoint', {
          method: '${apiMethod ?? 'POST'}',
          credentials: 'include',
          headers: ${jsonEncode(processedHeaders)},
          body: '$processedBody'
        })
        .then(function(response) {
          if (!response.ok) {
            window._audioError = 'HTTP ' + response.status + ': ' + response.statusText;
            return null;
          }
          return response.text();
        })
        .then(function(text) {
          if (text) {
            try {
              var data = JSON.parse(text);
              window._audioResult = JSON.stringify(data);
            } catch(e) {
              window._audioError = 'Parse error: ' + text.substring(0, 200);
            }
          }
        })
        .catch(function(error) { window._audioError = error.toString(); });
        'started';
      ''';

      await _webViewController!.evaluateJavascript(source: fetchJsCode);
      _logger.d('Fetch started, waiting for result...');

      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
        
        final checkResult = await _webViewController!.evaluateJavascript(
          source: 'window._audioResult || window._audioError || null'
        );
        
        if (checkResult != null && checkResult != 'null') {
          _logger.d('Got result: $checkResult');
          
          String jsonStr = checkResult.toString();
          if (jsonStr.startsWith('"') && jsonStr.endsWith('"')) {
            jsonStr = jsonStr.substring(1, jsonStr.length - 1);
            jsonStr = jsonStr.replaceAll(r'\"', '"');
            jsonStr = jsonStr.replaceAll(r'\/', '/');
          }
          
          _logger.d('Parsed JSON: $jsonStr');
          
          final String respRule = apiResponseRule ?? 'url';
          final regex = RegExp('"$respRule"\\s*:\\s*"([^"]+)"');
          var match = regex.firstMatch(jsonStr);
          
          if (match != null && match.group(1)!.isNotEmpty) {
            var audioUrl = match.group(1)!;
            if (audioUrl.startsWith('//')) {
              audioUrl = 'http:$audioUrl';
            }
            _logger.d('Extracted audio URL: $audioUrl');
            return audioUrl;
          }
          break;
        }
      }
      
      _logger.d('API returned empty URL, trying fallback methods...');
      
      final fallbackJsCode = '''
        (function() {
          var audio = document.querySelector('audio');
          if (audio && audio.src) {
            return audio.src;
          }
          
          if (typeof window.audio_info !== 'undefined' && window.audio_info && window.audio_info.url) {
            return window.audio_info.url;
          }
          
          if (typeof window.xf !== 'undefined' && window.xf && window.xf.url) {
            return window.xf.url;
          }
          
          var scripts = document.querySelectorAll('script');
          for (var i = 0; i < scripts.length; i++) {
            var text = scripts[i].textContent || '';
            var urlMatch = text.match(/"url"\\s*:\\s*"(https?:\\/\\/[^"]+\\.m4a)"/);
            if (urlMatch) {
              return urlMatch[1];
            }
            urlMatch = text.match(/src\\s*[:=]\\s*["'](https?:\\/\\/[^"']+\\.m4a)["']/);
            if (urlMatch) {
              return urlMatch[1];
            }
          }
          
          return null;
        })()
      ''';
      
      final fallbackResult = await _webViewController!.evaluateJavascript(source: fallbackJsCode);
      _logger.d('Fallback result: $fallbackResult');
      
      if (fallbackResult != null && fallbackResult != 'null') {
        String audioUrl = fallbackResult.toString();
        if (audioUrl.startsWith('"') && audioUrl.endsWith('"')) {
          audioUrl = audioUrl.substring(1, audioUrl.length - 1);
        }
        if (audioUrl.isNotEmpty && (audioUrl.contains('.m4a') || audioUrl.contains('.mp3'))) {
          _logger.d('Got audio URL from fallback: $audioUrl');
          return audioUrl;
        }
      }
      
      _logger.e('Fetch timeout or no result');
      return null;
    } catch (e) {
      _logger.e('Fetch audio URL in WebView failed', error: e);
      return null;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _headlessWebView?.dispose();
    _headlessWebView = null;
    _webViewController = null;
    _isReady = false;
  }
}
