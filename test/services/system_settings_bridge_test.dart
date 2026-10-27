import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soft_sound/services/system_settings_bridge.dart';

/// 系统设置跳转桥测试（不触达真实系统 UI）。
///
/// 行为契约：非 Android / 原生报错时不抛，返回 false 或 null，
/// 让调用方退化为「只给步骤说明」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemSettingsBridge', () {
    late List<String> called;
    late SystemSettingsBridge bridge;

    setUp(() {
      called = [];
      final channel = const MethodChannel('soft_sound/system_settings');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        called.add(call.method);
        switch (call.method) {
          case 'isIgnoringBatteryOptimizations':
            return true;
          default:
            return true;
        }
      });
      bridge = SystemSettingsBridge(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('soft_sound/system_settings'),
        null,
      );
    });

    test('openAppSettings / openBatteryOptimizationSettings 调用原生并返回 true',
        () async {
      expect(await bridge.openAppSettings(), isTrue);
      expect(await bridge.openBatteryOptimizationSettings(), isTrue);
      expect(called, ['openAppSettings', 'openBatteryOptimizationSettings']);
    });

    test('isIgnoringBatteryOptimizations 透传原生结果', () async {
      expect(await bridge.isIgnoringBatteryOptimizations(), isTrue);
      expect(called, ['isIgnoringBatteryOptimizations']);
    });
  });

  group('原生异常 / 平台不支持时优雅降级', () {
    test('原生抛错 → false（不崩溃）', () async {
      const channel = MethodChannel('soft_sound/system_settings');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });

      final bridge = SystemSettingsBridge(channel: channel);
      expect(await bridge.openAppSettings(), isFalse);
      expect(await bridge.isIgnoringBatteryOptimizations(), isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
