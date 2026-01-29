import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/play_history_repository.dart';
import '../source_manager/source_manager_page.dart';
import '../book_detail/book_detail_page.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          if (bookshelfState.books.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(bookshelfProvider.notifier).loadBooks(),
            ),
        ],
      ),
      body: _buildBody(context, ref, bookshelfState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BookshelfState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.books.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(bookshelfProvider.notifier).loadBooks(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: state.books.length,
        itemBuilder: (context, index) {
          final book = state.books[index];
          final progress = state.progressMap[book.bookId];
          return _buildBookItem(context, ref, book, progress);
        },
      ),
    );
  }

  Widget _buildBookItem(
    BuildContext context,
    WidgetRef ref,
    Book book,
    PlayProgress? progress,
  ) {
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
                          placeholder: (context, url) => _buildDefaultCover(),
                          errorWidget: (context, url, error) => _buildDefaultCover(),
                        )
                      : _buildDefaultCover(),
                ),
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
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
                            color: Theme.of(context).colorScheme.primary,
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (progress != null)
            Text(
              progress.chapterName ?? '第${progress.chapterIndex + 1}章',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[200],
      child: Icon(
        Icons.headphones,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '快去搜索添加喜欢的有声书吧',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
            label: const Text('去搜索'),
          ),
        ],
      ),
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, Book book) {
    final sources = ref.read(sourcesProvider);
    final source = sources.firstWhere(
      (s) => s.sourceId == book.sourceId,
      orElse: () => sources.first,
    );
    BookDetailPageExt.loadBook(ref, book, source);
    context.push('/book/${book.bookId}');
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出书架'),
        content: Text('确定要将「${book.name}」移出书架吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(bookshelfProvider.notifier).removeBook(book.bookId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已将「${book.name}」移出书架')),
              );
            },
            child: const Text('移出'),
          ),
        ],
      ),
    );
  }
}
