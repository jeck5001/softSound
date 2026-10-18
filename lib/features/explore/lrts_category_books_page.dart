import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/services/lrts_category_api.dart';
import 'package:soft_sound/services/lrts_home_api.dart' show LrtsHomeBook;
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/brand_widgets.dart';

/// 懒人听书分类书籍列表页 —— 聆阅 `lrts-category/[id].tsx` 的 Flutter 等价。
///
/// 数据：`LrtsCategoryApi`（Edge lrts-category 优先 + 直连 HTML 兜底，
/// 均为 2026-10-16 实测契约）。滚动到底自动翻页。
class LrtsCategoryBooksPage extends ConsumerStatefulWidget {
  final String categoryId;
  final String name;

  const LrtsCategoryBooksPage({
    super.key,
    required this.categoryId,
    required this.name,
  });

  @override
  ConsumerState<LrtsCategoryBooksPage> createState() =>
      _LrtsCategoryBooksPageState();
}

class _LrtsCategoryBooksPageState extends ConsumerState<LrtsCategoryBooksPage> {
  final _books = <LrtsHomeBook>[];
  final _scroll = ScrollController();
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400 &&
        _hasMore &&
        !_loadingMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _books.clear();
      _hasMore = true;
    });
    try {
      final api = ref.read(lrtsCategoryApiProvider);
      final r = await api.fetch(widget.categoryId, page: 1);
      if (!mounted) return;
      setState(() {
        _books.addAll(r.books);
        _total = r.total;
        _loading = false;
        _hasMore = _books.length < _total && r.books.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败，下拉重试';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final api = ref.read(lrtsCategoryApiProvider);
      final next = _page + 1;
      final r = await api.fetch(widget.categoryId, page: next);
      if (!mounted) return;
      setState(() {
        if (r.books.isNotEmpty) {
          _page = next;
          _books.addAll(r.books);
        }
        _total = r.total > 0 ? r.total : _total;
        _loadingMore = false;
        _hasMore = r.books.isNotEmpty && _books.length < _total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_books.isEmpty && _error == null
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text('该分类暂无书籍',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _books.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i >= _books.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        );
                      }
                      return _bookRow(c, _books[i]);
                    },
                  )),
      ),
    );
  }

  /// 书籍行卡（聆阅行式：封面 + 标题 + 作者/演播 + 播放量/评分）。
  Widget _bookRow(AppColors c, LrtsHomeBook b) {
    return GestureDetector(
      onTap: () => context.push(
          '/book/lrts_${b.id}?name=${Uri.encodeComponent(b.title)}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E1F5)),
        ),
        child: Row(
          children: [
            LyCover(url: b.cover, width: 64, height: 84, radius: 12, offsetCard: false),
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (b.author.isNotEmpty) b.author,
                      if (b.narrator.isNotEmpty && b.narrator != b.author)
                        '${b.narrator} 演播',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.mutedForeground, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (b.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFEA580C)),
                        Text(
                          ' ${b.rating!.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Color(0xFFEA580C),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (b.listeners.isNotEmpty && b.listeners != '–')
                        Flexible(
                          child: Text(
                            b.listeners,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.mutedForeground, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFA8A29E)),
          ],
        ),
      ),
    );
  }
}
