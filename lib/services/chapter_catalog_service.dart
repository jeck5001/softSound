import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/book.dart';
import '../data/models/chapter.dart';
import '../data/models/source_rule.dart';
import '../data/repositories/catalog_repository.dart';
import 'source_parser.dart';

/// 目录（章节列表）加载 + 缓存合并。
///
/// 为什么不能只靠"一次拉全"：
/// 懒人一本书要连拉近百页（5795 集 = 97 页），而书源代理有项目级并发限制
/// （实测 429 限流与 500 `InvalidWorkerCreation`）。一次会话极难 100% 拉全，
/// 旧实现每次进详情页都从零重拉，于是**永远差几页** ——
/// 这正是用户反馈「目录还是加载不全」的根因。
///
/// 这里的做法：
/// 1. 网络拉到的页 → 写入缓存（按上游 `section` 绝对序号存）
/// 2. 把**历史缓存**与**本次结果**合并 → 本次失败的页由缓存补上
/// 3. 网络完全失败时 → 直接返回缓存（至少不空）
/// 4. 完整性以 `Book.chapterCount`（上游声明总数）为准判断
class ChapterCatalogService {
  ChapterCatalogService({
    required SourceParser parser,
    required CatalogRepository catalog,
  })  : _parser = parser,
        _catalog = catalog;

  final SourceParser _parser;
  final CatalogRepository _catalog;

  /// 本次结果是否可能仍不完整。
  bool lastWasPartial = false;

  /// 缓存最多可信多久。
  ///
  /// 目录是**会变**的：上游会加章、也可能删章/改序号。
  /// 缓存只用来"救急补洞"，超时就必须失效，
  /// 否则会把已删除的章节一直留在用户目录里。
  static const Duration cacheTtl = Duration(days: 3);

  Future<List<Chapter>> loadChapters(
    SourceRule source,
    Book book, {
    int? expectedTotal,
  }) async {
    final expected = expectedTotal ?? book.chapterCount ?? 0;

    // 1) 先拉网络
    List<Chapter> fresh = const [];
    try {
      fresh = await _parser.getChapterList(source, book);
    } catch (e) {
      debugPrint('目录网络拉取失败: $e');
    }

    // 2) 判断本次是否已「完整」
    final complete = expected > 0 && fresh.length >= expected;
    if (complete) {
      // 完整时缓存**整体替换**：这样上游删掉/改序的章节不会残留在库里。
      try {
        await _catalog.clear(book.bookId);
        await _catalog.upsert(book.bookId, source.sourceId, fresh);
      } catch (e) {
        debugPrint('目录缓存替换失败: $e');
      }
      lastWasPartial = false;
      return fresh;
    }

    // 3) 不完整：本次结果落盘（累积），并读取仍在有效期内的缓存补洞
    if (fresh.isNotEmpty) {
      try {
        await _catalog.upsert(book.bookId, source.sourceId, fresh);
      } catch (e) {
        debugPrint('目录缓存写入失败: $e');
      }
    }

    List<Chapter> cached = const [];
    try {
      cached = await _catalog.load(book.bookId, maxAge: cacheTtl);
    } catch (e) {
      debugPrint('目录缓存读取失败: $e');
    }

    final merged = _mergeBySection(cached, fresh);
    lastWasPartial = expected > 0 && merged.length < expected;
    if (merged.isEmpty && fresh.isNotEmpty) return fresh;
    return merged;
  }

  /// 按绝对序号合并：同 section 以 [fresh]（较新）为准。
  List<Chapter> _mergeBySection(List<Chapter> cached, List<Chapter> fresh) {
    final bySection = <int, Chapter>{};
    for (final c in cached) {
      final s = c.sectionIndex ?? c.index + 1;
      bySection[s] = c;
    }
    for (final c in fresh) {
      final s = c.sectionIndex ?? c.index + 1;
      bySection[s] = c;
    }
    final sorted = bySection.values.toList()
      ..sort((a, b) => (a.sectionIndex ?? a.index).compareTo(
            b.sectionIndex ?? b.index,
          ));
    // 重编成连续 index（播放器按下标取章，不能有洞）
    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].copyWith(index: i),
    ];
  }

  /// 手动重试：清空后重拉（用于"目录可能不全 → 重试"按钮想彻底重来时）。
  Future<void> invalidate(String bookId) => _catalog.clear(bookId);
}

/// 目录服务 Provider（详情页与播放器共用，保证缓存视图一致）。
final chapterCatalogProvider = Provider<ChapterCatalogService>((ref) {
  return ChapterCatalogService(
    parser: SourceParser(),
    catalog: ref.watch(catalogRepositoryProvider),
  );
});
