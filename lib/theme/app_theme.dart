import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 主题色方案 —— 取值直接来自「聆阅 FM」的 `getThemeColors()` 函数。
///
/// 从 APK 的 Hermes 字节码中还原出的原始定义为：
/// ```js
/// {
///   default: { dark: '#8B5CF6', light: '#6D28D9' },  // 经典紫
///   blue:    { dark: '#3B82F6', light: '#1D4ED8' },
///   green:   { dark: '#22C55E', light: '#15803D' },
///   red:     { dark: '#EF4444', light: '#B91C1C' },
///   orange:  { dark: '#F97316', light: '#C2410C' },
/// }
/// ```
enum AppAccent {
  /// 经典紫（聆阅默认）
  classicPurple('default', '经典紫', Color(0xFF6D28D9), Color(0xFF8B5CF6)),

  blue('blue', '静谧蓝', Color(0xFF1D4ED8), Color(0xFF3B82F6)),

  green('green', '青葱绿', Color(0xFF15803D), Color(0xFF22C55E)),

  red('red', '绯红', Color(0xFFB91C1C), Color(0xFFEF4444)),

  orange('orange', '暖橙', Color(0xFFC2410C), Color(0xFFF97316));

  /// 聆阅内部的存储键值（AsyncStorage `tingshu_accent`）。
  final String storageKey;

  /// 中文显示名。
  final String label;

  /// 亮色模式下的主色。
  final Color light;

  /// 暗色模式下的主色。
  final Color dark;

  const AppAccent(this.storageKey, this.label, this.light, this.dark);

  /// 从存储键还原；未知值回退到默认（经典紫）。
  static AppAccent fromStorageKey(String? key) {
    if (key == null) return AppAccent.classicPurple;
    for (final a in AppAccent.values) {
      if (a.storageKey == key) return a;
    }
    return AppAccent.classicPurple;
  }

  /// 按亮度取主色。
  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// 应用主题构建器。
///
/// 设计语言移植自聆阅：shadcn/ui 语义 token + 亮/暗双模式 + 可切换主题色。
class AppTheme {
  const AppTheme._();

  /// 亮色模式默认语义色（对应 shadcn 的 `:root`）。
  ///
  /// 说明：聆阅把 token 的真值编译进了 NativeWind 的 class 定义，
  /// 字节码中只保留了变量名而没有 `--background: ...` 的赋值文本。
  /// 因此这里的**主色系严格照搬还原值**，中性色按 shadcn 标准亮色主题取值，
  /// 保证与聆阅观感一致的同时可独立演进。
  static const AppColors lightColors = AppColors.fallbackLight;

  /// 暗色模式默认语义色（对应 shadcn 的 `.dark`）。
  static const AppColors darkColors = AppColors(
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFAFAFA),
    card: Color(0xFF171717),
    cardForeground: Color(0xFFFAFAFA),
    popover: Color(0xFF171717),
    popoverForeground: Color(0xFFFAFAFA),
    primary: Color(0xFF8B5CF6),
    primaryForeground: Color(0xFF171717),
    secondary: Color(0xFF262626),
    secondaryForeground: Color(0xFFFAFAFA),
    muted: Color(0xFF262626),
    mutedForeground: Color(0xFFA1A1A1),
    accent: Color(0xFF262626),
    accentForeground: Color(0xFFFAFAFA),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFFAFAFA),
    border: Color(0xFF262626),
    input: Color(0xFF262626),
    ring: Color(0xFF525252),
  );

  /// 标准圆角（shadcn 默认 `--radius: 0.5rem`）。
  static const double radius = 8.0;

  /// 构建亮色主题。
  static ThemeData light({AppAccent accent = AppAccent.classicPurple}) =>
      _build(Brightness.light, accent);

  /// 构建暗色主题。
  static ThemeData dark({AppAccent accent = AppAccent.classicPurple}) =>
      _build(Brightness.dark, accent);

  /// 按 [accent] 派生出该亮度下的完整语义色。
  ///
  /// 主色替换为所选主题色；`accent`（强调底色）取主色的低透明度版本，
  /// 与 shadcn 中 `bg-accent` 用于悬停/选中的用法一致。
  static AppColors colorsFor(Brightness brightness, AppAccent accent) {
    final base = brightness == Brightness.dark ? darkColors : lightColors;
    final primary = accent.resolve(brightness);
    return base.copyWith(
      primary: primary,
      accent: primary.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.10),
      accentForeground: primary,
      ring: primary,
    );
  }

  static ThemeData _build(Brightness brightness, AppAccent accent) {
    final c = colorsFor(brightness, accent);
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.primaryForeground,
      secondary: c.secondary,
      onSecondary: c.secondaryForeground,
      surface: c.background,
      onSurface: c.foreground,
      error: c.destructive,
      onError: c.destructiveForeground,
      outline: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.border,
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.background,
        foregroundColor: c.foreground,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? c.input.withValues(alpha: 0.5) : c.input.withValues(alpha: 0.3),
        hintStyle: TextStyle(color: c.mutedForeground),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius * 3),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius * 3),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius * 3),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius * 3),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius * 3),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.background,
        indicatorColor: c.accent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c.primary : c.mutedForeground,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? c.primary : c.mutedForeground,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.popover,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.popover,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.foreground,
        contentTextStyle: TextStyle(color: c.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.mutedForeground,
        textColor: c.foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? c.primaryForeground : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? c.primary : null),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.muted,
        circularTrackColor: c.muted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.secondary,
        labelStyle: TextStyle(color: c.secondaryForeground, fontSize: 12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius * 2),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.mutedForeground,
        indicatorColor: c.primary,
        dividerColor: Colors.transparent,
      ),
    );
  }
}
