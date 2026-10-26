import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lrts_home_api.dart' show LrtsHomeBook, LrtsHomeSection;
import 'nuxt_payload.dart';

/// 懒人听书「频道/分类」页 —— 聆阅 `channels/[categoryId].tsx` 的契约。
///
/// 来源：2026-10-26 对 Hermes 字节码 #18090（`fetchLrtsChildren`）的函数体深挖，
/// 并用真实请求验证。聆阅**不经过任何 Edge Function**，而是直接抓网页并解析
/// Nuxt SSR 的内联数据：
///
/// ```
/// GET https://m.lrts.me/category/book?title={分类名}&rootId={rootId}&index=-2
///   headers: iPhone UA + Accept: text/html
/// → HTML 内含 window.__NUXT__ = (function(...){return {...}}(...));
///   取 payload.data[0]（或 data）
/// ```
///
/// 解出的字段（字节码 #18090 逐字）：
///
/// | 字段 | 说明 |
/// |---|---|
/// | `title` | 分类名（缺省回退「儿童」） |
/// | `rootId` | 分类根 id |
/// | `tabList` | 页签：`{name}` 或 `{id, name}`；首项「推荐」，次项「全部」 |
/// | `recommendList` | 推荐书（→ `sections` 首栏「听友推荐」） |
/// | `subTypeRecommendList` | 子类栏目 `[{name, list:[书]}]` |
///
/// 输出结构（字节码里 push 的对象字面量）：
/// `{title, tabs, recommendBooks, sections:[{label, books}], allBooks, total}`
///
/// 页签过滤规则（字节码 #18093，逐条）：
/// 丢弃 `!name`、`name==='推荐'`、`name==='全部'`、`id==='0'`、`id==='6'`。
///
/// 书映射（字节码 #18091 `mapChildBook`）：
/// id 取 `id || entityId || baseEntityId`；title 取 `name`；
/// author 取 `nickName || author || '未知'`；cover 取 `cover || originCover`
/// 且把 `http://` 升级为 `https://`；`rating` 恒为 9.5（聆阅写死的展示值）。
class LrtsChildrenApi {
  LrtsChildrenApi({
    Dio? dio,
    this.timeout = const Duration(seconds: 12),
    this.maxAttempts = 2,
    this.retryDelay = const Duration(milliseconds: 500),
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final Duration timeout;
  final int maxAttempts;
  final Duration retryDelay;

  /// 聆阅用的 iPhone UA（字节码 #18090 内联字面量，逐字）。
  static const String userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';

  /// 分类页 URL（`title` 需 URL 编码）。
  static String categoryUrl({required String title, required String rootId}) {
    return 'https://m.lrts.me/category/book'
        '?title=${Uri.encodeComponent(title)}&rootId=$rootId&index=-2';
  }

  /// 拉一个频道页。失败（网络/解析）返回 [LrtsChildrenData.empty]。
  Future<LrtsChildrenData> fetch({
    required String title,
    required String rootId,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(retryDelay);
      try {
        final r = await _dio.get<String>(
          categoryUrl(title: title, rootId: rootId),
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (c) => c != null && c < 500,
            headers: const {
              'User-Agent': userAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
            receiveTimeout: timeout,
            sendTimeout: timeout,
          ),
        );
        final html = r.data;
        if (html == null || html.isEmpty) continue;
        final parsed = parseHtml(html);
        if (parsed.allBooks.isNotEmpty) return parsed;
      } catch (_) {
        // 重试
      }
    }
    return const LrtsChildrenData.empty();
  }

  /// 解析频道页 HTML（独立方法便于 fixture 单测）。
  LrtsChildrenData parseHtml(String html) {
    final payload = NuxtPayload.tryParse(html);
    final data = payload?.pageData;
    if (data == null) return const LrtsChildrenData.empty();

    final title = _string(data['title']);
    final rootId = _string(data['rootId']);

    final tabs = <LrtsChannelTab>[];
    final rawTabs = data['tabList'];
    if (rawTabs is List) {
      for (final t in rawTabs) {
        if (t is! Map) continue;
        final name = _string(t['name']);
        final id = _string(t['id']);
        if (name.isEmpty) continue; // 字节码：!name 直接丢
        if (name == '推荐' || name == '全部') continue;
        if (id == '0' || id == '6') continue;
        tabs.add(LrtsChannelTab(id: id, name: name));
      }
    }

    final recommend = <LrtsHomeBook>[];
    final rawRecommend = data['recommendList'];
    if (rawRecommend is List) {
      for (final b in rawRecommend) {
        final mapped = _mapBook(b, category: title);
        if (mapped != null) recommend.add(mapped);
      }
    }

    final sections = <LrtsHomeSection>[];
    if (recommend.isNotEmpty) {
      sections.add(LrtsHomeSection(label: '听友推荐', books: recommend));
    }
    final rawSubs = data['subTypeRecommendList'];
    if (rawSubs is List) {
      for (final s in rawSubs) {
        if (s is! Map) continue;
        final label = _string(s['name']).trim();
        final list = s['list'];
        if (list is! List) continue;
        final books = <LrtsHomeBook>[];
        for (final b in list) {
          final mapped = _mapBook(b, category: label.isEmpty ? title : label);
          if (mapped != null) books.add(mapped);
        }
        if (books.isEmpty) continue;
        sections.add(
          LrtsHomeSection(label: label.isEmpty ? '推荐' : label, books: books),
        );
      }
    }

    // allBooks：推荐 ∪ 各栏目，按 id 去重（字节码 #18096 用 Set 去重）。
    final seen = <String>{};
    final all = <LrtsHomeBook>[];
    void addAll(Iterable<LrtsHomeBook> src) {
      for (final b in src) {
        if (seen.add(b.id)) all.add(b);
      }
    }

    addAll(recommend);
    for (final s in sections) {
      addAll(s.books);
    }

    return LrtsChildrenData(
      title: title.isEmpty ? '儿童' : title,
      rootId: rootId,
      tabs: tabs,
      recommendBooks: recommend,
      sections: sections,
      allBooks: all,
    );
  }

  /// 字节码 #18091 `mapChildBook` 的逐条等价实现。
  LrtsHomeBook? _mapBook(Object? raw, {required String category}) {
    if (raw is! Map) return null;
    final id = _firstNonEmpty([
      raw['id'],
      raw['entityId'],
      raw['baseEntityId'],
    ]);
    if (id.isEmpty) return null;
    final name = _string(raw['name']).trim();
    if (name.isEmpty) return null;
    var cover = _firstNonEmpty([raw['cover'], raw['originCover']]);
    if (cover.startsWith('http://')) {
      cover = 'https://${cover.substring(7)}';
    }
    final author = _firstNonEmpty([raw['nickName'], raw['author']]);
    return LrtsHomeBook(
      id: id,
      title: name,
      author: author.isEmpty ? '未知' : author,
      narrator: '',
      cover: cover,
      // 聆阅在此处写死 9.5（字节码 LoadConstDouble 9.5），照搬以免 UI 空位。
      rating: 9.5,
      listeners: _formatPlayCount(raw['playCount']),
      description: _string(raw['desc']).trim(),
      category: category,
    );
  }

  /// `playCount` → 「303.2万播放」（聆阅文案单位在 AppStrings.unitWanPlay）。
  static String _formatPlayCount(Object? raw) {
    final n = raw is num ? raw : num.tryParse('$raw');
    if (n == null || n <= 0) return '';
    if (n >= 100000000) {
      return '${(n / 100000000).toStringAsFixed(1)}亿播放';
    }
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万播放';
    }
    return '${n.toInt()}播放';
  }

  static String _string(Object? v) => v == null ? '' : '$v';

  static String _firstNonEmpty(List<Object?> candidates) {
    for (final c in candidates) {
      final s = _string(c).trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }
}

/// 频道页页签。
class LrtsChannelTab {
  const LrtsChannelTab({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is LrtsChannelTab && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'LrtsChannelTab($id, $name)';
}

/// 频道页数据。
class LrtsChildrenData {
  const LrtsChildrenData({
    required this.title,
    required this.rootId,
    required this.tabs,
    required this.recommendBooks,
    required this.sections,
    required this.allBooks,
  });

  const LrtsChildrenData.empty()
    : title = '',
      rootId = '',
      tabs = const [],
      recommendBooks = const [],
      sections = const [],
      allBooks = const [];

  final String title;
  final String rootId;
  final List<LrtsChannelTab> tabs;
  final List<LrtsHomeBook> recommendBooks;
  final List<LrtsHomeSection> sections;
  final List<LrtsHomeBook> allBooks;

  bool get isEmpty => allBooks.isEmpty && sections.isEmpty;
}

/// 频道数据 Provider 工厂（按 rootId+title 缓存）。
final lrtsChildrenProvider =
    FutureProvider.family<LrtsChildrenData, ({String title, String rootId})>((
      ref,
      arg,
    ) {
      return LrtsChildrenApi().fetch(title: arg.title, rootId: arg.rootId);
    });
