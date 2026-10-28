import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/data/repositories/play_history_repository.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_widgets.dart';
import 'package:soft_sound/theme/brand_widgets.dart';

/// 一条听书记录（历史 + 书籍元数据）。
class HistoryEntry {
  const HistoryEntry({required this.book, required this.progress});

  final Book book;
  final PlayProgress progress;

  /// 章节名；历史里没存名字时退回「第 N 章」。
  String get chapterLabel {
    final name = progress.chapterName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return '第 ${progress.chapterIndex + 1} 章';
  }

  double get ratio => progress.progress.clamp(0.0, 1.0);

  /// `12:04 / 18:00`（时长未知时只显示已听）。
  String get timeLabel {
    final pos = clock(Duration(milliseconds: progress.position));
    final total = progress.duration > 0
        ? ' / ${clock(Duration(milliseconds: progress.duration))}'
        : '';
    return '$pos$total';
  }

  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// 读听书记录：`play_history` + `books`（拿书名/封面）。
///
/// 之前这页是**写死的空状态**：无论库里有多少条记录都显示「暂无听书记录」，
/// 而「我的」页同时显示「听书记录 3 条」—— 自相矛盾。
final historyEntriesProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final historyRepo = ref.watch(playHistoryRepositoryProvider);
  final bookRepo = ref.watch(bookRepositoryProvider);

  final rows = await historyRepo.getRecentPlayed(limit: 100);
  final entries = <HistoryEntry>[];
  for (final p in rows) {
    final book = await bookRepo.getBookById(p.bookId);
    if (book == null) continue; // 书已不在库（旧版本留下的孤立记录）
    entries.add(HistoryEntry(book: book, progress: p));
  }
  return entries;
});

/// 听书记录页 —— 对应聆阅的历史页。
///
/// 支持左滑删除与一键清空（聆阅文案：`条收听记录（左滑可删除）`）。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// 已左滑删除、正在等数据库刷新的条目。
  ///
  /// Dismissible 要求「滑走之后立刻从树里消失」，而删库是异步的，
  /// 所以先用本地集合把它们从渲染列表里剔掉（否则 Flutter 会断言
  /// "A dismissed Dismissible widget is still part of the tree"）。
  final Set<String> _removed = {};

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final async = ref.watch(historyEntriesProvider);
    final all = async.valueOrNull ?? const <HistoryEntry>[];
    final entries =
        all.where((e) => !_removed.contains(e.book.bookId)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          entries.isEmpty
              ? AppStrings.listenHistory
              : AppStrings.historyCountText(entries.length),
        ),
        actions: [
          if (entries.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, entries.length),
              child: Text(
                AppStrings.clear,
                style: TextStyle(color: c.mutedForeground, fontSize: 13),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoadingState(message: AppStrings.loading),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline,
          title: AppStrings.loadFailed,
          description: '$e',
        ),
        data: (_) {
          // 注意用过滤后的 entries（不是 when 给的原始 list），
          // 否则左滑删除后那一行仍会被 build 出来，Flutter 会断言
          // "A dismissed Dismissible widget is still part of the tree"。
          final list = entries;
          if (list.isEmpty) {
            return const AppEmptyState(
              icon: Icons.history,
              title: AppStrings.historyEmpty,
              description: AppStrings.offlineHint1,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _HistoryTile(
              entry: list[i],
              onRemoved: (bookId) =>
                  setState(() => _removed.add(bookId)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.historyDeleteTitle),
        content: Text(
          '${AppStrings.confirmClearPrefix}$count${AppStrings.historyCount}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(playHistoryRepositoryProvider).clearAllHistory();
      ref.invalidate(historyEntriesProvider);
    }
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.entry, required this.onRemoved});

  final HistoryEntry entry;

  /// 立即从列表移除（同步），删除数据库随后完成。
  final void Function(String bookId) onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final cover = entry.book.coverUrl ?? '';

    return Dismissible(
      key: ValueKey('history_${entry.book.bookId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        // 先同步摘掉，满足 Dismissible 的约束
        onRemoved(entry.book.bookId);
        await ref
            .read(playHistoryRepositoryProvider)
            .deleteHistory(entry.book.bookId);
        if (ref.context.mounted) ref.invalidate(historyEntriesProvider);
      },
      child: GestureDetector(
        onTap: () => context.push('/book/${entry.book.bookId}'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E1F5), width: 1.5),
            boxShadow: lyHardShadowSm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: cover.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: c.muted),
                        )
                      : Container(
                          color: c.muted,
                          child: Icon(
                            Icons.headphones_rounded,
                            size: 22,
                            color: c.mutedForeground,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.book.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.chapterLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.mutedForeground, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: entry.ratio == 0 ? null : entry.ratio,
                        minHeight: 4,
                        backgroundColor: c.muted,
                        valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.timeLabel,
                      style: TextStyle(color: c.mutedForeground, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: c.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
