import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/services/kuwo_rank_api.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_widgets.dart';

/// 分类书籍列表页 —— 对应聆阅的「书目列表」。
///
/// 数据来自聆阅后端 `kuwo-albums?classifyId=&categoryId=&pn=&rn=`（实测契约）。
/// 点击书籍进入详情（`/book/:bookId`，detailUrl 承载酷我 albumId）。
class CategoryBooksPage extends ConsumerStatefulWidget {
  final String categoryId;
  final String name;

  /// 预选子分类（聆阅分类页子类 chip 跳转时携带的 classifyId）。
  final String? classifyId;

  const CategoryBooksPage({
    super.key,
    required this.categoryId,
    required this.name,
    this.classifyId,
  });

  @override
  ConsumerState<CategoryBooksPage> createState() => _CategoryBooksPageState();
}

class _CategoryBooksPageState extends ConsumerState<CategoryBooksPage> {
  final _books = <KuwoRankBook>[];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  /// 子频道（该分类下的频道页签，如「郭德纲」「评书大全」）。
  List<KuwoChannel> _channels = const [];
  String? _selectedChannel; // classifyId；null 表示全部（classifyId=0）

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.classifyId;
    _scroll.addListener(_onScroll);
    _initialLoad();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || !_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _initialLoad() async {
    setState(() => _loading = true);
    final api = ref.read(kuwoRankApiProvider);

    // 并行拉子频道与第一页书籍
    final results = await Future.wait([
      api.fetchChannels(widget.categoryId),
      api.fetchAlbums(categoryId: widget.categoryId, page: 1),
    ]);

    if (!mounted) return;
    setState(() {
      _channels = results[0] as List<KuwoChannel>;
      final page = results[1] as KuwoAlbumPage;
      _books
        ..clear()
        ..addAll(page.books);
      _total = page.total;
      _hasMore = _books.length < _total;
      _page = 1;
      _loading = false;
      _error = _books.isEmpty ? AppStrings.categoryEmpty : null;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final api = ref.read(kuwoRankApiProvider);
    final page = await api.fetchAlbums(
      categoryId: widget.categoryId,
      classifyId: _selectedChannel ?? '0',
      page: _page + 1,
    );
    if (!mounted) return;
    setState(() {
      _books.addAll(page.books);
      _page += 1;
      _hasMore = _books.length < page.total && page.books.isNotEmpty;
      _loadingMore = false;
    });
  }

  /// 切换子频道（classifyId 变化，重新拉第一页）。
  Future<void> _switchChannel(String? classifyId) async {
    setState(() {
      _selectedChannel = classifyId;
      _loading = true;
    });
    final api = ref.read(kuwoRankApiProvider);
    final page = await api.fetchAlbums(
      categoryId: widget.categoryId,
      classifyId: classifyId ?? '0',
      page: 1,
    );
    if (!mounted) return;
    setState(() {
      _books
        ..clear()
        ..addAll(page.books);
      _total = page.total;
      _page = 1;
      _hasMore = _books.length < page.total;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _loading
          ? const AppLoadingState(message: AppStrings.loadingCategoryBooks)
          : Column(
              children: [
                // 子频道页签
                if (_channels.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: const Text(AppStrings.filterAll),
                            selected: _selectedChannel == null,
                            onSelected: (_) => _switchChannel(null),
                          ),
                        ),
                        for (final ch in _channels)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceChip(
                              label: Text(ch.name),
                              selected: _selectedChannel == ch.id,
                              onSelected: (_) => _switchChannel(ch.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_channels.isNotEmpty)
                  Divider(height: 1, color: c.border),

                // 书籍列表
                Expanded(
                  child: _error != null && _books.isEmpty
                      ? AppEmptyState(
                          icon: Icons.menu_book_outlined,
                          title: _error!,
                          description: AppStrings.offlineHint1,
                        )
                      : RefreshIndicator(
                          onRefresh: _initialLoad,
                          child: ListView.separated(
                            controller: _scroll,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _books.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: c.border),
                            itemBuilder: (context, i) {
                              if (i >= _books.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              return _buildBookRow(context, _books[i]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBookRow(BuildContext context, KuwoRankBook b) {
    final c = context.appColors;
    return InkWell(
      onTap: () => context.push('/book/xiaoKu_${b.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 74,
                child: (b.cover != null && b.cover!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: b.cover!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: c.muted),
                        errorWidget: (_, __, ___) =>
                            Container(color: c.muted),
                      )
                    : Container(
                        color: c.muted,
                        child: Icon(Icons.headphones,
                            size: 28, color: c.mutedForeground),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (b.playCount.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${b.playCount} 收听'
                      '${b.chapterCount.isNotEmpty ? ' · ${b.chapterCount}${AppStrings.unitEpisode}' : ''}',
                      style: TextStyle(
                          color: c.mutedForeground, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.mutedForeground),
          ],
        ),
      ),
    );
  }
}
