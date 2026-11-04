import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'book_repository.dart' show databaseProvider;

import '../models/chapter.dart';

/// 目录缓存仓库：让大目录的分页结果**跨会话累积**。
///
/// 背景：懒人一本书要连拉近百页（5795 集 = 97 页），而书源代理有
/// 项目级并发限制（实测 429 / 500）。一次会话拉不全时，旧实现下次
/// 又从第 1 页重来，于是「永远差几页」——用户反馈的目录不全就是这么来的。
///
/// 这里按上游 `section`（书内绝对序号）存原始数据，
/// 因此缺页只是表里有空洞，补齐后不会错位。
class CatalogRepository {
  CatalogRepository(this._db);

  final AppDatabase _db;

  /// 写入/更新章节（按 bookId + section 去重）。
  Future<void> upsert(String bookId, String sourceId, List<Chapter> chapters) async {
    if (chapters.isEmpty) return;
    await _db.batch((batch) {
      for (final c in chapters) {
        batch.insert(
          _db.bookChaptersTable,
          BookChaptersTableCompanion(
            bookId: Value(bookId),
            sourceId: Value(sourceId),
            // 缓存"绝对序号"，读回时再按连续位置重编号
            section: Value(c.sectionIndex ?? c.index + 1),
            chapterId: Value(c.chapterId),
            name: Value(c.name),
            durationMs: Value(c.duration ?? 0),
            isVip: Value(c.isVip),
            audioUrl: Value(c.audioUrl),
            updatedAt: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (old) => BookChaptersTableCompanion(
              chapterId: Value(c.chapterId),
              name: Value(c.name),
              durationMs: Value(c.duration ?? 0),
              isVip: Value(c.isVip),
              audioUrl: Value(c.audioUrl),
              updatedAt: Value(DateTime.now()),
            ),
            target: [_db.bookChaptersTable.bookId, _db.bookChaptersTable.section],
          ),
        );
      }
    });
  }

  /// 读回缓存章节，按 section 升序并重编成连续 index。
  ///
  /// [maxAge] 用于**防过期**：目录是会变的（上游可能增删改序），
  /// 陈旧缓存只能短期救急，不能永久生效。
  Future<List<Chapter>> load(String bookId, {Duration? maxAge}) async {
    final q = _db.select(_db.bookChaptersTable)
      ..where(
        (t) =>
            t.bookId.equals(bookId) &
            (maxAge == null
                ? _db.bookChaptersTable.updatedAt.isNotNull()
                : t.updatedAt.isBiggerOrEqualValue(
                    DateTime.now().subtract(maxAge))),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.section)]);
    final rows = await q.get();
    if (rows.isEmpty) return const [];
    return [
      for (var i = 0; i < rows.length; i++)
        Chapter(
          chapterId: rows[i].chapterId,
          bookId: bookId,
          index: i,
          name: rows[i].name,
          // url 承载章节 token，供后续换音频地址
          url: rows[i].chapterId,
          audioUrl: rows[i].audioUrl,
          duration: rows[i].durationMs,
          isVip: rows[i].isVip,
          sectionIndex: rows[i].section,
        ),
    ];
  }

  /// 已缓存的章节数。
  Future<int> count(String bookId) async {
    final t = _db.bookChaptersTable;
    final q = _db.selectOnly(t)
      ..addColumns([t.section.count()])
      ..where(t.bookId.equals(bookId));
    final row = await q.getSingleOrNull();
    return row?.read(t.section.count()) ?? 0;
  }

  /// 删除早于 [cutoff] 的缓存（防长期读到已删除/改号的章节）。
  Future<void> pruneBefore(DateTime cutoff) async {
    await (_db.delete(_db.bookChaptersTable)
          ..where((t) => t.updatedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// 清除某本书的目录缓存（手动刷新/换源时用）。
  Future<void> clear(String bookId) async {
    await (_db.delete(_db.bookChaptersTable)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}

/// 目录缓存仓库 Provider。
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(databaseProvider));
});
