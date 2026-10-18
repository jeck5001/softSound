import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_widgets.dart';

import '../../data/database/tables/download_chapters_table.dart';
import '../../data/repositories/download_repository.dart';
import 'downloads_notifier.dart';

/// 下载管理页 —— 对应聆阅的 `downloads.tsx`。
///
/// 分「下载中 / 已下载」两个页签，数据来自本地 `download_chapters` 表。
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final state = ref.watch(downloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.downloadManage),
        actions: [
          if (state.completed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: AppStrings.cacheClearTitle,
              onPressed: () => _confirmClearAll(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: c.primary,
          unselectedLabelColor: c.mutedForeground,
          indicatorColor: c.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              text: state.active.isEmpty
                  ? AppStrings.downloading
                  : '${AppStrings.downloading} (${state.active.length})',
            ),
            Tab(
              text: state.completed.isEmpty
                  ? AppStrings.downloaded
                  : '${AppStrings.downloaded} (${state.completed.length})',
            ),
          ],
        ),
      ),
      body: state.isLoading && state.isEmpty
          ? const AppLoadingState(message: AppStrings.loadingPlease)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(
                  context,
                  tasks: state.active,
                  emptyTitle: AppStrings.noData,
                  emptyDesc: AppStrings.offlineHint3,
                  emptyIcon: Icons.downloading_outlined,
                  showProgress: true,
                ),
                _buildList(
                  context,
                  tasks: state.completed,
                  emptyTitle: AppStrings.downloadedEmpty,
                  emptyDesc: AppStrings.offlineHint2,
                  emptyIcon: Icons.download_done_outlined,
                  showProgress: false,
                ),
              ],
            ),
    );
  }

  Widget _buildList(
    BuildContext context, {
    required List<DownloadTask> tasks,
    required String emptyTitle,
    required String emptyDesc,
    required IconData emptyIcon,
    required bool showProgress,
  }) {
    if (tasks.isEmpty) {
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        description: emptyDesc,
      );
    }

    // 按书籍分组展示，贴合聆阅「整本书下载」的组织方式。
    final grouped = <String, List<DownloadTask>>{};
    for (final t in tasks) {
      grouped.putIfAbsent(t.bookId, () => []).add(t);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final entry in grouped.entries)
            _BookDownloadCard(
              bookId: entry.key,
              tasks: entry.value,
              showProgress: showProgress,
              onDeleteChapter: (index) => ref
                  .read(downloadsProvider.notifier)
                  .deleteChapter(entry.key, index),
              onDeleteBook: () => _confirmDeleteBook(context, entry.key),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBook(BuildContext context, String bookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.cacheClearTitle),
        content: Text(
          '${AppStrings.deleteCacheOf}$bookId${AppStrings.cacheDeleteOfBook}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(downloadsProvider.notifier).deleteBook(bookId);
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final state = ref.read(downloadsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.cacheClearTitle),
        content: Text(
          '${AppStrings.cacheClearConfirm}'
          '${_formatBytes(state.totalBytes)}${AppStrings.cacheNote}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(downloadsProvider.notifier).clearAll();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.cacheCleared)),
      );
    }
  }
}

/// 单本书的下载卡片。
class _BookDownloadCard extends StatelessWidget {
  final String bookId;
  final List<DownloadTask> tasks;
  final bool showProgress;
  final void Function(int chapterIndex) onDeleteChapter;
  final VoidCallback onDeleteBook;

  const _BookDownloadCard({
    required this.bookId,
    required this.tasks,
    required this.showProgress,
    required this.onDeleteChapter,
    required this.onDeleteBook,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final completed =
        tasks.where((t) => t.status == DownloadStatus.completed).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$completed / ${tasks.length} ${AppStrings.unitEpisode}'
                        ' · ${_formatBytes(tasks.fold(0, (s, t) => s + t.downloadedBytes))}',
                        style: TextStyle(
                          color: c.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: c.mutedForeground,
                  tooltip: AppStrings.delete,
                  onPressed: onDeleteBook,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          for (final t in tasks)
            _ChapterRow(
              task: t,
              showProgress: showProgress,
              onDelete: () => onDeleteChapter(t.chapterIndex),
            ),
        ],
      ),
    );
  }
}

/// 单个章节行。
class _ChapterRow extends StatelessWidget {
  final DownloadTask task;
  final bool showProgress;
  final VoidCallback onDelete;

  const _ChapterRow({
    required this.task,
    required this.showProgress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final (label, color) = switch (task.status) {
      DownloadStatus.queued => (AppStrings.downloadQueued, c.mutedForeground),
      DownloadStatus.downloading => (AppStrings.downloading, c.primary),
      DownloadStatus.completed => (AppStrings.downloaded, c.mutedForeground),
      DownloadStatus.failed => (AppStrings.downloadFailed, c.destructive),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${task.chapterIndex + 1}. ${task.chapterName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.foreground, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                    if (task.error != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          task.error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.destructive,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (showProgress && task.status == DownloadStatus.downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 3,
                        color: c.primary,
                        backgroundColor: c.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: c.mutedForeground,
            tooltip: AppStrings.delete,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// 字节数格式化（B / KB / MB / GB）。
String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(value >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}
