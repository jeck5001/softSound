import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/tables/download_chapters_table.dart';
import 'book_repository.dart';

/// 单个下载任务的领域模型（对外暴露，避免 UI 直接依赖 Drift 生成类型）。
class DownloadTask {
  final int id;
  final String bookId;
  final String sourceId;
  final int chapterIndex;
  final String chapterName;
  final String? remoteUrl;
  final String? localPath;
  final int downloadedBytes;
  final int totalBytes;
  final DownloadStatus status;
  final String? error;
  final int durationMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DownloadTask({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.chapterIndex,
    required this.chapterName,
    this.remoteUrl,
    this.localPath,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.queued,
    this.error,
    this.durationMs = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 下载进度 0.0–1.0；总大小未知时返回 0。
  double get progress =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// 是否已完成并可离线播放。
  bool get isPlayable => status == DownloadStatus.completed &&
      localPath != null &&
      localPath!.isNotEmpty;
}

/// 按书籍聚合的下载概览，用于「已缓存书籍」列表。
class BookDownloadSummary {
  final String bookId;
  final int chapterCount;
  final int completedCount;
  final int totalBytes;

  const BookDownloadSummary({
    required this.bookId,
    required this.chapterCount,
    required this.completedCount,
    required this.totalBytes,
  });

  /// 是否整本下载完成。
  bool get isComplete => chapterCount > 0 && completedCount == chapterCount;

  /// 完成进度 0.0–1.0。
  double get progress =>
      chapterCount > 0 ? completedCount / chapterCount : 0.0;
}

/// 下载/缓存数据访问层。
///
/// 支撑「下载管理」「已下载章节」「离线缓存清理」三类界面，
/// 对应聆阅的 `downloads.tsx` 与设置页的缓存管理。
class DownloadRepository {
  final AppDatabase _db;

  DownloadRepository(this._db);

  // ------------------------------------------------------------------ 写入

  /// 登记一个下载任务（同书同章重复调用则覆盖）。
  ///
  /// 注意：不能用 `insertOnConflictUpdate` —— 它只处理主键冲突，
  /// 而这里的唯一约束是业务键 `(bookId, chapterIndex)`。
  /// 因此先尝试更新，未命中再插入。
  Future<int> enqueue({
    required String bookId,
    required String sourceId,
    required int chapterIndex,
    required String chapterName,
    String? remoteUrl,
    int? durationMs,
  }) async {
    final updated = await (_db.update(_db.downloadChaptersTable)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex)))
        .write(
      DownloadChaptersTableCompanion(
        sourceId: Value(sourceId),
        chapterName: Value(chapterName),
        remoteUrl: Value(remoteUrl),
        durationMs: Value(durationMs ?? 0),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (updated > 0) {
      final row = await (_db.select(_db.downloadChaptersTable)
            ..where((t) =>
                t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex))
            ..limit(1))
          .getSingle();
      return row.id;
    }

    return _db.into(_db.downloadChaptersTable).insert(
          DownloadChaptersTableCompanion.insert(
            bookId: bookId,
            sourceId: sourceId,
            chapterIndex: chapterIndex,
            chapterName: chapterName,
            remoteUrl: Value(remoteUrl),
            durationMs: Value(durationMs ?? 0),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// 更新下载进度。
  Future<void> updateProgress({
    required String bookId,
    required int chapterIndex,
    required int downloadedBytes,
    int? totalBytes,
  }) {
    return (_db.update(_db.downloadChaptersTable)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex)))
        .write(
      DownloadChaptersTableCompanion(
        downloadedBytes: Value(downloadedBytes),
        totalBytes: totalBytes == null ? const Value.absent() : Value(totalBytes),
        status: const Value(DownloadStatus.downloading),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 标记下载完成。
  Future<void> markCompleted({
    required String bookId,
    required int chapterIndex,
    required String localPath,
    int? totalBytes,
  }) {
    return (_db.update(_db.downloadChaptersTable)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex)))
        .write(
      DownloadChaptersTableCompanion(
        localPath: Value(localPath),
        status: const Value(DownloadStatus.completed),
        totalBytes: totalBytes == null ? const Value.absent() : Value(totalBytes),
        downloadedBytes: totalBytes == null
            ? const Value.absent()
            : Value(totalBytes),
        error: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 标记下载失败。
  Future<void> markFailed({
    required String bookId,
    required int chapterIndex,
    required String error,
  }) {
    return (_db.update(_db.downloadChaptersTable)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex)))
        .write(
      DownloadChaptersTableCompanion(
        status: const Value(DownloadStatus.failed),
        error: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ------------------------------------------------------------------ 查询

  /// 全部任务，按书 + 章排序。
  Future<List<DownloadTask>> getAll() async {
    final rows = await (_db.select(_db.downloadChaptersTable)
          ..orderBy([
            (t) => OrderingTerm(expression: t.bookId),
            (t) => OrderingTerm(expression: t.chapterIndex),
          ]))
        .get();
    return rows.map(_toTask).toList();
  }

  /// 某本书的全部任务。
  Future<List<DownloadTask>> getByBook(String bookId) async {
    final rows = await (_db.select(_db.downloadChaptersTable)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm(expression: t.chapterIndex)]))
        .get();
    return rows.map(_toTask).toList();
  }

  /// 进行中（排队 + 下载中）的任务。
  Future<List<DownloadTask>> getActive() async {
    final rows = await (_db.select(_db.downloadChaptersTable)
          ..where((t) =>
              t.status.equalsValue(DownloadStatus.queued) |
              t.status.equalsValue(DownloadStatus.downloading))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return rows.map(_toTask).toList();
  }

  /// 已完成（可离线播放）的任务。
  Future<List<DownloadTask>> getCompleted() async {
    final rows = await (_db.select(_db.downloadChaptersTable)
          ..where((t) => t.status.equalsValue(DownloadStatus.completed))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt)]))
        .get();
    return rows.map(_toTask).toList();
  }

  /// 某章是否已缓存，返回本地路径（未缓存返回 null）。
  Future<String?> localPathOf(String bookId, int chapterIndex) async {
    final row = await (_db.select(_db.downloadChaptersTable)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex))
          ..limit(1))
        .getSingleOrNull();
    if (row == null || row.status != DownloadStatus.completed) return null;
    return row.localPath;
  }

  /// 按书籍聚合的下载概览（只包含有下载记录的书籍）。
  Future<List<BookDownloadSummary>> getSummaryByBook() async {
    final tasks = await getAll();
    final grouped = <String, List<DownloadTask>>{};
    for (final t in tasks) {
      grouped.putIfAbsent(t.bookId, () => []).add(t);
    }
    return grouped.entries
        .map((e) => BookDownloadSummary(
              bookId: e.key,
              chapterCount: e.value.length,
              completedCount: e.value
                  .where((t) => t.status == DownloadStatus.completed)
                  .length,
              totalBytes: e.value.fold(0, (sum, t) => sum + t.downloadedBytes),
            ))
        .toList();
  }

  /// 缓存占用的总字节数（用于设置页「当前占用」）。
  Future<int> totalBytes() async {
    final tasks = await getCompleted();
    return tasks.fold<int>(0, (sum, t) => sum + t.downloadedBytes);
  }

  // ------------------------------------------------------------------ 删除

  /// 删除单章下载记录。
  Future<void> deleteChapter(String bookId, int chapterIndex) {
    return (_db.delete(_db.downloadChaptersTable)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterIndex.equals(chapterIndex)))
        .go();
  }

  /// 删除某本书的全部下载记录（聆阅：删除整本书缓存）。
  Future<void> deleteBook(String bookId) {
    return (_db.delete(_db.downloadChaptersTable)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }

  /// 清空全部下载记录（聆阅：清除应用缓存）。
  Future<void> clearAll() => _db.delete(_db.downloadChaptersTable).go();

  DownloadTask _toTask(DownloadChaptersTableData row) => DownloadTask(
        id: row.id,
        bookId: row.bookId,
        sourceId: row.sourceId,
        chapterIndex: row.chapterIndex,
        chapterName: row.chapterName,
        remoteUrl: row.remoteUrl,
        localPath: row.localPath,
        downloadedBytes: row.downloadedBytes,
        totalBytes: row.totalBytes,
        status: row.status,
        error: row.error,
        durationMs: row.durationMs,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}

/// 下载数据访问层 Provider。
final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(databaseProvider));
});

/// 某本书是否有任一章节已下载完成（用于书架「已离线」标记）。
final bookHasDownloadProvider =
    FutureProvider.family<bool, String>((ref, bookId) async {
  final tasks = await ref.watch(downloadRepositoryProvider).getByBook(bookId);
  return tasks.any(
    (t) => t.status == DownloadStatus.completed && t.isPlayable,
  );
});
