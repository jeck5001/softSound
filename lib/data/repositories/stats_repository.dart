import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/listener_stats.dart';
import 'book_repository.dart';

/// 收听统计数据访问层。
///
/// 支撑「我的」页的累计听书时长、书架数、收藏数与等级展示。
class StatsRepository {
  final AppDatabase _db;

  StatsRepository(this._db);

  /// 统计行的固定主键（单行表）。
  static const int _rowId = 1;

  /// 累加收听秒数。
  ///
  /// 由播放器在进度保存时调用（增量，负数会被忽略）。
  Future<void> addListeningSeconds(int seconds) async {
    if (seconds <= 0) return;

    final existing = await (_db.select(_db.listeningStatsTable)
          ..where((t) => t.id.equals(_rowId)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.listeningStatsTable).insert(
            ListeningStatsTableCompanion.insert(
              id: const Value(_rowId),
              totalSeconds: Value(seconds),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (_db.update(_db.listeningStatsTable)
            ..where((t) => t.id.equals(_rowId)))
          .write(
        ListeningStatsTableCompanion(
          totalSeconds: Value(existing.totalSeconds + seconds),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// 读取累计收听秒数。
  Future<int> totalListeningSeconds() async {
    final row = await (_db.select(_db.listeningStatsTable)
          ..where((t) => t.id.equals(_rowId)))
        .getSingleOrNull();
    return row?.totalSeconds ?? 0;
  }

  /// 清零统计（用户在设置页主动清空数据时调用）。
  Future<void> resetListening() async {
    await (_db.delete(_db.listeningStatsTable)
          ..where((t) => t.id.equals(_rowId)))
        .go();
  }

  /// 汇总完整统计快照。
  Future<ListenerStats> snapshot() async {
    final seconds = await totalListeningSeconds();

    // 只统计**在书架里**的书：`books` 表还会存「听过但没收藏」的书
    // （播放时 `touchPlayedBook` 写入，inBookshelf=false），
    // 直接 count() 会把它们算进收藏数。
    final bookCount = await (_db.selectOnly(_db.booksTable)
          ..addColumns([_db.booksTable.id])
          ..where(_db.booksTable.inBookshelf.equals(true)))
        .map((row) => row.read(_db.booksTable.id))
        .get()
        .then((rows) => rows.length);

    final listenedChapters = await _db.playHistoryTable.count().getSingle();

    return ListenerStats(
      totalListening: Duration(seconds: seconds),
      bookCount: bookCount,
      // 当前书架即为收藏（聆阅中收藏与书架同源）
      favoriteCount: bookCount,
      listenedChapters: listenedChapters,
    );
  }
}

/// 收听统计 Provider。
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(databaseProvider));
});

/// 统计快照 Provider（我的页使用）。
final listenerStatsProvider = FutureProvider<ListenerStats>((ref) async {
  return ref.watch(statsRepositoryProvider).snapshot();
});
