import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edge_gate.dart';

import 'lrts_home_api.dart' show LrtsHomeBook;

/// 懒人听书分类书籍（聆阅字节码 #18053 双路契约，2026-10-16 实测）。
///
/// 主路 Edge：`GET {edge}/functions/v1/lrts-category?categoryId={id}`
///   → `{books:[{id,title,author,narrator,cover,rating,listeners,...}], total, page}`
/// 兜底直连：`GET https://www.lrts.me/book/category/{id}/20` 的 HTML 正则
///   `href="/book/(\d+)"[^>]*>\s*<img[^>]*alt="([^"]*)"[^>]*src="([^"]*)"`
///   （alt 形如「书名-作者」，聆阅按 `–`/`-` 切分）。
class LrtsCategoryApi {
  LrtsCategoryApi({
    Dio? dio,
    this.retryDelay = const Duration(milliseconds: 600),
    this.maxAttempts = 2,
    this.gate,
    this.timeout = const Duration(seconds: 8),
  }) : _dio = dio ?? Dio();

  final Dio _dio;

  /// 429 之后的重试间隔（测试注入 `Duration.zero`）。
  final Duration retryDelay;

  /// 总尝试次数（含首次）。
  final int maxAttempts;

  /// 串行闸门；`null` 时用全局 [edgeGate]。
  final EdgeGate? gate;

  /// 单次请求超时（裸 Dio 默认无限等）。
  final Duration timeout;

  static const String _fnBase =
      'https://backend.appmiaoda.com/projects/supabase345057433544081408/functions/v1';

  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhw'
      'IjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9'
      '.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc';

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36';

  /// 拉一页分类书籍（Edge 优先，直连 HTML 兜底）。
  Future<LrtsCategoryPage> fetch(String categoryId, {int page = 1}) async {
    final body = await _edgeGet('/lrts-category?categoryId=$categoryId&page=$page');
    if (body != null) {
      final parsed = parseEdgeResponse(body);
      if (parsed.books.isNotEmpty) return parsed;
    }
    // 兜底：直连 www.lrts.me（仅第一页有直连形态）
    if (page == 1) {
      try {
        final r = await _dio.get<String>(
          'https://www.lrts.me/book/category/$categoryId/20',
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (c) => c != null && c < 500,
            headers: const {
              'User-Agent': _userAgent,
              'Referer': 'https://www.lrts.me/',
            },
          ),
        );
        final html = r.data;
        if (html != null) {
          final books = parseDirectHtml(html);
          if (books.isNotEmpty) {
            return LrtsCategoryPage(books: books, total: books.length);
          }
        }
      } catch (_) {/* 兜底失败如实返回空 */}
    }
    return const LrtsCategoryPage(books: [], total: 0);
  }

  /// 解析 Edge 响应（独立方法便于 fixture 单测）。
  LrtsCategoryPage parseEdgeResponse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const LrtsCategoryPage(books: [], total: 0);
      final raw = json['books'];
      final books = <LrtsHomeBook>[];
      if (raw is List) {
        for (final b in raw) {
          if (b is! Map) continue;
          books.add(LrtsHomeBook(
            id: '${b['id'] ?? ''}',
            title: '${b['title'] ?? ''}',
            author: '${b['author'] ?? ''}',
            narrator: '${b['narrator'] ?? ''}',
            cover: '${b['cover'] ?? ''}',
            rating: b['rating'] is num ? (b['rating'] as num).toDouble() : null,
            listeners: '${b['listeners'] ?? ''}',
            description: '${b['description'] ?? ''}',
            category: (b['categories'] is List &&
                    (b['categories'] as List).isNotEmpty)
                ? '${(b['categories'] as List).first}'
                : '',
          ));
        }
      }
      return LrtsCategoryPage(
        books: books,
        total: (json['total'] as num?)?.toInt() ?? books.length,
      );
    } catch (_) {
      return const LrtsCategoryPage(books: [], total: 0);
    }
  }

  /// 解析直连分类页 HTML（聆阅 #18053 同款正则）。
  List<LrtsHomeBook> parseDirectHtml(String html) {
    final re = RegExp(
        r'href="/book/(\d+)"[^>]*>\s*<img[^>]*alt="([^"]*)"[^>]*src="([^"]*)"');
    final seen = <String>{};
    final out = <LrtsHomeBook>[];
    for (final m in re.allMatches(html)) {
      final id = m.group(1)!;
      if (!seen.add(id)) continue;
      final alt = m.group(2) ?? '';
      var cover = m.group(3) ?? '';
      if (cover.startsWith('//')) cover = 'https:$cover';
      if (cover.startsWith('http://')) {
        cover = 'https://${cover.substring(7)}';
      }
      // alt：书名–作者（聆阅按 – 切分）
      final parts = alt.split(RegExp(r'[–-]'));
      out.add(LrtsHomeBook(
        id: id,
        title: parts.first.trim(),
        author: parts.length > 1 ? parts[1].trim() : '',
        narrator: '',
        cover: cover,
        listeners: '',
        description: '',
        category: '',
      ));
    }
    return out;
  }

  Future<String?> _edgeGet(String path) {
    final g = gate ?? edgeGate;
    return g.run(() async {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(retryDelay);
        }
        try {
          final r = await _dio.get<String>(
            '$_fnBase$path',
            options: Options(
              responseType: ResponseType.plain,
              validateStatus: (c) => c != null && c < 600,
              headers: {
                'apikey': _anonKey,
                'Authorization': 'Bearer $_anonKey',
              },
              receiveTimeout: timeout,
              sendTimeout: timeout,
            ),
          );
          final body = r.data;
          if (body == null) return null;
          if (body.contains('projectConcurrencyLimitExceeded')) continue;
          return body;
        } catch (_) {
          // 重试
        }
      }
      return null;
    });
  }
}

/// 分类书籍分页结果。
class LrtsCategoryPage {
  final List<LrtsHomeBook> books;
  final int total;

  const LrtsCategoryPage({required this.books, required this.total});
}

/// Provider。
final lrtsCategoryApiProvider =
    Provider<LrtsCategoryApi>((ref) => LrtsCategoryApi());
