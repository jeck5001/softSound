import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/services/kuwo_rank_api.dart';
import 'package:soft_sound/services/app_sources.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_widgets.dart';

/// 发现页 —— 对应聆阅的 `(tabs)/explore.tsx`。
///
/// 承载分类导航与排行榜入口。分类优先取**线上分类树**
/// （`kuwo-classify`，2026-10-16 字节码 #17953 挖掘 + 实测确认，7 个大类），
/// 网络失败时回退到本地兜底（同一份实测数据的快照）。
/// 卡片配色/emoji/描述逐字还原自聆阅字节码 #21189。
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  /// 聆阅分类卡样式（categoryId → emoji / ARGB 主色 / 静态描述）。
  static const Map<String, ({String emoji, String accent, String desc})>
      _styles = {
    '2': (emoji: '📚', accent: 'FFA855F7', desc: '玄幻修真 · 都市爽文 · 悬疑惊悚'),
    '8': (emoji: '🎙️', accent: 'FFFFB800', desc: '大师经典 · 评书相声 · 戏曲荟萃'),
    '1': (emoji: '🧸', accent: 'FF00FF87', desc: '睡前故事 · 国学启蒙 · 少儿名著'),
    '45': (emoji: '🏯', accent: 'FF38BDF8', desc: '百家讲坛 · 人物传记 · 哲学思考'),
    '7': (emoji: '💗', accent: 'FFFF2D78', desc: '情感夜话 · 治愈美文 · 睡前暖心'),
    '81': (emoji: '🌙', accent: 'FF00E5FF', desc: '白噪音 · 自然之声 · 催眠冥想'),
    '42': (emoji: '🎵', accent: 'FFFFD60A', desc: '热歌神曲 · 影视原声 · 经典流行'),
  };

  /// 兜底分类的显示名（与 2026-10-16 真实响应 sections 一致）。
  static const Map<String, String> _fallbackNames = {
    '2': '有声小说',
    '1': '儿童',
    '8': '相声曲艺',
    '81': '助眠解压',
    '7': '两性情感',
    '42': '音乐娱乐',
    '45': '历史人文',
  };

  static String _emojiByName(String name) {
    if (name.contains('儿童') || name.contains('少儿')) return '🧸';
    if (name.contains('历史') || name.contains('人文')) return '🏯';
    if (name.contains('音乐')) return '🎵';
    if (name.contains('相声') || name.contains('曲艺')) return '🎙️';
    if (name.contains('助眠') || name.contains('情感')) return '🌙';
    return '📖';
  }

  /// 统一分类卡记录：chips 携带跳转路由（源1 → /category，源2 → /lrts-category）。
  static ({String route, String name, String desc, String emoji, Color accent,
      List<({String name, String route})> chips}) _kuwoCard(
      String categoryId, String name, String desc, String emoji, Color accent,
      List<KuwoClassifyChild> children) {
    return (
      route: '/category/$categoryId?name=${Uri.encodeComponent(name)}',
      name: name,
      desc: desc,
      emoji: emoji,
      accent: accent,
      chips: [
        for (final ch in children)
          (
            name: ch.name,
            route: '/category/${ch.categoryId}'
                '?name=${Uri.encodeComponent(ch.name)}'
                '&classify=${ch.classifyId}',
          ),
      ],
    );
  }

  /// 源1（酷我）分类卡：线上树优先（desc 用服务端热榜文案 + 子类 chips），
  /// 失败用样式表快照。
  static List<({String route, String name, String desc, String emoji,
      Color accent, List<({String name, String route})> chips})>
      _categories(List<KuwoClassifySection>? live) {
    if (live != null && live.isNotEmpty) {
      return [
        for (final x in live)
          _kuwoCard(
            x.categoryId,
            x.name,
            (x.desc != null && x.desc!.isNotEmpty)
                ? x.desc!
                : (_styles[x.categoryId]?.desc ?? ''),
            _styles[x.categoryId]?.emoji ?? _emojiByName(x.name),
            Color(int.parse(
                _styles[x.categoryId]?.accent ?? 'FFA855F7', radix: 16)),
            x.children,
          ),
      ];
    }
    return [
      for (final e in _fallbackNames.entries)
        _kuwoCard(
          e.key,
          e.value,
          _styles[e.key]?.desc ?? e.value,
          _styles[e.key]?.emoji ?? _emojiByName(e.value),
          Color(int.parse(
              _styles[e.key]?.accent ?? 'FFA855F7', radix: 16)),
          const <KuwoClassifyChild>[],
        ),
    ];
  }

  /// 源2（懒人听书）分类卡：字节码 SOURCE2_CATEGORIES 静态树（11 大类 82 子类）。
  static List<({String route, String name, String desc, String emoji,
      Color accent, List<({String name, String route})> chips})>
      _lrtsCategories() {
    return [
      for (final p in source2Categories)
        (
          route: '/lrts-category/${p.lrtsId}'
              '?name=${Uri.encodeComponent(p.name)}',
          name: p.name,
          desc: p.desc,
          emoji: p.icon,
          accent: Color(p.accent),
          chips: [
            for (final c in p.children)
              (
                name: c.name,
                route: '/lrts-category/${c.id}'
                    '?name=${Uri.encodeComponent(c.name)}',
              ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSourceProvider);
    final categories = active == LySource.lrts
        ? _lrtsCategories()
        : _categories(ref.watch(kuwoClassifyProvider).valueOrNull);

    return Scaffold(
      appBar: AppBar(
        title: Text(active == LySource.lrts
            ? '${AppStrings.navExplore} · ${active.label}'
            : AppStrings.navExplore),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: AppStrings.searchAction,
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 搜索入口
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _SearchEntry(onTap: () => context.push('/search')),
          ),

          // 排行榜入口
          const AppSectionHeader(title: AppStrings.navRanking),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _RankingEntry(onTap: () => context.push('/ranking')),
          ),

          // 分类区（聆阅「全部分类」大卡 + 子类 chips）
          const AppSectionHeader(title: AppStrings.navCategory),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                for (final e in categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SectionCard(
                      route: e.route,
                      name: e.name,
                      desc: e.desc,
                      emoji: e.emoji,
                      accent: e.accent,
                      chips: e.chips,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
          // 聆阅 SourceSwitchBadge：右下角悬浮「源1/源2」胶囊
          Positioned(
            right: 12,
            bottom: 130,
            child: _SourceSwitchBadge(
              active: active,
              onSelect: (src) =>
                  ref.read(activeSourceProvider.notifier).set(src),
            ),
          ),
        ],
      ),
    );
  }
}

/// 发现页搜索入口。
class _SearchEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.muted,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: c.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.searchHint,
                style: TextStyle(color: c.mutedForeground, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 排行榜入口卡片。
class _RankingEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _RankingEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.leaderboard_outlined,
                  color: c.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.navRanking,
                    style: TextStyle(
                      color: c.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.loadingRanking,
                    style: TextStyle(color: c.mutedForeground, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.mutedForeground, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 分类大区卡（聆阅「全部分类」样式：emoji 盒 + 名称 + N个子类 chip + 子类 chips）。
class _SectionCard extends StatelessWidget {
  final String route;
  final String name;
  final String desc;
  final String emoji;
  final Color accent;
  final List<({String name, String route})> chips;

  const _SectionCard({
    required this.route,
    required this.name,
    required this.desc,
    required this.emoji,
    required this.accent,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push(route),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.mutedForeground, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (chips.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${chips.length} 个子类',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final ch in chips)
                    GestureDetector(
                      onTap: () => context.push(ch.route),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.muted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          ch.name,
                          style: TextStyle(
                            color: c.foreground,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 聆阅 SourceSwitchBadge（字节码 #21193）：右下悬浮「源1/源2」竖排胶囊。
class _SourceSwitchBadge extends StatelessWidget {
  final LySource active;
  final ValueChanged<LySource> onSelect;

  const _SourceSwitchBadge({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBD8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF5C99A)),
        boxShadow: const [
          BoxShadow(color: Color(0x331C1917), offset: Offset(2, 3), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _half(LySource.kuwo),
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _half(LySource.lrts),
        ],
      ),
    );
  }

  Widget _half(LySource src) {
    final isActive = src == active;
    return GestureDetector(
      onTap: () => onSelect(src),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text(
          src.badge,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
            color: isActive ? const Color(0xFF1C1917) : const Color(0xFFA8A29E),
          ),
        ),
      ),
    );
  }
}
