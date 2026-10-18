import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:image/image.dart' as img;

/// 幻听网验证码处理器
/// 自动处理幻听网的滑块验证码，实现自动搜索
class HuantingCaptchaHandler {
  final Dio _dio;
  final Logger _logger = Logger();
  
  static const String _baseUrl = 'https://www.huanting.cc';
  static const String _captchaInitUrl = '/api.php?c=XSV';
  static const String _captchaValidateUrl = '/api.php?c=XSV&a=XSValidation';
  static const String _searchUrl = '/Ps.php';
  
  String? _sessionCookie;

  String? get sessionCookie => _sessionCookie;

  HuantingCaptchaHandler({Dio? dio}) : _dio = dio ?? Dio();

  /// 执行搜索，自动处理验证码
  Future<String?> search(String keyword, Map<String, String>? headers) async {
    try {
      // 先尝试方案1：直接POST搜索，某些情况下可能不需要验证码
      final directResult = await _directSearch(keyword, headers);
      if (directResult != null && _isValidSearchResult(directResult)) {
        _logger.d('Direct search succeeded');
        return directResult;
      }

      _logger.d('Direct search failed, trying captcha flow');
      
      // 方案2：尝试验证码流程
      final captchaResult = await _tryCaptchaSearch(keyword, headers);
      if (captchaResult != null && _isValidSearchResult(captchaResult)) {
        return captchaResult;
      }
      
      // 方案3：从分类页面抓取书籍（验证码失败时的备用方案）
      _logger.d('Captcha failed, trying category page search');
      final categoryResult = await _searchFromCategories(keyword, headers);
      if (categoryResult != null) {
        _logger.d('Category page search succeeded');
        return categoryResult;
      }
      
      _logger.e('All search methods failed');
      return null;
    } catch (e) {
      _logger.e('HuantingCaptchaHandler search failed', error: e);
      return null;
    }
  }
  
  /// 尝试验证码搜索流程
  Future<String?> _tryCaptchaSearch(String keyword, Map<String, String>? headers) async {
    try {
      // 获取验证码数据并分析图片
      final captchaData = await _getCaptchaData(headers);
      if (captchaData == null) {
        _logger.e('Failed to get captcha data');
        return null;
      }
      
      // 分析图片获取基准位置
      final basePoint = await _calculateSlidePoint(captchaData, headers, 0);
      _logger.d('Image analysis base point: $basePoint');
      
      // 在基准位置附近小范围尝试
      final offsets = [0, -5, 5, -10, 10, -15, 15];
      
      for (int i = 0; i < offsets.length; i++) {
        final point = (basePoint ?? 160) + offsets[i];
        if (point <= 0 || point > 250) continue;
        
        _logger.d('Trying offset ${offsets[i]}, position: $point');
        
        // 每次尝试需要获取新的验证码（除了第一次）
        if (i > 0) {
          final newCaptcha = await _getCaptchaData(headers);
          if (newCaptcha == null) continue;
        }

        // 提交验证
        final validated = await _validateCaptcha(point, headers);
        if (validated) {
          _logger.d('Captcha validated successfully at position: $point');
          return await _postSearch(keyword, headers);
        }
        
        await Future.delayed(const Duration(milliseconds: 150));
      }
      
      return null;
    } catch (e) {
      _logger.e('Captcha search failed', error: e);
      return null;
    }
  }

  /// 尝试解锁会话（用于音频获取等非搜索场景）
  Future<bool> unlockSession(Map<String, String>? headers) async {
    try {
      // 获取验证码数据
      final captchaData = await _getCaptchaData(headers);
      if (captchaData == null) return false;
      
      // 分析图片获取基准位置
      final basePoint = await _calculateSlidePoint(captchaData, headers, 0);
      
      final offsets = [0, -5, 5, -10, 10, -15, 15];
      
      for (int i = 0; i < offsets.length; i++) {
        final point = (basePoint ?? 160) + offsets[i];
        if (point <= 0 || point > 250) continue;
        
        if (i > 0) {
          final newCaptcha = await _getCaptchaData(headers);
          if (newCaptcha == null) continue;
        }

        final validated = await _validateCaptcha(point, headers);
        if (validated) {
          _logger.d('Session unlocked successfully at position: $point');
          return true;
        }
        
        await Future.delayed(const Duration(milliseconds: 150));
      }
      return false;
    } catch (e) {
      _logger.e('Session unlock failed', error: e);
      return false;
    }
  }
  
  /// 从分类页面搜索书籍（通过关键词匹配书名）
  Future<String?> _searchFromCategories(String keyword, Map<String, String>? headers) async {
    try {
      // 主要分类列表
      final categories = [
        'xuanhuan',
        'dushi', 
        'kongbu',
        'xingzhen',
        'shangzhan',
        'junshi',
        'wangyou',
        'nvpin',
        'chuanyue',
        'shuangwen',
      ];
      
      final keywordLower = keyword.toLowerCase();
      
      // 遍历分类页面查找匹配的书籍
      for (final category in categories) {
        final url = '$_baseUrl/$category/';
        _logger.d('Searching category: $url');
        
        try {
          final response = await _dio.get<String>(
            url,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': '$_baseUrl/',
                ...?headers,
              },
            ),
          );
          
          if (response.data == null) continue;
          
          // 检查页面内容是否包含关键词
          if (response.data!.toLowerCase().contains(keywordLower)) {
            _logger.d('Found keyword in category: $category');
            // 返回这个分类页面的HTML，让source_parser来解析
            return response.data;
          }
        } catch (e) {
          _logger.d('Failed to fetch category $category: $e');
        }
        
        // 避免频繁请求
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // 如果没找到，返回第一个分类页面让用户浏览
      final defaultUrl = '$_baseUrl/xuanhuan/';
      final defaultResponse = await _dio.get<String>(
        defaultUrl,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': '$_baseUrl/',
            ...?headers,
          },
        ),
      );
      
      return defaultResponse.data;
    } catch (e) {
      _logger.e('Category search failed', error: e);
      return null;
    }
  }

  /// 直接POST搜索，不经过验证码
  Future<String?> _directSearch(String keyword, Map<String, String>? headers) async {
    try {
      final response = await _dio.post<String>(
        '$_baseUrl$_searchUrl',
        data: {'q': keyword},
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': '$_baseUrl/',
            ...?headers,
          },
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        // 检查是否返回了重定向URL
        try {
          final json = jsonDecode(response.data!);
          if (json is Map && json['location'] != null) {
            // 获取实际的搜索结果页面
            final resultUrl = _buildUrl(json['location']);
            final resultResponse = await _dio.get<String>(
              resultUrl,
              options: Options(
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Referer': '$_baseUrl/',
                  ...?headers,
                },
              ),
            );
            return resultResponse.data;
          }
        } catch (e) {
          // 可能直接返回HTML
          return response.data;
        }
      }
      return null;
    } catch (e) {
      _logger.d('Direct search error: $e');
      return null;
    }
  }

  /// 获取验证码初始数据
  Future<Map<String, dynamic>?> _getCaptchaData(Map<String, String>? headers) async {
    try {
      final response = await _dio.get<String>(
        '$_baseUrl$_captchaInitUrl',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': '$_baseUrl/',
            ...?headers,
          },
        ),
      );

      // 保存Cookie
      final cookies = response.headers['set-cookie'];
      if (cookies != null && cookies.isNotEmpty) {
        _sessionCookie = cookies.first.split(';').first;
        _logger.d('Got session cookie: $_sessionCookie');
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = jsonDecode(response.data!);
        _logger.d('Captcha data: $data');
        return data;
      }
      return null;
    } catch (e) {
      _logger.e('Get captcha data failed', error: e);
      return null;
    }
  }

  /// 分析验证码图片，计算滑块位移
  Future<int?> _calculateSlidePoint(
    Map<String, dynamic> captchaData, 
    Map<String, String>? headers,
    int attempt,
  ) async {
    try {
      final bgPic = captchaData['bg_pic'];
      final sliceData = captchaData['data'];
      final icoPic = captchaData['ico_pic'];
      final yPoint = captchaData['y_point'];
      
      if (bgPic == null) {
        _logger.e('No bg_pic in captcha data');
        return null;
      }

      _logger.d('Captcha data keys: ${captchaData.keys}');
      _logger.d('Slice data: $sliceData');
      _logger.d('Icon pic: $icoPic');
      _logger.d('Y point: $yPoint');

      // 尝试从ico_pic中获取滑块宽度
      int sliderWidth = 60;
      if (icoPic is Map) {
        sliderWidth = icoPic['w'] ?? 60;
      }
      _logger.d('Slider width: $sliderWidth');

      // 下载背景图片
      final bgUrl = _buildUrl(bgPic);
      final bgResponse = await _dio.get<List<int>>(
        bgUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': '$_baseUrl/',
            ...?headers,
          },
        ),
      );

      if (bgResponse.data == null) return null;

      // 尝试下载滑块图片来进行模板匹配
      String? icoUrl;
      if (icoPic is Map && icoPic['url'] != null) {
        icoUrl = _buildUrl(icoPic['url']);
      }
      
      Uint8List? sliderImageData;
      if (icoUrl != null) {
        try {
          final icoResponse = await _dio.get<List<int>>(
            icoUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': '$_baseUrl/',
                ...?headers,
              },
            ),
          );
          if (icoResponse.data != null) {
            sliderImageData = Uint8List.fromList(icoResponse.data!);
          }
        } catch (e) {
          _logger.d('Failed to download slider image: $e');
        }
      }

      // 图片是打乱的碎片，需要先还原
      final bgImageData = Uint8List.fromList(bgResponse.data!);
      final restoredImage = _restoreImage(bgImageData, sliceData);
      
      // 使用图像分析找出缺口位置
      final slidePoint = _findGapPosition(
        restoredImage ?? bgImageData,
        sliceData,
        attempt,
        sliderWidth,
        sliderImageData,
        yPoint is int ? yPoint : 60,
      );
      
      _logger.d('Calculated slide point: $slidePoint');
      return slidePoint;
    } catch (e) {
      _logger.e('Calculate slide point failed', error: e);
      return null;
    }
  }
  
  /// 尝试还原被打乱的图片
  Uint8List? _restoreImage(Uint8List imageData, dynamic sliceData) {
    try {
      if (sliceData == null || sliceData is! List) return null;
      
      final image = img.decodeImage(imageData);
      if (image == null) return null;
      
      final width = image.width;
      final height = image.height;
      
      // 创建新画布
      final restored = img.Image(width: width, height: height);
      
      // 根据data中的坐标信息还原图片
      // data格式: [[碎片1坐标...], [碎片2坐标...]]
      // 每个碎片坐标格式: [x, y]
      if (sliceData.length >= 2) {
        final topRow = sliceData[0] as List;
        final bottomRow = sliceData[1] as List;
        
        // 计算每个碎片的宽度
        final pieceWidth = width ~/ topRow.length;
        final pieceHeight = height ~/ 2;
        
        // 还原上半部分
        for (int i = 0; i < topRow.length; i++) {
          final coords = topRow[i] as List;
          final srcX = int.parse(coords[0].toString());
          final srcY = int.parse(coords[1].toString());
          
          // 从原图的srcX/srcY位置复制碎片到新图的指定位置
          for (int px = 0; px < pieceWidth && srcX + px < width; px++) {
            for (int py = 0; py < pieceHeight && srcY + py < height; py++) {
              final pixel = image.getPixel(srcX + px, srcY + py);
              if (i * pieceWidth + px < width) {
                restored.setPixel(i * pieceWidth + px, py, pixel);
              }
            }
          }
        }
        
        // 还原下半部分
        for (int i = 0; i < bottomRow.length; i++) {
          final coords = bottomRow[i] as List;
          final srcX = int.parse(coords[0].toString());
          final srcY = int.parse(coords[1].toString());
          
          for (int px = 0; px < pieceWidth && srcX + px < width; px++) {
            for (int py = 0; py < pieceHeight && srcY + py < height; py++) {
              final pixel = image.getPixel(srcX + px, srcY + py);
              if (i * pieceWidth + px < width && pieceHeight + py < height) {
                restored.setPixel(i * pieceWidth + px, pieceHeight + py, pixel);
              }
            }
          }
        }
      }
      
      _logger.d('Image restored successfully');
      return Uint8List.fromList(img.encodePng(restored));
    } catch (e) {
      _logger.e('Failed to restore image: $e');
      return null;
    }
  }

  /// 分析图片找出缺口位置
  int _findGapPosition(Uint8List imageData, dynamic sliceData, int attempt, int sliderWidth, Uint8List? sliderImageData, int yPoint) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        _logger.e('Failed to decode image');
        return 100;
      }

      final width = image.width;
      final height = image.height;
      
      _logger.d('Image size: ${width}x$height');

      // 如果有滑块图片，使用模板匹配
      if (sliderImageData != null) {
        final sliderImage = img.decodeImage(sliderImageData);
        if (sliderImage != null) {
          final matchX = _templateMatch(image, sliderImage, yPoint);
          if (matchX > 0) {
            _logger.d('Template match found at X: $matchX');
            final offsets = [-5, -3, 0, 3, 5];
            return matchX + offsets[attempt % offsets.length];
          }
        }
      }

      // 改进的缺口检测算法：寻找与背景对比明显的区域
      int bestX = width ~/ 2;
      double maxScore = 0;
      
      const int startX = 50;
      
      for (int x = startX; x < width - sliderWidth; x++) {
        double regionScore = 0;
        int edgeCount = 0;
        
        // Detect vertical edges within the y_point band
        // Gap is usually at y_point. We scan a bit wider range vertically.
        final int scanYStart = (yPoint - 10).clamp(0, height);
        final int scanYEnd = (yPoint + 50).clamp(0, height);
        
        for (int y = scanYStart; y < scanYEnd; y++) {
          if (x > 0) {
            final leftPixel = image.getPixel(x - 1, y);
            final rightPixel = image.getPixel(x, y);
            
            final leftBrightness = (leftPixel.r * 0.299 + leftPixel.g * 0.587 + leftPixel.b * 0.114);
            final rightBrightness = (rightPixel.r * 0.299 + rightPixel.g * 0.587 + rightPixel.b * 0.114);
            
            final diff = (leftBrightness - rightBrightness).abs();
            if (diff > 30) {
              edgeCount++;
              regionScore += diff;
            }
          }
        }
        
        // 同时检测是否有暗色区块（缺口阴影）
        int darkCount = 0;
        for (int dx = 0; dx < sliderWidth ~/ 2 && x + dx < width; dx++) {
          for (int dy = 0; dy < sliderWidth ~/ 2; dy++) {
            final py = yPoint + 10 + dy; // Check inside the gap area (approx y_point + offset)
            if (py < height) {
              final pixel = image.getPixel(x + dx, py);
              final brightness = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
              if (brightness < 80) darkCount++;
            }
          }
        }
        
        // 综合评分
        final combinedScore = regionScore + darkCount * 2;
        if (combinedScore > maxScore && edgeCount > 10) {
          maxScore = combinedScore;
          bestX = x;
        }
      }

      // 根据attempt添加偏移
      final offsets = [-8, -4, 0, 4, 8];
      final offset = offsets[attempt % offsets.length];
      
      final result = bestX + offset;
      _logger.d('Best X: $bestX, offset: $offset, final: $result');
      
      return result > 0 ? result : 80;
    } catch (e) {
      _logger.e('Gap detection failed', error: e);
      return 100;
    }
  }
  
  /// 简单的模板匹配
  int _templateMatch(img.Image background, img.Image template, int yPoint) {
    final bgWidth = background.width;
    final tplWidth = template.width;
    final tplHeight = template.height;
    
    double minDiff = double.infinity;
    int bestX = 0;
    
    // 只在中间区域搜索
    for (int x = 50; x < bgWidth - tplWidth; x += 2) {
      double diff = 0;
      int count = 0;
      
      for (int tx = 0; tx < tplWidth; tx += 3) {
        for (int ty = 0; ty < tplHeight; ty += 3) {
          final bgPixel = background.getPixel(x + tx, yPoint + ty);
          final tplPixel = template.getPixel(tx, ty);
          
          // 跳过透明像素
          if (tplPixel.a < 128) continue;
          
          diff += (bgPixel.r - tplPixel.r).abs() +
                  (bgPixel.g - tplPixel.g).abs() +
                  (bgPixel.b - tplPixel.b).abs();
          count++;
        }
      }
      
      if (count > 0 && diff / count < minDiff) {
        minDiff = diff / count;
        bestX = x;
      }
    }
    
    return bestX;
  }
  
  // 备用方案：当模板匹配失败时的边缘检测找缺口算法，暂未启用。
  // ignore: unused_element
  int _findGapByEdgeDetection(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    int maxEdgeX = 80;
    int maxEdgeDiff = 0;

    for (int x = 60; x < width - 60; x++) {
      int edgeScore = 0;
      
      for (int y = (height * 0.25).toInt(); y < (height * 0.75).toInt(); y++) {
        final leftPixel = image.getPixel(x - 1, y);
        final rightPixel = image.getPixel(x, y);
        
        final leftGray = (leftPixel.r * 0.299 + leftPixel.g * 0.587 + leftPixel.b * 0.114).toInt();
        final rightGray = (rightPixel.r * 0.299 + rightPixel.g * 0.587 + rightPixel.b * 0.114).toInt();
        
        edgeScore += (leftGray - rightGray).abs();
      }
      
      if (edgeScore > maxEdgeDiff) {
        maxEdgeDiff = edgeScore;
        maxEdgeX = x;
      }
    }
    
    return maxEdgeX;
  }

  /// 提交验证码验证
  Future<bool> _validateCaptcha(int point, Map<String, String>? headers) async {
    try {
      final requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '$_baseUrl/',
        ...?headers,
      };
      
      if (_sessionCookie != null) {
        requestHeaders['Cookie'] = _sessionCookie!;
      }

      final response = await _dio.post<String>(
        '$_baseUrl$_captchaValidateUrl',
        data: 'point=$point',
        options: Options(
          headers: requestHeaders,
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        try {
          final data = jsonDecode(response.data!);
          final state = data['state'];
          _logger.d('Validation response state: $state');
          return state == 0 || state == '0';
        } catch (e) {
          return false;
        }
      }
      return false;
    } catch (e) {
      _logger.e('Validate captcha failed', error: e);
      return false;
    }
  }

  /// 验证通过后POST搜索
  Future<String?> _postSearch(String keyword, Map<String, String>? headers) async {
    try {
      final requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': '$_baseUrl/',
        ...?headers,
      };
      
      if (_sessionCookie != null) {
        requestHeaders['Cookie'] = _sessionCookie!;
      }

      final response = await _dio.post<String>(
        '$_baseUrl$_searchUrl',
        data: 'q=${Uri.encodeComponent(keyword)}',
        options: Options(
          headers: requestHeaders,
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        try {
          final json = jsonDecode(response.data!);
          if (json is Map && json['location'] != null) {
            final resultUrl = _buildUrl(json['location']);
            _logger.d('Search result URL: $resultUrl');
            
            final resultResponse = await _dio.get<String>(
              resultUrl,
              options: Options(
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Referer': '$_baseUrl/',
                  'Cookie': _sessionCookie ?? '',
                  ...?headers,
                },
              ),
            );
            return resultResponse.data;
          }
        } catch (e) {
          return response.data;
        }
      }
      return null;
    } catch (e) {
      _logger.e('Post search failed', error: e);
      return null;
    }
  }

  /// 检查是否是有效的搜索结果
  bool _isValidSearchResult(String html) {
    return html.contains('div class="book"') || 
           html.contains('class="searchlist"') ||
           html.contains('search-result');
  }

  /// 构建完整URL
  String _buildUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return '$_baseUrl$path';
    }
    return '$_baseUrl/$path';
  }
}
