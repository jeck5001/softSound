import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/services/edge_gate.dart';
import 'package:soft_sound/services/kuwo_rank_api.dart';
import 'package:soft_sound/services/lrts_rank_api.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_widgets.dart';

/// 排行榜页 —— 对应聆阅的 `ranking.tsx`。
///
/// 双书源：
/// - 酷我榜：`kuwo-rank-tabs` / `kuwo-rank-data?tabId=`（实测契约）
/// - 懒人榜：`lrts-rank?rankId=&rangeType=`（2026-10-16 字节码 #18082 挖掘，
///   8 个真实榜单；书籍自带标题/作者/播音，每榜约 100 本）
class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage> {
  /// 当前书源：false=酷我，true=懒人。
  bool _lrts = false;

  /// 酷我页签（来自 kuwo-rank-tabs）；加载前为空。
  List<KuwoRankTab> _kuwoTabs = const [];

  /// 酷我当前选中页签。
  KuwoRankTab? _currentKuwo;

  /// 懒人当前选中页签（页签是字节码常量，无需加载）。
  LrtsRankTab? _currentLrts;

  /// 当前榜单书籍（两源共用行模型）。
  List<KuwoRankBook> _books = const [];

  bool _loadingTabs = true;
  bool _loadingBooks = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    if (_lrts) {
      // 懒人榜页签为字节码常量：直接选中第一个并加载数据。
      setState(() {
        _loadingTabs = false;
        _error = null;
      });
      await _selectLrts(LrtsRankApi.tabs.first);
      return;
    }
    setState(() {
      _loadingTabs = true;
      _error = null;
    });
    try {
      final api = ref.read(kuwoRankApiProvider);
      final tabs = await api.fetchTabs();
      if (!mounted) return;
      // `fetchTabs()` 拿不到数据时返回空列表（不抛）。空列表**不等于**
      // 「服务端没有页签」：429 被闸门收口后也是空。这里必须显式报错，
      // 否则页面会静默落到「暂无数据」，看起来像榜单真的空了。
      if (tabs.isEmpty) {
        setState(() {
          _loadingTabs = false;
          _error = AppStrings.rankBusy;
        });
        return;
      }
      setState(() {
        _kuwoTabs = tabs;
        _loadingTabs = false;
      });
      // 默认加载第一个页签的数据
      await _selectKuwo(tabs.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTabs = false;
        _error = _describe(e);
      });
    }
  }

  /// 把异常翻译成用户能看懂的一句话。
  ///
  /// Edge 后端是项目级并发配额，取不到数据**最常见的原因不是网络**，
  /// 而是 429；统一报「网络失败」会把人引到错误方向。
  static String _describe(Object e) {
    if (e is EdgeUnavailableException) return AppStrings.rankBusy;
    final text = '$e';
    if (text.contains('projectConcurrencyLimitExceeded') ||
        text.contains('429')) {
      return AppStrings.rankBusy;
    }
    return AppStrings.loadFailedNetwork;
  }

  /// 切换书源（保留已加载的酷我页签，不重复请求 tabs）。
  Future<void> _switchSource(bool lrts) async {
    if (lrts == _lrts) return;
    setState(() => _lrts = lrts);
    _books = const [];
    await _loadTabs();
  }

  Future<void> _selectKuwo(KuwoRankTab tab) async {
    setState(() {
      _currentKuwo = tab;
      _loadingBooks = true;
      _error = null;
    });
    try {
      final api = ref.read(kuwoRankApiProvider);
      final books = await api.fetchRankData(tab.id);
      if (!mounted) return;
      setState(() {
        _books = books;
        _loadingBooks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBooks = false;
        _error = _describe(e);
      });
    }
  }

  Future<void> _selectLrts(LrtsRankTab tab) async {
    setState(() {
      _currentLrts = tab;
      _loadingBooks = true;
      _error = null;
    });
    try {
      final api = ref.read(lrtsRankApiProvider);
      final books = await api.fetchRankBooks(tab);
      if (!mounted) return;
      setState(() {
        _books = books;
        _loadingBooks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBooks = false;
        _error = _describe(e);
      });
    }
  }

  /// 刷新当前榜单。
  Future<void> _refresh() async {
    if (_lrts) {
      await _selectLrts(_currentLrts ?? LrtsRankApi.tabs.first);
    } else if (_lrts == false && !_loadingTabs) {
      final tab = _currentKuwo;
      if (tab != null) {
        await _selectKuwo(tab);
      } else {
        await _loadTabs();
      }
    } else {
      await _loadTabs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navRanking),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.reload,
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loadingTabs
          ? const AppLoadingState(message: AppStrings.loadingRanking)
          : (_error != null && _books.isEmpty && !_lrts)
              ? AppErrorState(
                  message: _error!,
                  onRetry: _loadTabs,
                )
              : Column(
                  children: [
                    // 书源切换
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('酷我榜'),
                            selected: !_lrts,
                            onSelected: (_) => _switchSource(false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('懒人榜'),
                            selected: _lrts,
                            onSelected: (_) => _switchSource(true),
                          ),
                        ],
                      ),
                    ),

                    // 页签
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        children: _lrts
                            ? [
                                for (final t in LrtsRankApi.tabs)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: ChoiceChip(
                                      label: Text(t.name),
                                      selected: t.rankId ==
                                          (_currentLrts?.rankId ?? -1),
                                      onSelected: (_) => _selectLrts(t),
                                    ),
                                  ),
                              ]
                            : [
                                for (final t in _kuwoTabs)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: ChoiceChip(
                                      label: Text(t.name),
                                      selected:
                                          t.id == (_currentKuwo?.id ?? ''),
                                      onSelected: (_) => _selectKuwo(t),
                                    ),
                                  ),
                              ],
                      ),
                    ),
                    Divider(height: 1, color: c.border),

                    // 榜单内容
                    Expanded(
                      child: _loadingBooks
                          ? const AppLoadingState(
                              message: AppStrings.loadingRanking)
                          : (_books.isEmpty
                              ? (_error != null
                                  ? AppErrorState(
                                      message: _error!,
                                      onRetry: _refresh,
                                    )
                                  : AppEmptyState(
                                      icon: Icons.leaderboard_outlined,
                                      title: AppStrings.rankEmpty,
                                      description: AppStrings.loadingCategory,
                                      actionLabel: AppStrings.reload,
                                      onAction: _refresh,
                                    ))
                              : _buildList(context)),
                    ),
                  ],
                ),
    );
  }

  Widget _buildList(BuildContext context) {
    final c = context.appColors;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _books.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
        itemBuilder: (context, i) {
          final b = _books[i];
          return InkWell(
            // 带上封面：详情接口返回前，播放页/详情页先用榜单自带的真实封面，
            // 否则从榜单进来会有一段（甚至一直）没有封面图。
            onTap: () => context.push(
              '/book/${_lrts ? 'lrts' : 'xiaoKu'}_${b.id}'
              '?name=${Uri.encodeComponent(b.title)}'
              '${(b.cover != null && b.cover!.isNotEmpty) ? '&cover=${Uri.encodeComponent(b.cover!)}' : ''}',
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      b.rank.isEmpty ? '${i + 1}' : b.rank,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: i < 3 ? c.primary : c.mutedForeground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 封面缩略图（榜单响应自带真实 cover）
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 42,
                      height: 56,
                      child: (b.cover != null && b.cover!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: b.cover!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  _coverPlaceholder(c, b.title),
                              errorWidget: (_, __, ___) =>
                                  _coverPlaceholder(c, b.title),
                            )
                          : _coverPlaceholder(c, b.title),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.foreground, fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (b.author.isNotEmpty) b.author,
                            if (b.playCount.isNotEmpty &&
                                b.playCount != '–')
                              '${b.playCount} 播放',
                            if (b.chapterCount.isNotEmpty &&
                                b.chapterCount != '–')
                              '${b.chapterCount}${AppStrings.unitEpisode}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.mutedForeground, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 无封面/加载失败时的占位：取标题首字。
  Widget _coverPlaceholder(AppColors c, String title) {
    return Container(
      color: c.muted,
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title.substring(0, 1),
        style: TextStyle(
          color: c.mutedForeground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
