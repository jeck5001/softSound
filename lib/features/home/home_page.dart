import 'package:cached_network_image/cached_network_image.dart';
import 'package:soft_sound/app/book_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/services/last_played_service.dart';
import 'package:soft_sound/services/lrts_home_api.dart';
import 'package:soft_sound/services/player_service.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/brand_widgets.dart';

/// 首页 —— 按聆阅 `(tabs)/home.tsx` 真机截图 1:1 复刻版式（2026-10-16）。
///
/// 设计语言（截图取色 #F5F4FF 淡紫底）：
/// - 大字品牌头「聆阅」+ AUDIO UNIVERSE 眉标 + 三色下划条
/// - 2×2 深色霓虹描边快捷卡（金/品红/绿/青，取色自聆阅卡片）
/// - 图片驱动栏目轮播：精选焦点（金边大卡）+ 各分区（彩色描边封面卡）
/// - 数据源：`lrts-home`（15 栏目真实推荐流，字节码 #18036 契约）
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// 栏目配色循环（聆阅各分区描边色采样 + 同族扩展）。
  static const List<int> _palette = [
    0xFFD4A017, // 金
    0xFFFF2D78, // 品红
    0xFF8B5CF6, // 紫
    0xFF00E5FF, // 青
    0xFF00FF87, // 绿
    0xFFFF6B00, // 橙
    0xFF3B82F6, // 蓝
    0xFFEF4444, // 红
  ];

  static const Map<String, String> _labelEmoji = {
    '恐怖': '👻',
    '悬疑': '🕵️',
    '推荐': '⭐',
    '焦点': '⭐',
    '限免': '🎁',
    '玄幻': '⚔️',
    '言情': '💗',
    '历史': '📜',
    '儿童': '🧸',
  };

  static const Map<String, String> _labelBadgeEn = {
    '恐怖专区': 'HORROR',
    '精选焦点': 'FOCUS',
  };

  static String emojiFor(String label) {
    for (final e in _labelEmoji.entries) {
      if (label.contains(e.key)) return e.value;
    }
    return '🔥';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final home = ref.watch(lrtsHomeProvider);
    final data = home.valueOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const _BrandHeader(),
            const SizedBox(height: 16),
            const _SearchPill(),
            const SizedBox(height: 16),
            // 「继续收听」卡片（聆阅 #21364 ResumeListenHint）：
            // 有上次播放记录才显示，点击直接回到播放页接着听。
            const _ResumeListenCard(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _QuickCards2x2(),
            ),

            if (data != null && !data.isEmpty) ...[
              const _SectionHeader(
                title: '精选焦点',
                barColor: Color(0xFF8B5CF6),
                badge: 'FOCUS',
              ),
              _FocusCarousel(books: _focusBooks(data)),

              for (var i = 0; i < data.sections.length && i < 8; i++) ...[
                _SectionHeader(
                  title: data.sections[i].label,
                  barColor: Color(_palette[i % _palette.length]),
                  badge: _labelBadgeEn[data.sections[i].label],
                  emojiBadge:
                      data.sections[i].label.contains('恐怖') ? '👻' : null,
                ),
                // 聆阅双形态：偶数分区=封面轮播，奇数分区=奖牌行卡
                if (i.isOdd)
                  _RowListSection(
                    books: data.sections[i].books,
                    accent: Color(_palette[i % _palette.length]),
                  )
                else
                  _SectionCarousel(
                    books: data.sections[i].books,
                    accent: Color(_palette[i % _palette.length]),
                  ),
              ],
            ] else if (home.isLoading) ...[
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                child: Text(
                  '推荐流暂不可用（后端限流），可先用上方入口与搜索',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.mutedForeground, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 精选焦点书目：top books + 各栏目书合并去重取 8。
  static List<LrtsHomeBook> _focusBooks(LrtsHomeData data) {
    final seen = <String>{};
    final out = <LrtsHomeBook>[];
    for (final b in [
      ...data.books,
      for (final s in data.sections) ...s.books,
    ]) {
      if (seen.add(b.id)) out.add(b);
      if (out.length >= 8) break;
    }
    return out;
  }
}

/// 品牌头：◆ AUDIO UNIVERSE / 聆阅 / 三色条 / 副标题。
/// 「继续收听」卡片 —— 对应聆阅首页 `ResumeListenHint`。
///
/// 文案（字节码 #21364 逐字）：眉标 `继续收听`、副标 `上次收听记录已就绪`、
/// 标题 `上次收听的有声书`、正文 `第 N 章 · 听到 mm:ss`、按钮 `续播`。
///
/// 数据来自本地播放历史（[lastPlayedProvider]）；播放器里已有会话时
/// （刚播完切页签）就不再重复提示。
class _ResumeListenCard extends ConsumerWidget {
  const _ResumeListenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final playing = ref.watch(playerProvider).currentBook;
    final async = ref.watch(lastPlayedProvider);

    // 已经在播放/已装载会话时不打扰
    if (playing != null) return const SizedBox.shrink();

    final last = async.valueOrNull;
    if (last == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () async {
          // 先恢复会话（章节 + 进度），再进播放页；进页面后由用户点播放。
          // force：启动时那次可能已失败，这里必须允许重试
          final ok =
              await ref.read(sessionRestorerProvider).restoreOnce(force: true);
          if (!context.mounted) return;
          if (ok) {
            context.push('/player');
          } else {
            // 章节拉取失败：退回详情页，让用户在那里重试
            context.push(bookDetailRouteForBook(last.book));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAB308), width: 2),
            boxShadow: lyHardShadowSm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: (last.book.coverUrl ?? '').startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: last.book.coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: const Color(0xFFFEF3C7)),
                        )
                      : Container(
                          color: const Color(0xFFFEF3C7),
                          child: const Icon(Icons.headphones_rounded,
                              color: Color(0xFFB45309)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.continuePlay,
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last.book.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.mutedForeground,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAB308),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF000000), width: 1.5),
                ),
                child: const Text(
                  AppStrings.resumeAction,
                  style: TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('◆',
                  style: TextStyle(
                      color: Color(0xFF6D28D9), fontSize: 13)),
              SizedBox(width: 6),
              // 眉标是等距大写字母，窄屏（320dp）下自然宽度会顶破一行；
              // Flexible + scaleDown 让它在空间不足时整体微缩而不是溢出/截断。
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A U D I O   U N I V E R S E',
                    style: TextStyle(
                      color: Color(0xFF6D28D9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.appName,
            style: TextStyle(
              color: c.foreground,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          const Row(
            children: [
              _Dash(Color(0xFF6D28D9), 64),
              SizedBox(width: 6),
              _Dash(Color(0xFFEF4444), 24),
              SizedBox(width: 6),
              _Dash(Color(0xFF14B8A6), 10),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '精选大作 · 随时随地沉浸收听',
            style: TextStyle(color: Color(0xFF6D28D9), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Dash extends StatelessWidget {
  final Color color;
  final double width;

  const _Dash(this.color, this.width);

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

/// 搜索胶囊（白底紫描边 + 源切换 chip）。
class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/search'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: Color(0xFF6D28D9)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '搜索书名、作者、分类…',
                  style: TextStyle(color: c.mutedForeground, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/sources'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '源1',
                    style: TextStyle(
                      color: Color(0xFF6D28D9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2×2 深色霓虹描边快捷卡（聆阅取色：金/品红/绿/青）。
class _QuickCards2x2 extends StatelessWidget {
  const _QuickCards2x2();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 2.2,
      children: const [
        _NeonCard(
          emoji: '🏆',
          title: '排行榜',
          bg: Color(0xFF211700),
          border: Color(0xFFEAB308),
          text: Color(0xFFFACC15),
          route: '/ranking',
        ),
        _NeonCard(
          emoji: '🔥',
          title: '热歌神曲',
          bg: Color(0xFF210013),
          border: Color(0xFFFF2D78),
          text: Color(0xFFFF5C93),
          route: '/category/42?name=%E9%9F%B3%E4%B9%90%E5%A8%B1%E4%B9%90',
        ),
        _NeonCard(
          emoji: '🧸',
          title: '亲子儿童',
          bg: Color(0xFF001F12),
          border: Color(0xFF00FF87),
          text: Color(0xFF34D399),
          route: '/category/1?name=%E5%84%BF%E7%AB%A5',
        ),
        _NeonCard(
          emoji: '🎭',
          title: '相声评书',
          bg: Color(0xFF001820),
          border: Color(0xFF00E5FF),
          text: Color(0xFF22D3EE),
          route: '/category/8?name=%E7%9B%B8%E5%A3%B0%E6%9B%B2%E8%89%BA',
        ),
      ],
    );
  }
}

class _NeonCard extends StatelessWidget {
  final String emoji;
  final String title;
  final Color bg;
  final Color border;
  final Color text;
  final String route;

  const _NeonCard({
    required this.emoji,
    required this.title,
    required this.bg,
    required this.border,
    required this.text,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 2),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border.withValues(alpha: 0.6)),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: text,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 右上角旋转小方块装饰（聆阅同款）
            Positioned(
              top: 8,
              right: 8,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: border.withValues(alpha: 0.5), width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 栏目标题：色条 + 标题 + 徽章（英文 chip 或 emoji）。
class _SectionHeader extends StatelessWidget {
  final String title;
  final Color barColor;
  final String? badge;
  final String? emojiBadge;

  const _SectionHeader({
    required this.title,
    required this.barColor,
    this.badge,
    this.emojiBadge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 18,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  color: barColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ] else if (emojiBadge != null) ...[
            const SizedBox(width: 8),
            Text(emojiBadge!, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

/// 精选焦点：金边大卡横向轮播。
class _FocusCarousel extends StatelessWidget {
  final List<LrtsHomeBook> books;

  const _FocusCarousel({required this.books});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    const gold = Color(0xFFD4A017);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final b = books[i];
          return InkWell(
            onTap: () => context.push(
                bookDetailRoute(
                  'lrts_${b.id}',
                  name: b.title,
                  cover: b.cover,
                )),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? gold.withValues(alpha: 0.08)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gold, width: 2.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Cover(
                          url: b.cover,
                          w: 88,
                          h: 116,
                          radius: 12,
                          border: gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (b.category.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1917),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  b.category,
                                  style: const TextStyle(
                                    color: Color(0xFFFACC15),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              b.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.foreground,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b.narrator.isNotEmpty
                                  ? '${b.narrator} 演播'
                                  : b.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: c.mutedForeground, fontSize: 12),
                            ),
                            if (b.rating != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '★ ${b.rating!.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Color(0xFFEA580C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    b.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.mutedForeground, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 分区封面卡横向轮播（彩色描边 + emoji 角标）。
class _SectionCarousel extends StatelessWidget {
  final List<LrtsHomeBook> books;
  final Color accent;

  const _SectionCarousel({required this.books, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (books.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 226,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length > 10 ? 10 : books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final b = books[i];
          return InkWell(
            onTap: () => context.push(
                bookDetailRoute(
                  'lrts_${b.id}',
                  name: b.title,
                  cover: b.cover,
                )),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 124,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _Cover(
                        url: b.cover,
                        w: 124,
                        h: 168,
                        radius: 14,
                        border: accent,
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            HomePage.emojiFor(b.category),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (b.listeners.isNotEmpty && b.listeners != '–')
                    Text(
                      b.listeners,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: c.mutedForeground, fontSize: 11),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 奖牌行卡分区（聆阅「经典摸金探险」样式：描边行卡 + 🥇🥉 + 火焰按钮）。
class _RowListSection extends StatelessWidget {
  final List<LrtsHomeBook> books;
  final Color accent;

  const _RowListSection({required this.books, required this.accent});

  static const _medals = ['🥇', '', '🥉'];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final list = books.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => context.push(bookDetailRoute(
                  'lrts_${list[i].id}',
                  name: list[i].title,
                  cover: list[i].cover,
                )),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          i < 3 ? _medals[i] : '${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: i < 3 ? 20 : 14,
                            fontWeight: FontWeight.w800,
                            color: c.mutedForeground,
                          ),
                        ),
                      ),
                      _Cover(
                        url: list[i].cover,
                        w: 48,
                        h: 60,
                        radius: 10,
                        border: accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              list[i].description.isEmpty
                                  ? list[i].author
                                  : list[i].description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: c.mutedForeground, fontSize: 11),
                            ),
                            if (list[i].listeners.isNotEmpty &&
                                list[i].listeners != '–')
                              Text(
                                list[i].listeners,
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.5)),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🔥',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 封面图（失败/加载中回退占位）。
class _Cover extends StatelessWidget {
  final String url;
  final double w;
  final double h;
  final double radius;
  final Color? border;

  const _Cover({
    required this.url,
    required this.w,
    required this.h,
    required this.radius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          border: border == null
              ? null
              : Border.all(color: border!.withValues(alpha: 0.9), width: 2),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: url.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _ph(c),
                errorWidget: (_, __, ___) => _ph(c),
              )
            : _ph(c),
      ),
    );
  }

  Widget _ph(AppColors c) => Container(
        color: c.muted,
        alignment: Alignment.center,
        child: Icon(Icons.headphones_rounded,
            color: c.mutedForeground, size: 26),
      );
}
