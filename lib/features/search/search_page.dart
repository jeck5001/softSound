import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/book.dart';
import '../../data/models/source_rule.dart';
import '../../services/source_parser.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_strings.dart';
import '../../theme/app_widgets.dart';
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
          error: AppStrings.searchNoSource,
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
        error: allResults.isEmpty ? AppStrings.searchNoResult : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '${AppStrings.searchFailedPrefix}$e',
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
  /// 进入即搜的关键词（聆阅 `/search?source=` 同款上下文，支持深链与调试）。
  final String? initialQuery;

  const SearchPage({super.key, this.initialQuery});

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
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _searchController.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSearch(q);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: TextStyle(color: c.foreground),
          decoration: InputDecoration(
            hintText: AppStrings.searchHint,
            hintStyle: TextStyle(color: c.mutedForeground),
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
                : const Text(AppStrings.searchAction),
          ),
        ],
      ),
      body: _buildBody(context, searchState),
    );
  }

  Widget _buildBody(BuildContext context, SearchState searchState) {
    final c = context.appColors;

    if (searchState.isLoading) {
      return const AppLoadingState(message: AppStrings.searching);
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchState.error == AppStrings.searchNoSource
                  ? Icons.source_outlined
                  : Icons.search_off,
              size: 64,
              color: c.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(
              searchState.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.mutedForeground,
                fontSize: 16,
              ),
            ),
            if (searchState.error == AppStrings.searchNoSource) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/sources'),
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.searchAddSource),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                AppStrings.searchRetryHint,
                style: TextStyle(
                  color: c.mutedForeground,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search,
        title: AppStrings.searchIdleTitle,
        description: AppStrings.searchIdleHint,
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
              backgroundColor: c.accent,
              child: Text(
                source.sourceName.substring(0, 1),
                style: TextStyle(
                  color: c.accentForeground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              source.sourceName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${books.length} ${AppStrings.unitBook}'),
            children: books.map((book) => _buildBookItem(context, book)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBookItem(BuildContext context, Book book) {
    final c = context.appColors;
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
                        placeholder: (context, url) => _buildCoverFallback(context),
                        errorWidget: (context, url, error) =>
                            _buildCoverFallback(context),
                      )
                    : Container(
                        width: 80,
                        height: 100,
                        color: c.accent,
                        child: Icon(
                          Icons.headphones,
                          color: c.accentForeground,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (book.author != null && book.author!.isNotEmpty)
                      Text(
                        '${AppStrings.bookAuthor}: ${book.author}',
                        style: TextStyle(
                          color: c.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    if (book.narrator != null && book.narrator!.isNotEmpty)
                      Text(
                        '${AppStrings.bookNarrator}: ${book.narrator}',
                        style: TextStyle(
                          color: c.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                    if (book.intro != null && book.intro!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.intro!,
                        style: TextStyle(
                          color: c.mutedForeground,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  /// 封面加载中 / 加载失败时的占位块。
  Widget _buildCoverFallback(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: 80,
      height: 100,
      color: c.muted,
      child: Icon(Icons.book, color: c.mutedForeground),
    );
  }

  void _onSearch(String keyword) {
    if (keyword.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.searchKeywordEmpty)),
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
