import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/play_history_repository.dart';
import '../../data/repositories/download_repository.dart';
import '../../services/player_service.dart';
import '../source_manager/source_manager_page.dart';
import '../book_detail/book_detail_page.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_strings.dart';
import '../../theme/app_widgets.dart';
import 'shelf_preferences.dart';

/// 书架状态
class BookshelfState {
  final List<Book> books;
  final Map<String, PlayProgress?> progressMap;
  final bool isLoading;
  final String? error;

  BookshelfState({
    this.books = const [],
    this.progressMap = const {},
    this.isLoading = false,
    this.error,
  });

  BookshelfState copyWith({
    List<Book>? books,
    Map<String, PlayProgress?>? progressMap,
    bool? isLoading,
    String? error,
  }) {
    return BookshelfState(
      books: books ?? this.books,
      progressMap: progressMap ?? this.progressMap,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 书架状态管理
class BookshelfNotifier extends StateNotifier<BookshelfState> {
  final BookRepository _bookRepo;
  final PlayHistoryRepository _historyRepo;

  BookshelfNotifier(this._bookRepo, this._historyRepo) : super(BookshelfState()) {
    loadBooks();
  }

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true);
    try {
      final books = await _bookRepo.getBookshelfBooks();
      final progressMap = <String, PlayProgress?>{};
      for (final book in books) {
        progressMap[book.bookId] = await _historyRepo.getProgress(book.bookId);
      }
      state = state.copyWith(
        books: books,
        progressMap: progressMap,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> removeBook(String bookId) async {
    await _bookRepo.removeFromBookshelf(bookId);
    state = state.copyWith(
      books: state.books.where((b) => b.bookId != bookId).toList(),
    );
  }
}

/// 书架 Provider
final bookshelfProvider = StateNotifierProvider<BookshelfNotifier, BookshelfState>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final historyRepo = ref.watch(playHistoryRepositoryProvider);
  return BookshelfNotifier(bookRepo, historyRepo);
});

/// 书架页面
class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelfState = ref.watch(bookshelfProvider);
    final prefs = ref.watch(shelfPreferencesProvider);
    final view = prefs.view;
    final sort = prefs.sort;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myShelf),
        actions: [
          if (bookshelfState.books.isNotEmpty) ...[
            // 视图切换（网格 / 列表）—— 对齐聆阅的「网格/列表」
            IconButton(
              icon: Icon(
                view == ShelfView.grid ? Icons.view_list : Icons.grid_view,
              ),
              tooltip: view == ShelfView.grid
                  ? AppStrings.shelfViewList
                  : AppStrings.shelfViewGrid,
              onPressed: () => ref
                  .read(shelfPreferencesProvider.notifier)
                  .setView(
                    view == ShelfView.grid ? ShelfView.list : ShelfView.grid,
                  ),
            ),
            // 排序（聆阅：最新 / 最热）
            PopupMenuButton<ShelfSort>(
              icon: const Icon(Icons.sort),
              tooltip: AppStrings.shelfSort,
              initialValue: sort,
              onSelected: (v) =>
                  ref.read(shelfPreferencesProvider.notifier).setSort(v),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ShelfSort.added,
                  child: Text(AppStrings.shelfSortAdded),
                ),
                PopupMenuItem(
                  value: ShelfSort.title,
                  child: Text(AppStrings.shelfSortTitle),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(context, ref, bookshelfState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BookshelfState state) {
    if (state.isLoading) {
      return const AppLoadingState(message: AppStrings.loadingPlease);
    }

    if (state.books.isEmpty) {
      return _buildEmptyState(context);
    }

    final books = _sorted(state.books, ref.watch(shelfPreferencesProvider).sort);
    final view = ref.watch(shelfPreferencesProvider).view;

    return RefreshIndicator(
      onRefresh: () => ref.read(bookshelfProvider.notifier).loadBooks(),
      child: view == ShelfView.grid
          ? GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return _buildBookItem(
                  context,
                  ref,
                  book,
                  state.progressMap[book.bookId],
                );
              },
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return _buildBookRow(
                  context,
                  ref,
                  book,
                  state.progressMap[book.bookId],
                );
              },
            ),
    );
  }

  /// 按所选排序返回书籍列表。
  List<Book> _sorted(List<Book> books, ShelfSort sort) {
    final copy = [...books];
    switch (sort) {
      case ShelfSort.title:
        copy.sort((a, b) => a.name.compareTo(b.name));
      case ShelfSort.added:
        // 保持数据源顺序（仓库已按加入/更新时间倒序返回）
        break;
    }
    return copy;
  }
  Widget _buildBookItem(
    BuildContext context,
    WidgetRef ref,
    Book book,
    PlayProgress? progress,
  ) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () => _openBook(context, ref, book),
      onLongPress: () => _showDeleteDialog(context, ref, book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: book.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: book.coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) =>
                              _buildDefaultCover(context),
                          errorWidget: (context, url, error) =>
                              _buildDefaultCover(context),
                        )
                      : _buildDefaultCover(context),
                ),
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.foreground,
            ),
          ),
          if (progress != null)
            Text(
              progress.chapterName ??
                  '${AppStrings.chapterIndexPrefix}'
                      '${progress.chapterIndex + 1}'
                      '${AppStrings.chapterIndexSuffix}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: c.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: c.muted,
      child: Icon(
        Icons.headphones,
        size: 40,
        color: c.mutedForeground,
      ),
    );
  }

  /// 列表视图的书籍行 —— 对齐聆阅的列表模式。
  ///
  /// 相比网格多显示作者/播音与收听进度文本，并带「已离线」标记。
  Widget _buildBookRow(
    BuildContext context,
    WidgetRef ref,
    Book book,
    PlayProgress? progress,
  ) {
    final c = context.appColors;
    return InkWell(
      onTap: () => _openBook(context, ref, book),
      onLongPress: () => _showDeleteDialog(context, ref, book),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 74,
                child: book.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: book.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            _buildDefaultCover(context),
                        errorWidget: (context, url, error) =>
                            _buildDefaultCover(context),
                      )
                    : _buildDefaultCover(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (book.author != null && book.author!.isNotEmpty)
                        book.author!,
                      if (book.narrator != null && book.narrator!.isNotEmpty)
                        '${AppStrings.bookNarratorPrefix}${book.narrator}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.mutedForeground),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${AppStrings.listenedAlready}'
                      '${progress.chapterName ?? AppStrings.episodeIndex(progress.chapterIndex + 1)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: c.primary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 离线缓存标记：该书是否有已下载章节
            if (ref.watch(bookHasDownloadProvider(book.bookId)).valueOrNull ??
                false)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppStrings.offlineReady,
                  style: TextStyle(fontSize: 10, color: c.accentForeground),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.library_books_outlined,
      title: AppStrings.shelfEmpty,
      description: AppStrings.shelfEmptyHint,
      actionLabel: AppStrings.shelfExplore,
      onAction: () => context.push('/search'),
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, Book book) {
    final sources = ref.read(sourcesProvider);
    final source = sources.firstWhere(
      (s) => s.sourceId == book.sourceId,
      orElse: () => sources.first,
    );
    BookDetailPageExt.loadBook(ref, book, source);
    // 把本地已知的书名与封面一并带上：路由若只带 bookId，详情页会先造一个
    // 「加载书籍信息…」占位 Book 等详情接口补全；而详情接口失败
    // （酷我 `getBookDetail` 常失败）时，标题就永久卡在占位串上。
    final query = <String, String>{
      if (book.name.trim().isNotEmpty &&
          !PlayerNotifier.isPlaceholderBook(book))
        'name': book.name,
      if ((book.coverUrl ?? '').trim().isNotEmpty)
        'cover': book.coverUrl!.trim(),
    };
    context.push(
      Uri(
        path: '/book/${book.bookId}',
        queryParameters: query.isEmpty ? null : query,
      ).toString(),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.removeFromShelfTitle),
        content: Text(
          '${AppStrings.removeFromShelfConfirmPrefix}'
          '${book.name}'
          '${AppStrings.removeFromShelfConfirmSuffix}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(bookshelfProvider.notifier).removeBook(book.bookId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${AppStrings.removedFromShelfPrefix}'
                    '${book.name}'
                    '${AppStrings.removedFromShelfSuffix}',
                  ),
                ),
              );
            },
            child: const Text(AppStrings.moveOut),
          ),
        ],
      ),
    );
  }
}
