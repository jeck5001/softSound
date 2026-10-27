import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 外观「特效」设置 —— 对齐聆阅 `tingshu_animations_enabled` / `tingshu_tap_fx`。
///
/// 两个键都来自字节码 #16799 的批量读取（逐字），此前本项目把它们做成了
/// **禁用占位行**（灰着、点了没反应）。这里补成真实开关：
///
/// - `tingshu_animations_enabled`：全局动效。关闭后页面转场变成瞬时切换，
///   点击特效也一并停用（动效总开关的合理语义）。
/// - `tingshu_tap_fx`：点击粒子特效。开启后每次点击在落点炸开一小簇粒子。
///
/// 默认值：动效 **开**、点击特效 **关**（与聆阅「默认不打扰」的取向一致）。
@immutable
class EffectsSettings {
  final bool animationsEnabled;
  final bool tapFxEnabled;

  const EffectsSettings({
    this.animationsEnabled = true,
    this.tapFxEnabled = false,
  });

  EffectsSettings copyWith({bool? animationsEnabled, bool? tapFxEnabled}) =>
      EffectsSettings(
        animationsEnabled: animationsEnabled ?? this.animationsEnabled,
        tapFxEnabled: tapFxEnabled ?? this.tapFxEnabled,
      );

  /// 点击特效的实际生效条件：自身开启 **且** 动效总开关开启。
  bool get tapFxActive => animationsEnabled && tapFxEnabled;
}

/// 特效设置控制器（持久化到聆阅同名键）。
class EffectsSettingsController extends StateNotifier<EffectsSettings> {
  /// [initial] 仅供测试注入：给了就不再读盘（避免异步恢复覆盖注入值）。
  EffectsSettingsController({EffectsSettings? initial})
      : super(initial ?? const EffectsSettings()) {
    if (initial == null) _restore();
  }

  /// 存储键（聆阅逐字）。
  static const String kAnimationsKey = 'tingshu_animations_enabled';
  static const String kTapFxKey = 'tingshu_tap_fx';

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = EffectsSettings(
        // 用 get(key) + 类型判断，避免 getBool 遇到脏数据直接抛
        // （SharedPreferences 的 getBool 对错误类型会抛 TypeError）。
        animationsEnabled: _readBool(p, kAnimationsKey) ?? true,
        tapFxEnabled: _readBool(p, kTapFxKey) ?? false,
      );
    } catch (e) {
      debugPrint('恢复特效设置失败: $e');
    }
  }

  static bool? _readBool(SharedPreferences p, String key) {
    final v = p.get(key);
    if (v is bool) return v;
    return null;
  }

  Future<void> setAnimationsEnabled(bool v) async {
    state = state.copyWith(animationsEnabled: v);
    await _put((p) => p.setBool(kAnimationsKey, v));
  }

  Future<void> setTapFxEnabled(bool v) async {
    state = state.copyWith(tapFxEnabled: v);
    await _put((p) => p.setBool(kTapFxKey, v));
  }

  Future<void> _put(Future<void> Function(SharedPreferences) fn) async {
    try {
      await fn(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('保存特效设置失败: $e');
    }
  }
}

/// 特效设置 Provider。
final effectsSettingsProvider =
    StateNotifierProvider<EffectsSettingsController, EffectsSettings>(
  (ref) => EffectsSettingsController(),
);
