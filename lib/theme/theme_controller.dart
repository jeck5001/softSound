import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// 主题模式 —— 对应聆阅的设置项。
///
/// 聆阅只提供「亮色模式 / 暗夜模式」两个显式选项，
/// 这里额外保留 [system] 以兼容原有行为（默认值仍为跟随系统）。
enum AppThemeMode {
  system('system', '跟随系统', ThemeMode.system),
  light('light', '亮色模式', ThemeMode.light),
  dark('dark', '暗夜模式', ThemeMode.dark);

  final String storageKey;
  final String label;
  final ThemeMode themeMode;

  const AppThemeMode(this.storageKey, this.label, this.themeMode);

  static AppThemeMode fromStorageKey(String? key) {
    if (key == null) return AppThemeMode.system;
    for (final m in AppThemeMode.values) {
      if (m.storageKey == key) return m;
    }
    return AppThemeMode.system;
  }
}

/// 外观设置状态。
@immutable
class AppearanceState {
  final AppThemeMode mode;
  final AppAccent accent;

  const AppearanceState({
    this.mode = AppThemeMode.system,
    this.accent = AppAccent.classicPurple,
  });

  AppearanceState copyWith({AppThemeMode? mode, AppAccent? accent}) =>
      AppearanceState(
        mode: mode ?? this.mode,
        accent: accent ?? this.accent,
      );
}

/// 外观设置控制器。
///
/// 存储键与聆阅保持一致（`tingshu_theme` / `tingshu_accent`），
/// 便于后续与聆阅数据互通。
class AppearanceController extends StateNotifier<AppearanceState> {
  AppearanceController() : super(const AppearanceState()) {
    _restore();
  }

  /// 存储键：主题模式。
  static const String kThemeKey = 'tingshu_theme';

  /// 存储键：主题色。
  static const String kAccentKey = 'tingshu_accent';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppearanceState(
        mode: AppThemeMode.fromStorageKey(prefs.getString(kThemeKey)),
        accent: AppAccent.fromStorageKey(prefs.getString(kAccentKey)),
      );
    } catch (e) {
      // 读取失败时保持默认外观，不阻断启动。
      debugPrint('恢复外观设置失败: $e');
    }
  }

  /// 切换主题模式。
  Future<void> setMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _persist(kThemeKey, mode.storageKey);
  }

  /// 切换主题色。
  Future<void> setAccent(AppAccent accent) async {
    state = state.copyWith(accent: accent);
    await _persist(kAccentKey, accent.storageKey);
  }

  Future<void> _persist(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('保存外观设置失败: $e');
    }
  }
}

/// 外观设置 Provider。
final appearanceProvider =
    StateNotifierProvider<AppearanceController, AppearanceState>(
  (ref) => AppearanceController(),
);

/// 当前主题（亮/暗，由模式决定，已考虑系统亮度）。
final themeDataProvider = Provider<ThemeData>((ref) {
  final appearance = ref.watch(appearanceProvider);
  return AppTheme.light(accent: appearance.accent);
});

/// 暗色主题。
final darkThemeDataProvider = Provider<ThemeData>((ref) {
  final appearance = ref.watch(appearanceProvider);
  return AppTheme.dark(accent: appearance.accent);
});
