import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/book.dart';
import '../../data/models/source_rule.dart';
import '../../services/source_parser.dart';
import '../source_manager/source_manager_page.dart';
import '../book_detail/book_detail_page.dart';

/// 搜索状态
class SearchState {
  final bool isLoading;
  final List<Book> results;
  final Map<String, List<Book>> groupedResults;
  final String? error;

  const SearchState({
    this.isLoading = false,
    this.results = const [],
    this.groupedResults = const {},
    this.error,
  });

  SearchState copyWith({
    bool? isLoading,
    List<Book>? results,
    Map<String, List<Book>>? groupedResults,
    String? error,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      groupedResults: groupedResults ?? this.groupedResults,
      error: error,
    );
  }
}

/// 搜索状态管理
class SearchNotifier extends StateNotifier<SearchState> {
  final SourceParser _parser;
  final List<SourceRule> _sources;

  SearchNotifier(this._sources) : _parser = SourceParser(), super(const SearchState());

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) return;

    state = state.copyWith(isLoading: true, error: null, results: [], groupedResults: {});

    try {
      final enabledSources = _sources.where((s) => s.enabled).toList();

      if (enabledSources.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '请先添加并启用书源',
        );
        return;
      }

      final allResults = <Book>[];
      final grouped = <String, List<Book>>{};

      for (final source in enabledSources) {
        try {
          final books = await _parser.search(source, keyword);
          allResults.addAll(books);
          if (books.isNotEmpty) {
            grouped[source.sourceId] = books;
          }
        } catch (e) {
          debugPrint('Search error for ${source.sourceName}: $e');
        }
      }

      state = state.copyWith(
        isLoading: false,
        results: allResults,
        groupedResults: grouped,
        error: allResults.isEmpty ? '未找到相关书籍' : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '搜索失败: $e',
      );
    }
  }

  void clear() {
    state = const SearchState();
  }
}

/// 搜索状态Provider
final searchProvider = StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  final sources = ref.watch(sourcesProvider);
  return SearchNotifier(sources);
});

/// 搜索页面
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: '搜索有声书',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchProvider.notifier).clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _onSearch,
          onChanged: (value) => setState(() {}),
        ),
        actions: [
          TextButton(
            onPressed: searchState.isLoading
                ? null
                : () => _onSearch(_searchController.text),
            child: searchState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('搜索'),
          ),
        ],
      ),
      body: _buildBody(searchState),
    );
  }

  Widget _buildBody(SearchState searchState) {
    if (searchState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在搜索...'),
          ],
        ),
      );
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchState.error == '请先添加并启用书源'
                  ? Icons.source_outlined
                  : Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchState.error!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            if (searchState.error == '请先添加并启用书源') ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/sources'),
                icon: const Icon(Icons.add),
                label: const Text('添加书源'),
              ),
            ],
          ],
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '输入书名搜索有声书',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final sources = ref.read(sourcesProvider);
    final groupedResults = searchState.groupedResults;
    final sourceIds = groupedResults.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sourceIds.length,
      itemBuilder: (context, index) {
        final sourceId = sourceIds[index];
        final books = groupedResults[sourceId]!;
        final source = sources.firstWhere(
          (s) => s.sourceId == sourceId,
          orElse: () => sources.first,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                source.sourceName.substring(0, 1),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              source.sourceName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${books.length} 本书'),
            children: books.map((book) => _buildBookItem(book)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBookItem(Book book) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _openBookDetail(book),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: book.coverUrl!,
                        width: 80,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(Icons.book),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 80,
                          height: 100,
                          color: Colors.grey[300],
                          child: const Icon(Icons.book),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 100,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.headphones,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (book.author != null && book.author!.isNotEmpty)
                      Text(
                        '作者: ${book.author}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    if (book.narrator != null && book.narrator!.isNotEmpty)
                      Text(
                        '播音: ${book.narrator}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    if (book.intro != null && book.intro!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.intro!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _onSearch(String keyword) {
    if (keyword.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入搜索关键词')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    ref.read(searchProvider.notifier).search(keyword);
  }

  void _openBookDetail(Book book) {
    final sources = ref.read(sourcesProvider);
    final source = sources.firstWhere(
      (s) => s.sourceId == book.sourceId,
      orElse: () => sources.first,
    );

    ref.read(bookDetailProvider.notifier).loadBook(book, source);
    context.push('/book/${book.bookId}');
  }
}
