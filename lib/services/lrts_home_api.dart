import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edge_gate.dart';

/// 聆阅首页推荐流契约（2026-10-16 字节码 #18036 挖掘 + 实测）。
///
/// ```
/// GET {edge}/functions/v1/lrts-home
/// → { books: [推荐书], sections: [{ label, books: [...] }] }   // 15 个栏目
/// ```
///
/// 书字段：id/title/author/narrator/cover/rating/listeners/description。
/// 这是首页「图片驱动」的数据源（对应聆阅的精选焦点/恐怖专区等轮播）。
class LrtsHomeApi {
  LrtsHomeApi({
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

  /// 拉首页推荐流；限流/超时都按 [maxAttempts] 收口，绝不无限重试。
  Future<LrtsHomeData> fetchHome() {
    final g = gate ?? edgeGate;
    return g.run(() async {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(retryDelay);
        }
        try {
          final r = await _dio.get<String>(
            '$_fnBase/lrts-home',
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
          if (body == null) continue;
          if (body.contains('projectConcurrencyLimitExceeded')) continue;
          return parseHome(body);
        } catch (_) {
          // 重试
        }
      }
      return const LrtsHomeData.empty();
    });
  }

  /// 解析（独立方法便于 fixture 单测）。
  LrtsHomeData parseHome(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const LrtsHomeData.empty();
      return LrtsHomeData(
        books: _books(json['books']),
        sections: [
          if (json['sections'] is List)
            for (final s in (json['sections'] as List))
              if (s is Map)
                LrtsHomeSection(
                  label: '${s['label'] ?? ''}',
                  books: _books(s['books']),
                ),
        ],
      );
    } catch (_) {
      return const LrtsHomeData.empty();
    }
  }

  List<LrtsHomeBook> _books(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final b in raw)
        if (b is Map && '${b['id'] ?? ''}'.isNotEmpty)
          LrtsHomeBook(
            id: '${b['id']}',
            title: '${b['title'] ?? ''}',
            author: '${b['author'] ?? ''}',
            narrator: '${b['narrator'] ?? ''}',
            cover: '${b['cover'] ?? ''}',
            rating: b['rating'] is num ? (b['rating'] as num).toDouble() : null,
            listeners: '${b['listeners'] ?? ''}',
            description: '${b['description'] ?? ''}',
            category: (b['categories'] is List && (b['categories'] as List).isNotEmpty)
                ? '${(b['categories'] as List).first}'
                : '',
          ),
    ];
  }
}

/// 首页数据。
class LrtsHomeData {
  const LrtsHomeData({required this.books, required this.sections});
  const LrtsHomeData.empty() : books = const [], sections = const [];

  final List<LrtsHomeBook> books;
  final List<LrtsHomeSection> sections;

  bool get isEmpty => books.isEmpty && sections.isEmpty;
}

/// 首页栏目。
class LrtsHomeSection {
  const LrtsHomeSection({required this.label, required this.books});

  final String label;
  final List<LrtsHomeBook> books;
}

/// 首页推荐书。
class LrtsHomeBook {
  const LrtsHomeBook({
    required this.id,
    required this.title,
    required this.author,
    required this.narrator,
    required this.cover,
    this.rating,
    required this.listeners,
    required this.description,
    required this.category,
  });

  final String id;
  final String title;
  final String author;
  final String narrator;
  final String cover;
  final double? rating;
  final String listeners;
  final String description;
  final String category;
}

/// 首页数据 Provider（app 生命周期内缓存）。
final lrtsHomeProvider = FutureProvider<LrtsHomeData>(
    (ref) => LrtsHomeApi().fetchHome());
