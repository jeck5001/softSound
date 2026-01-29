import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'book_repository.dart';

/// 播放进度信息
class PlayProgress {
  final String bookId;
  final String sourceId;
  final int chapterIndex;
  final String? chapterName;
  final int position;
  final int duration;
  final DateTime lastPlayTime;

  PlayProgress({
    required this.bookId,
    required this.sourceId,
    required this.chapterIndex,
    this.chapterName,
    required this.position,
    required this.duration,
    required this.lastPlayTime,
  });

  double get progress => duration > 0 ? position / duration : 0;
}

/// 播放历史数据访问层
class PlayHistoryRepository {
  final AppDatabase _db;

  PlayHistoryRepository(this._db);

  /// 保存播放进度
  Future<void> saveProgress({
    required String bookId,
    required String sourceId,
    required int chapterIndex,
    String? chapterName,
    required int position,
    required int duration,
  }) async {
    await _db.into(_db.playHistoryTable).insert(
      PlayHistoryTableCompanion.insert(
        bookId: bookId,
        sourceId: sourceId,
        chapterIndex: Value(chapterIndex),
        chapterName: Value(chapterName),
        position: Value(position),
        duration: Value(duration),
        lastPlayTime: Value(DateTime.now()),
      ),
      onConflict: DoUpdate(
        (old) => PlayHistoryTableCompanion(
          sourceId: Value(sourceId),
          chapterIndex: Value(chapterIndex),
          chapterName: Value(chapterName),
          position: Value(position),
          duration: Value(duration),
          lastPlayTime: Value(DateTime.now()),
        ),
        target: [_db.playHistoryTable.bookId],
      ),
    );
  }

  /// 获取播放进度
  Future<PlayProgress?> getProgress(String bookId) async {
    final rows = await (_db.select(_db.playHistoryTable)
      ..where((t) => t.bookId.equals(bookId)))
      .get();

    if (rows.isEmpty) return null;

    final row = rows.first;
    return PlayProgress(
      bookId: row.bookId,
      sourceId: row.sourceId,
      chapterIndex: row.chapterIndex,
      chapterName: row.chapterName,
      position: row.position,
      duration: row.duration,
      lastPlayTime: row.lastPlayTime,
    );
  }

  /// 获取最近播放列表
  Future<List<PlayProgress>> getRecentPlayed({int limit = 20}) async {
    final rows = await (_db.select(_db.playHistoryTable)
      ..orderBy([(t) => OrderingTerm.desc(t.lastPlayTime)])
      ..limit(limit))
      .get();

    return rows.map((row) => PlayProgress(
      bookId: row.bookId,
      sourceId: row.sourceId,
      chapterIndex: row.chapterIndex,
      chapterName: row.chapterName,
      position: row.position,
      duration: row.duration,
      lastPlayTime: row.lastPlayTime,
    )).toList();
  }

  /// 删除播放历史
  Future<void> deleteHistory(String bookId) async {
    await (_db.delete(_db.playHistoryTable)
      ..where((t) => t.bookId.equals(bookId)))
      .go();
  }

  /// 清空所有播放历史
  Future<void> clearAllHistory() async {
    await _db.delete(_db.playHistoryTable).go();
  }
}

/// PlayHistoryRepository Provider
final playHistoryRepositoryProvider = Provider<PlayHistoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PlayHistoryRepository(db);
});
