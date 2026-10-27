import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

/// 系统设置跳转桥（后台保活 / 电池优化）。
///
/// 对应聆阅设置页的「开启后台常驻」引导（`bgKeepAliveStep1/2`），
/// 但聆阅只给文案；这里补上「真的把用户送到系统页面」这一步，
/// 否则用户看完提示还得自己翻菜单。
///
/// 原生实现见 `android/.../MainActivity.kt`（channel `soft_sound/system_settings`）：
/// - `openAppSettings`：本应用的系统详情页（通知/权限都在这）
/// - `openBatteryOptimizationSettings`：电池优化列表页
/// - `isIgnoringBatteryOptimizations`：是否已在白名单
///
/// 非 Android 或调用失败时返回 `false`/`null`，UI 退化为「只给步骤说明」。
class SystemSettingsBridge {
  SystemSettingsBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'soft_sound/system_settings';

  final MethodChannel _channel;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 打开本应用的系统详情页（通知权限、电池等入口都在里面）。
  Future<bool> openAppSettings() => _invoke('openAppSettings');

  /// 打开「电池优化」列表页（让用户把本应用设为不优化）。
  Future<bool> openBatteryOptimizationSettings() =>
      _invoke('openBatteryOptimizationSettings');

  /// 是否已获得通知权限（Android 13+ 为运行时权限）。
  ///
  /// 没有通知权限 → 媒体通知不显示 → 小米 HyperOS 的灵动岛/焦点通知也不出现。
  /// 非 Android 视为 true（不适用）。
  Future<bool> hasNotificationPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// 申请通知权限。
  ///
  /// 返回 `true` 表示已是授权状态；`false` 表示刚弹出系统对话框
  /// （用户选择后系统会记住，下次调用即可拿到真实状态）。
  Future<bool> requestNotificationPermission() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 首次播放前调用：没授权就弹一次系统对话框。
  Future<void> ensureNotificationPermission() async {
    if (await hasNotificationPermission()) return;
    await requestNotificationPermission();
  }

  /// 当前是否已被系统豁免电池优化。
  ///
  /// `null` 表示无法判断（非 Android / 调用失败），UI 应给中性文案。
  Future<bool?> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    } catch (_) {
      return null;
    }
  }

  Future<bool> _invoke(String method) async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(method);
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}


/// 通知权限状态（设置页用来提示「通知栏播放控制」是否可用）。
final notificationPermissionProvider = FutureProvider<bool>(
  (ref) => SystemSettingsBridge().hasNotificationPermission(),
);
