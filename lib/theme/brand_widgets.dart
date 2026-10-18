import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 聆阅「新粗野主义」共享组件（2026-10-16 真机截图取色复刻）。
///
/// 视觉签名：黑色硬偏移阴影（blur 0）、彩色粗描边、圆角方块、
/// 紫色主按钮、淡紫 icon 底。

/// 黑色硬阴影（聆阅卡片签名：offset 4,4 blur 0）。
const List<BoxShadow> lyHardShadow = [
  BoxShadow(color: Color(0xFF1C1917), offset: Offset(4, 4)),
];

/// 轻量硬阴影（小 chip 用）。
const List<BoxShadow> lyHardShadowSm = [
  BoxShadow(color: Color(0xFF1C1917), offset: Offset(3, 3)),
];

/// 封面：紫色粗描边 + 错位衬卡（聆阅详情页/播放页封面同款）。
class LyCover extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final Color borderColor;
  final double radius;
  final bool offsetCard;

  const LyCover({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderColor = const Color(0xFF7C3AED),
    this.radius = 20,
    this.offsetCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Widget cover = ClipRRect(
      borderRadius: BorderRadius.circular(radius - 4),
      child: url.startsWith('http')
          ? CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => _ph(c),
              errorWidget: (_, __, ___) => _ph(c),
            )
          : _ph(c),
    );
    cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 4),
      ),
      child: cover,
    );
    if (!offsetCard) return cover;
    // 错位衬卡：背后一张偏移的同色卡
    return SizedBox(
      width: width + 10,
      height: height + 10,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          Positioned(left: 0, top: 0, child: cover),
        ],
      ),
    );
  }

  Widget _ph(AppColors c) => Container(
        width: width,
        height: height,
        color: c.muted,
        alignment: Alignment.center,
        child: Icon(Icons.headphones_rounded,
            color: c.mutedForeground, size: 30),
      );
}

/// 黑底硬阴影 chip（分类标签：玄幻/言情…）。
class LyDarkChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final Color border;

  const LyDarkChip(
    this.text, {
    super.key,
    this.bg = const Color(0xFF1C1917),
    this.fg = const Color(0xFFFACC15),
    this.border = const Color(0xFF7C3AED),
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 2),
          boxShadow: lyHardShadowSm,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

/// 彩色描边 meta chip（🕐时长 / N集 / 分类）。
class LyMetaChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const LyMetaChip(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 淡紫底圆角 icon 按钮（顶栏返回/收藏/分享等）。
class LyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final Color? borderColor;
  final double size;
  final bool hardShadow;

  const LyIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.bg = const Color(0xFFEDE9FE),
    this.fg = const Color(0xFF1C1917),
    this.borderColor,
    this.size = 46,
    this.hardShadow = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: 2),
            boxShadow: hardShadow ? lyHardShadowSm : null,
          ),
          child: Icon(icon, size: 22, color: fg),
        ),
      );
}

/// 二段分段控件（简介/目录：白容器 + 紫色激活块）。
class LySegment extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const LySegment({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index
                        ? const Color(0xFF7C3AED)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == index
                          ? Colors.white
                          : c.mutedForeground,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 白底硬阴影大卡（聆阅「我的」页签名卡）。
class LyBrutalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;

  const LyBrutalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(radius),
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 2),
          boxShadow: lyHardShadow,
        ),
        child: child,
      ),
    );
  }
}

/// ★评分 chip（米黄底橙字，聆阅同款）。
class LyRatingChip extends StatelessWidget {
  final double rating;

  const LyRatingChip(this.rating, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '★ ${rating.toStringAsFixed(1)}',
          style: const TextStyle(
            color: Color(0xFFB45309),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
