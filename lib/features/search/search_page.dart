import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/book.dart';
import '../../data/models/source_rule.dart';
import '../../services/search_history.dart';
import '../../services/search_relevance.dart';
import '../../services/source_parser.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_strings.dart';
import '../../theme/app_widgets.dart';
import '../source_manager/source_manager_page.dart';
import '../book_detail/book_detail_page.dart';
import 'package:soft_sound/app/book_routes.dart';

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
  SearchNotifier(this._sources) : _parser = SourceParser(), super(const SearchState());

  final SourceParser _parser;
  final List<SourceRule> _sources;

  /// 同时并发搜索的源数量上限。
  ///
  /// 全并发会撞上行 Edge 的「项目级并发限制」（429 projectConcurrencyLimitExceeded），
  /// 反而更慢；串行又是各源延迟相加。3 路是实测比较稳的折中。
  static const int maxConcurrent = 3;

  /// 单源超时：慢源不能拖住整次搜索（之后到货也不再刷 UI）。
  static const Duration sourceTimeout = Duration(seconds: 10);

  /// 结果缓存（关键词 → 分组结果），5 分钟内重复搜索直接命中。
  static final Map<String, Map<String, List<Book>>> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static const Duration cacheTtl = Duration(minutes: 5);

  /// 供测试清理缓存。
  @visibleForTesting
  static void clearCache() {
    _cache.clear();
    _cacheAt.clear();
  }

  Future<void> search(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;

    final cached = _readCache(kw);
    // 缓存可能是**部分**结果（上次中途离开过）：先立刻显示已有分组，
    // 只补搜缺失的书源 —— 首屏瞬时可见，同时不丢完整性。
    final grouped = <String, List<Book>>{
      if (cached != null) ...cached,
    };

    final enabledSources = _sources.where((s) => s.enabled).toList();
    if (enabledSources.isEmpty) {
      state = state.copyWith(isLoading: false, error: AppStrings.searchNoSource);
      return;
    }

    final todo =
        enabledSources.where((s) => !grouped.containsKey(s.sourceId)).toList();

    if (grouped.isNotEmpty) {
      final ordered = _ordered(grouped);
      state = SearchState(
        results: [for (final list in ordered.values) ...list],
        groupedResults: ordered,
        isLoading: todo.isNotEmpty,
      );
    } else {
      state = state.copyWith(
        isLoading: true,
        error: null,
        results: [],
        groupedResults: {},
      );
    }

    if (todo.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: null,
      );
      return;
    }

    var remaining = todo.length;

    Future<void> runOne(SourceRule source) async {
      try {
        final books = await _parser.search(source, kw).timeout(sourceTimeout);
        // 相关度过滤 + 排序：上游是模糊匹配，会带回完全不相关的书
        final ranked = [
          for (final b in SearchRelevance.rank(books, kw))
            b.copyWith(author: SearchRelevance.cleanAuthor(b.author)),
        ];
        if (ranked.isNotEmpty) {
          grouped[source.sourceId] = ranked;
          // 增量写缓存：用户中途返回上一页也留得住（此前只在全部完成时写）
          _mergeCache(kw, source.sourceId, ranked);
          if (mounted) {
            final ordered = _ordered(grouped);
            state = state.copyWith(
              results: [for (final list in ordered.values) ...list],
              groupedResults: ordered,
              // 还有源在跑就继续显示加载态（顶部细进度）
              isLoading: remaining > 1,
            );
          }
        }
      } catch (e) {
        debugPrint('Search error for ${source.sourceName}: $e');
      } finally {
        remaining--;
        if (remaining == 0 && mounted) {
          final ordered = _ordered(grouped);
          state = state.copyWith(
            isLoading: false,
            results: [for (final list in ordered.values) ...list],
            groupedResults: ordered,
            error: ordered.isEmpty ? AppStrings.searchNoResult : null,
          );
        }
      }
    }

    // 简单并发池：最多 maxConcurrent 个源同时在跑
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < todo.length) {
        final source = todo[cursor++];
        await runOne(source);
      }
    }

    await Future.wait([
      for (var i = 0; i < maxConcurrent && i < todo.length; i++) worker(),
    ]);
  }

  void _mergeCache(String kw, String sourceId, List<Book> books) {
    final at = _cacheAt[kw];
    final expired = at == null || DateTime.now().difference(at) > cacheTtl;
    final map = expired ? <String, List<Book>>{} : (_cache[kw] ?? <String, List<Book>>{});
    map[sourceId] = books;
    _cache[kw] = map;
    _cacheAt[kw] = DateTime.now();
  }

  /// 按书源配置顺序重排分组结果。
  ///
  /// 并发 + 渐进出结果会让分组按「谁先回来」插入，列表顺序会跳；
  /// 固定成配置顺序，用户看到的分组位置才稳定。
  Map<String, List<Book>> _ordered(Map<String, List<Book>> grouped) {
    if (grouped.isEmpty) return const {};
    final out = <String, List<Book>>{};
    for (final s in _sources) {
      final list = grouped[s.sourceId];
      if (list != null && list.isNotEmpty) out[s.sourceId] = list;
    }
    // 兜底：配置里没有的源（理论上不该有）也保留，别丢结果
    for (final e in grouped.entries) {
      out.putIfAbsent(e.key, () => e.value);
    }
    return out;
  }

  Map<String, List<Book>>? _readCache(String kw) {
    final at = _cacheAt[kw];
    if (at == null) return null;
    if (DateTime.now().difference(at) > cacheTtl) {
      _cache.remove(kw);
      _cacheAt.remove(kw);
      return null;
    }
    return _cache[kw];
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

    // 只有「一个结果都还没有」时才占满屏转圈。
    // 渐进出结果后 isLoading 仍可能为 true（慢源还没回），
    // 若此时还走全屏加载态，已回来的结果就又被盖住了。
    if (searchState.isLoading && searchState.results.isEmpty) {
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
      return _SearchIdle(onTapKeyword: _searchKeyword);
    }

    final sources = ref.read(sourcesProvider);
    final groupedResults = searchState.groupedResults;
    final sourceIds = groupedResults.keys.toList();

    return Column(
      children: [
        // 慢源还在跑时给一条轻量提示，别让用户以为搜完了
        if (searchState.isLoading)
          Container(
            width: double.infinity,
            color: c.muted,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.mutedForeground,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '其他书源仍在搜索…',
                  style: TextStyle(
                    color: c.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _buildResultList(context, sourceIds, groupedResults, sources),
        ),
      ],
    );
  }

  Widget _buildResultList(
    BuildContext context,
    List<String> sourceIds,
    Map<String, List<Book>> groupedResults,
    List<SourceRule> sources,
  ) {
    final c = context.appColors;
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
    // 记录搜索历史（聆阅 `search_history_v1`），失败不影响搜索。
    ref.read(searchHistoryProvider.notifier).record(keyword);
    ref.read(searchProvider.notifier).search(keyword);
  }

  /// 点历史/热门词直接搜索。
  void _searchKeyword(String keyword) {
    _searchController.text = keyword;
    setState(() {});
    _onSearch(keyword);
  }

  void _openBookDetail(Book book) {
    final sources = ref.read(sourcesProvider);
    final source = sources.firstWhere(
      (s) => s.sourceId == book.sourceId,
      orElse: () => sources.first,
    );

    ref.read(bookDetailProvider.notifier).loadBook(book, source);
    context.push(bookDetailRouteForBook(book));
  }
}

/// 搜索空闲态：搜索历史 + 热门搜索（聆阅 `search_history_v1` 契约）。
///
/// 历史为空时只显示热门搜索，且不显示「清空」按钮 —— 没东西可清。
class _SearchIdle extends ConsumerWidget {
  const _SearchIdle({required this.onTapKeyword});

  final void Function(String keyword) onTapKeyword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final history = ref.watch(searchHistoryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.history, size: 18, color: c.mutedForeground),
              const SizedBox(width: 6),
              Text(
                AppStrings.searchHistory,
                style: TextStyle(
                  color: c.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                child: const Text(AppStrings.clear),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kw in history)
                _KeywordChip(text: kw, onTap: () => onTapKeyword(kw)),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            Icon(Icons.local_fire_department_outlined,
                size: 18, color: c.mutedForeground),
            const SizedBox(width: 6),
            Text(
              AppStrings.searchHot,
              style: TextStyle(
                color: c.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kw in SearchHistoryStore.hotKeywords)
              _KeywordChip(text: kw, onTap: () => onTapKeyword(kw)),
          ],
        ),
        const SizedBox(height: 36),
        Center(
          child: Text(
            AppStrings.searchIdleHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.mutedForeground, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.muted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6E1F5), width: 1.2),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: c.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
