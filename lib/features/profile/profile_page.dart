import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/features/history/history_page.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/brand_widgets.dart';
import 'package:soft_sound/theme/theme_controller.dart';
import 'package:soft_sound/data/models/listener_stats.dart';
import 'package:soft_sound/data/repositories/stats_repository.dart';
import 'package:soft_sound/features/downloads/downloads_notifier.dart';

/// 我的页 —— 聆阅 `(tabs)/profile.tsx` 新粗野主义复刻（2026-10-16 截图）。
///
/// 视觉签名：白色硬阴影卡 + 彩色 icon 盒 + 大号彩色数值 + 描边 chip。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final appearance = ref.watch(appearanceProvider);
    final stats = ref.watch(listenerStatsProvider).valueOrNull ??
        const ListenerStats();
    final downloads = ref.watch(downloadsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            // 英雄卡：听友身份 + 等级
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LyBrutalCard(
                borderColor: const Color(0xFFDDD6FE),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: const Color(0xFF7C3AED), width: 2.5),
                          ),
                          child: const Icon(Icons.headphones_rounded,
                              color: Color(0xFF7C3AED), size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // 抬头 + 右侧「永久畅听」徽章是一行硬约束：
                                  // 320dp 窄屏下 6 字抬头会把徽章挤出屏幕（实测溢出 39px）。
                                  // Flexible + scaleDown 让抬头按可用宽度微缩，
                                  // 徽章始终完整可见，且不会用省略号吞掉品牌名。
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        AppStrings.communityLabel,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: c.foreground,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: const Border(
                                        top: BorderSide(
                                            color: Color(0xFFEAB308)),
                                        bottom: BorderSide(
                                            color: Color(0xFFEAB308)),
                                        left: BorderSide(
                                            color: Color(0xFFEAB308)),
                                        right: BorderSide(
                                            color: Color(0xFFEAB308)),
                                      ),
                                    ),
                                    child: const Text(
                                      '永久畅听',
                                      style: TextStyle(
                                        color: Color(0xFFB45309),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '沉浸声音宇宙 · 听见世间百态',
                                style: TextStyle(
                                    color: c.mutedForeground, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 两个等级胶囊在窄屏下合计宽度会超过一行（实测 360dp 溢出 61px）。
                    // 用 Wrap 让第二个换行，而不是 Expanded 挤压或 ellipsis 吞掉
                    // 「距 X 还需 N 分钟」这类关键进度信息。
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _LevelPill(
                          label: stats.currentLevel.title,
                          bg: const Color(0xFFCCFBF1),
                          border: const Color(0xFF0D9488),
                          fg: const Color(0xFF0F766E),
                        ),
                        _LevelPill(
                          label: stats.isMaxLevel
                              ? '已达顶级'
                              : '距 ${stats.nextLevel!.title} 还需'
                                  '${stats.minutesToNextLevel} 分钟',
                          bg: const Color(0xFFF3E8FF),
                          border: const Color(0xFFA855F7),
                          fg: const Color(0xFF7E22CE),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2×2 统计卡
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.9,
                children: [
                  _StatCard(
                    label: '累计听书',
                    value: stats.formattedListening,
                    color: const Color(0xFF0D9488),
                    icon: Icons.schedule_rounded,
                    onTap: () => context.push('/history'),
                  ),
                  _StatCard(
                    label: '我的收藏',
                    value: '${stats.favoriteCount} 本',
                    color: const Color(0xFFE11D48),
                    icon: Icons.favorite_rounded,
                    onTap: () => context.go('/shelf'),
                  ),
                  _StatCard(
                    label: '离线下载',
                    value: '${downloads.completed.length} 集',
                    color: const Color(0xFF059669),
                    icon: Icons.download_rounded,
                    onTap: () => context.push('/downloads'),
                  ),
                  _StatCard(
                    label: '听书记录',
                    // 与历史页同源：都数「能看到的那几条记录」，
                    // 避免「我的 3 条 / 历史页 1 条」自相矛盾。
                    value: '${ref.watch(historyEntriesProvider).valueOrNull?.length ?? 0} 条',
                    color: const Color(0xFFD97706),
                    icon: Icons.headphones_rounded,
                    onTap: () => context.push('/history'),
                  ),
                ],
              ),
            ),

            // 同步卡
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LyBrutalCard(
                borderColor: const Color(0xFFDDD6FE),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF8B5CF6), width: 2),
                      ),
                      child: const Icon(Icons.key_outlined,
                          color: Color(0xFF7C3AED), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('多设备数据同步',
                              style: TextStyle(
                                  color: c.foreground,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                          Text('跨设备同步听书进度与收藏',
                              style: TextStyle(
                                  color: c.mutedForeground, fontSize: 11)),
                        ],
                      ),
                    ),
                    _MiniChip(
                      label: '说明',
                      onTap: () =>
                          _snack(context, AppStrings.syncCodeHint),
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(
                      label: '设置',
                      filled: true,
                      onTap: () => context.push('/settings'),
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(
                      label: '导入',
                      color: const Color(0xFF0D9488),
                      onTap: () => context.push('/sources'),
                    ),
                  ],
                ),
              ),
            ),

            // 功能列表（硬阴影卡）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LyBrutalCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.hub_outlined,
                      label: AppStrings.sourceManagerTitle,
                      onTap: () => context.push('/sources'),
                    ),
                    _MenuRow(
                      icon: Icons.settings_outlined,
                      label: AppStrings.settings,
                      trailing:
                          '${appearance.accent.label} · ${appearance.mode.label}',
                      onTap: () => context.push('/settings'),
                    ),
                    _MenuRow(
                      icon: Icons.info_outline,
                      label: AppStrings.about,
                      onTap: () => _showAbout(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                '${AppStrings.appName} · v${AppStrings.appVersion}',
                style: TextStyle(color: c.mutedForeground, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.about),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.libraryHeadline),
            SizedBox(height: 8),
            Text(AppStrings.tagline),
            SizedBox(height: 8),
            Text('${AppStrings.version}: ${AppStrings.appVersion}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.gotIt),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 等级胶囊。
class _LevelPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color fg;

  const _LevelPill({
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: fg, fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
      );
}

/// 2×2 统计卡（聆阅：label + 右上 icon 盒 + 大彩色数值）。
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: LyBrutalCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        color: c.mutedForeground, fontSize: 13),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            // 卡片高度由 childAspectRatio 决定，窄屏下「图标行 + 22px 数值」的
            // 固有高度会超过可用高度（实测溢出 8.4px）。
            // Spacer + 固定字号在空间不足时无处可退，改成 Expanded + FittedBox：
            // 数值仍贴左下角、空间够时保持 22px 原样，空间不够则整体微缩而非溢出
            // （也顺带扛住系统大字号无障碍设置）。
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
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

/// 小操作 chip（说明/设置/导入）。
class _MiniChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color color;

  const _MiniChip({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color = const Color(0xFF7C3AED),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    color: c.foreground,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
            if (trailing != null)
              Text(trailing!,
                  style:
                      TextStyle(color: c.mutedForeground, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: c.mutedForeground),
          ],
        ),
      ),
    );
  }
}
