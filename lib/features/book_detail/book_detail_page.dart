import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import '../../services/source_parser.dart';
import '../../services/player_service.dart';
import '../source_manager/source_manager_page.dart';

/// 书籍详情状态
class BookDetailState {
  final Book? book;
  final SourceRule? source;
  final List<Chapter> chapters;
  final bool isLoading;
  final String? error;

  const BookDetailState({
    this.book,
    this.source,
    this.chapters = const [],
    this.isLoading = false,
    this.error,
  });

  BookDetailState copyWith({
    Book? book,
    SourceRule? source,
    List<Chapter>? chapters,
    bool? isLoading,
    String? error,
  }) {
    return BookDetailState(
      book: book ?? this.book,
      source: source ?? this.source,
      chapters: chapters ?? this.chapters,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 书籍详情状态管理
class BookDetailNotifier extends StateNotifier<BookDetailState> {
  final SourceParser _parser = SourceParser();
  bool _isCancelled = false;

  BookDetailNotifier() : super(const BookDetailState());

  Future<void> loadBook(Book book, SourceRule source) async {
    _isCancelled = false;
    state = BookDetailState(book: book, source: source, isLoading: true);

    try {
      final detailBook = await _parser.getBookDetail(source, book);
      if (_isCancelled || !mounted) return;

      final chapters = await _parser.getChapterList(source, book);
      if (_isCancelled || !mounted) return;

      state = state.copyWith(
        book: detailBook ?? book,
        chapters: chapters,
        isLoading: false,
        error: chapters.isEmpty ? '未找到章节' : null,
      );
    } catch (e) {
      if (_isCancelled || !mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: '加载失败: $e',
      );
    }
  }

  void cancel() {
    _isCancelled = true;
  }

  void clear() {
    _isCancelled = true;
    state = const BookDetailState();
  }

  @override
  void dispose() {
    _isCancelled = true;
    super.dispose();
  }
}

/// 书籍详情 Provider（不使用 autoDispose 避免异步问题）
final bookDetailProvider =
    StateNotifierProvider<BookDetailNotifier, BookDetailState>((ref) {
  return BookDetailNotifier();
});

/// 书籍详情页面
class BookDetailPage extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailPage({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  @override
  void initState() {
    super.initState();
    _loadBookFromSearch();
  }

  void _loadBookFromSearch() {
    final sources = ref.read(sourcesProvider);
    
    for (final source in sources) {
      final bookIdPrefix = '${source.sourceId}_';
      if (widget.bookId.startsWith(bookIdPrefix)) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(bookDetailProvider);

    return Scaffold(
      body: detailState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detailState.book == null
              ? _buildNotFound()
              : _buildContent(detailState),
      floatingActionButton: detailState.chapters.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _startPlaying(0),
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始播放'),
            )
          : null,
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '请从搜索结果进入书籍详情',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('返回首页'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BookDetailState detailState) {
    final book = detailState.book!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              book.name,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: book.coverUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        _buildDefaultBackground(),
                  )
                else
                  _buildDefaultBackground(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (book.author != null && book.author!.isNotEmpty)
                  _buildInfoRow('作者', book.author!),
                if (book.narrator != null && book.narrator!.isNotEmpty)
                  _buildInfoRow('播音', book.narrator!),
                const SizedBox(height: 16),
                const Text(
                  '简介',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  book.intro ?? '暂无简介',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '章节列表 (${detailState.chapters.length})',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (detailState.error != null)
                      Text(
                        detailState.error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (detailState.chapters.isEmpty && !detailState.isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  detailState.error ?? '暂无章节',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final chapter = detailState.chapters[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(
                    chapter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: chapter.isVip
                      ? const Icon(Icons.lock, color: Colors.orange, size: 18)
                      : const Icon(Icons.play_arrow),
                  onTap: () => _startPlaying(index),
                );
              },
              childCount: detailState.chapters.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.headphones,
        size: 80,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _startPlaying(int chapterIndex) {
    final detailState = ref.read(bookDetailProvider);
    if (detailState.book == null ||
        detailState.source == null ||
        detailState.chapters.isEmpty) {
      return;
    }

    ref.read(playerProvider.notifier).initBook(
          source: detailState.source!,
          book: detailState.book!,
          chapters: detailState.chapters,
          startChapterIndex: chapterIndex,
        );

    context.push('/player');
  }
}

/// 用于从搜索结果传递书籍数据的扩展
extension BookDetailPageExt on BookDetailPage {
  static void loadBook(WidgetRef ref, Book book, SourceRule source) {
    ref.read(bookDetailProvider.notifier).loadBook(book, source);
  }
}
