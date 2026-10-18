import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/download_repository.dart';

/// 下载管理页状态。
class DownloadsState {
  /// 进行中（排队 + 下载中）的任务。
  final List<DownloadTask> active;

  /// 已完成（可离线播放）的任务。
  final List<DownloadTask> completed;

  /// 是否正在加载。
  final bool isLoading;

  /// 错误信息。
  final String? error;

  const DownloadsState({
    this.active = const [],
    this.completed = const [],
    this.isLoading = false,
    this.error,
  });

  /// 两页签是否都为空。
  bool get isEmpty => active.isEmpty && completed.isEmpty;

  /// 已下载占用的总字节数。
  int get totalBytes =>
      completed.fold(0, (sum, t) => sum + t.downloadedBytes);

  DownloadsState copyWith({
    List<DownloadTask>? active,
    List<DownloadTask>? completed,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      DownloadsState(
        active: active ?? this.active,
        completed: completed ?? this.completed,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 下载管理控制器。
class DownloadsNotifier extends StateNotifier<DownloadsState> {
  final DownloadRepository _repo;

  DownloadsNotifier(this._repo) : super(const DownloadsState()) {
    refresh();
  }

  /// 重新载入下载列表。
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final active = await _repo.getActive();
      final completed = await _repo.getCompleted();
      state = state.copyWith(
        active: active,
        completed: completed,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  /// 删除单章缓存。
  Future<void> deleteChapter(String bookId, int chapterIndex) async {
    try {
      await _repo.deleteChapter(bookId, chapterIndex);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  /// 删除整本书缓存。
  Future<void> deleteBook(String bookId) async {
    try {
      await _repo.deleteBook(bookId);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  /// 清空全部缓存。
  Future<void> clearAll() async {
    try {
      await _repo.clearAll();
      await refresh();
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }
}

/// 下载管理 Provider。
final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, DownloadsState>(
  (ref) => DownloadsNotifier(ref.watch(downloadRepositoryProvider)),
);

/// 缓存总占用（用于设置页展示）。
final cacheUsageProvider = FutureProvider<int>((ref) async {
  return ref.watch(downloadRepositoryProvider).totalBytes();
});

/// 按书籍聚合的下载概览。
final downloadSummaryProvider =
    FutureProvider<List<BookDownloadSummary>>((ref) async {
  return ref.watch(downloadRepositoryProvider).getSummaryByBook();
});
