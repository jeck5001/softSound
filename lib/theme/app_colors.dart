import 'package:flutter/material.dart';

/// 语义色 token —— 移植自「聆阅 FM」的 shadcn/ui 设计系统。
///
/// 聆阅使用 NativeWind(Tailwind) 的语义化 token 命名，完整 token 集为：
/// `background` `foreground` `card` `card-foreground` `popover` `popover-foreground`
/// `primary` `primary-foreground` `secondary` `secondary-foreground`
/// `muted` `muted-foreground` `accent` `accent-foreground`
/// `destructive` `border` `input` `ring`
///
/// 这里用 Flutter 的 [ThemeExtension] 承载这些 token，
/// 使 `Theme.of(context).extension<AppColors>()` 可在任意页面取用，
/// 并与 Material 的 [ColorScheme] 并存（不破坏现有 Material 组件）。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// 页面底色
  final Color background;

  /// 主要文字色
  final Color foreground;

  /// 卡片底色
  final Color card;

  /// 卡片内文字色
  final Color cardForeground;

  /// 浮层底色（弹窗、下拉菜单）
  final Color popover;

  /// 浮层文字色
  final Color popoverForeground;

  /// 主色（品牌色，随用户选择变化）
  final Color primary;

  /// 主色之上的文字色
  final Color primaryForeground;

  /// 次级色（次要按钮、弱化标签）
  final Color secondary;

  /// 次级色之上的文字色
  final Color secondaryForeground;

  /// 弱化底色（占位、禁用态）
  final Color muted;

  /// 弱化文字色（辅助说明文字）
  final Color mutedForeground;

  /// 强调底色（悬停、选中行，由主色派生）
  final Color accent;

  /// 强调底色之上的文字色
  final Color accentForeground;

  /// 危险/错误色
  final Color destructive;

  /// 危险色之上的文字色
  final Color destructiveForeground;

  /// 描边色
  final Color border;

  /// 输入框底色
  final Color input;

  /// 聚焦环
  final Color ring;

  const AppColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
  });

  /// 兜底语义色（亮色 · 经典紫）。
  ///
  /// 仅用于主题未挂载 [AppColors] 扩展时的防御性回退，
  /// 正常路径应始终通过 `context.appColors` 取当前主题的颜色。
  static const AppColors fallbackLight = AppColors(
    // 2026-10-16 从聆阅真机截图取色：页面底是淡紫 #F5F4FF（非纯白），
    // 描边带紫调 #E6E1F5 —— 这是聆阅"高级感"的底色层。
    background: Color(0xFFF5F4FF),
    foreground: Color(0xFF0A0A0A),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF0A0A0A),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF0A0A0A),
    primary: Color(0xFF6D28D9),
    primaryForeground: Color(0xFFFAFAFA),
    secondary: Color(0xFFEFEFF8),
    secondaryForeground: Color(0xFF171717),
    muted: Color(0xFFEFEDF8),
    mutedForeground: Color(0xFF737373),
    accent: Color(0xFFEFEDF8),
    accentForeground: Color(0xFF171717),
    destructive: Color(0xFFB91C1C),
    destructiveForeground: Color(0xFFFAFAFA),
    border: Color(0xFFE6E1F5),
    input: Color(0xFFE6E1F5),
    ring: Color(0xFFA1A1A1),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? popover,
    Color? popoverForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? border,
    Color? input,
    Color? ring,
  }) {
    return AppColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      popover: popover ?? this.popover,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground:
          destructiveForeground ?? this.destructiveForeground,
      border: border ?? this.border,
      input: input ?? this.input,
      ring: ring ?? this.ring,
    );
  }

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      popover: Color.lerp(popover, other.popover, t)!,
      popoverForeground:
          Color.lerp(popoverForeground, other.popoverForeground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground:
          Color.lerp(primaryForeground, other.primaryForeground, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground:
          Color.lerp(secondaryForeground, other.secondaryForeground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground:
          Color.lerp(accentForeground, other.accentForeground, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveForeground:
          Color.lerp(destructiveForeground, other.destructiveForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
    );
  }
}

/// 便捷扩展：`context.appColors.primary`
///
/// 若当前主题未挂载 [AppColors]（例如某些局部 Theme），
/// 回退到亮色 token，保证调用方永远拿到可用的颜色。
extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.fallbackLight;
}

/// 让 [ThemeData] 也能直接取出 [AppColors]。
extension AppColorsThemeX on ThemeData {
  AppColors get appColors => extension<AppColors>() ?? AppColors.fallbackLight;
}
