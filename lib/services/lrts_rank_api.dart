import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kuwo_rank_api.dart' show KuwoRankBook;

/// 懒人听书（lrts）排行榜 —— 契约来自 2026-10-16 对聆阅 Hermes 字节码的
/// 深挖（Function #18082），并用真实请求验证：
///
/// ```
/// GET {edge}/functions/v1/lrts-rank?rankId={id}&rangeType={t}
///   headers: apikey / Authorization: Bearer <anonKey>
/// → {badgeList: [{rankId, rankName, rangeType}],   // 服务端页签（与字节码常量一致）
///    books: [{id, title, subtitle, cover, songNum, playCnt,
///             rank, isStar, author, narrator, description}],
///    total: 100}
/// ```
///
/// 与酷我榜不同：书籍**自带真实标题/作者/播音**，
/// 取代此前 `LrtsSourceAdapter.getRankList` 的「解析 HTML 得占位 id」方案。
class LrtsRankApi {
  LrtsRankApi({
    Dio? dio,
    this.retryDelay = const Duration(seconds: 8),
  }) : _dio = dio ?? Dio();

  final Dio _dio;

  /// 429 限流后的重试间隔（测试可注入 0）。
  final Duration retryDelay;

  static const String _fnBase =
      'https://backend.appmiaoda.com/projects/supabase345057433544081408/functions/v1';

  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhw'
      'IjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9'
      '.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc';

  /// 榜单页签（字节码 #18082 内联字面量逐字还原；
  /// 与线上响应 badgeList 前 8 项逐一比对一致）。
  static const List<LrtsRankTab> tabs = [
    LrtsRankTab(rankId: 75, name: '热播榜', rangeType: 1),
    LrtsRankTab(rankId: 738, name: '新书榜', rangeType: 3),
    LrtsRankTab(rankId: 77, name: '热搜榜', rangeType: 1),
    LrtsRankTab(rankId: 76, name: '好评榜', rangeType: 1),
    LrtsRankTab(rankId: 14479, name: '收藏榜', rangeType: 3),
    LrtsRankTab(rankId: 739, name: '完结榜', rangeType: 1),
    LrtsRankTab(rankId: 14481, name: '免费榜', rangeType: 1),
    LrtsRankTab(rankId: 740, name: '会员榜', rangeType: 1),
  ];

  /// 拉取一个榜单（429 限流自动重试，与酷我榜一致的克制策略）。
  Future<List<KuwoRankBook>> fetchRankBooks(LrtsRankTab tab) async {
    final body = await _get('/lrts-rank?rankId=${tab.rankId}&rangeType=${tab.rangeType}');
    if (body == null) return const [];
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      return parseRankBooks(json);
    } catch (_) {
      return const [];
    }
  }

  /// 解析 `lrts-rank` 响应为通用榜行（复用 [KuwoRankBook] 行模型）。
  ///
  /// playCnt 上游可能返回占位符 `–`（真实观测），原样透传由 UI 处理。
  List<KuwoRankBook> parseRankBooks(Map json) {
    final list = json['books'];
    if (list is! List) return const [];
    return [
      for (final b in list)
        if (b is Map)
          KuwoRankBook(
            id: '${b['id'] ?? ''}',
            title: '${b['title'] ?? ''}',
            cover: b['cover'] == null ? null : '${b['cover']}',
            playCount: '${b['playCnt'] ?? ''}',
            chapterCount: '${b['songNum'] ?? ''}',
            rank: '${b['rank'] ?? ''}',
            author: '${b['author'] ?? ''}',
          ),
    ];
  }

  Future<String?> _get(String path) async {
    for (var attempt = 0; attempt <= 2; attempt++) {
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
  }
}

/// lrts 榜单页签。
class LrtsRankTab {
  final int rankId;
  final String name;
  final int rangeType;

  const LrtsRankTab({
    required this.rankId,
    required this.name,
    required this.rangeType,
  });
}

/// Provider。
final lrtsRankApiProvider = Provider<LrtsRankApi>((ref) => LrtsRankApi());
