import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/audio_effects.dart';

/// 验证音量增强桥的调用协议与降级行为。
///
/// 通过 mock MethodChannel 拦截原生调用，不依赖真实设备。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('soft_sound/audio_effects');

  late List<MethodCall> calls;

  void mockHandler(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(() {
    calls = [];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('通道名与协议', () {
    test('使用约定通道名', () {
      expect(AudioEffects().currentGainMb, 0);
      // 通道名由实现常量决定，这里通过 mock 验证可被拦截
      mockHandler((call) async => true);
      expect(channel.name, 'soft_sound/audio_effects');
    });
  });

  group('enable', () {
    test('支持时调用 enable 并携带 gainMb', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return true;
        return true;
      });

      final fx = AudioEffects();
      final ok = await fx.enable(900);

      expect(ok, isTrue);
      expect(fx.currentGainMb, 900);

      final enableCall = calls.firstWhere((c) => c.method == 'enable');
      expect(enableCall.arguments['gainMb'], 900);
    });

    test('不支持时直接返回 false 且不调用 enable', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return false;
        return true;
      });

      final fx = AudioEffects();
      final ok = await fx.enable(600);

      expect(ok, isFalse);
      expect(calls.any((c) => c.method == 'enable'), isFalse);
      expect(fx.currentGainMb, 0);
    });

    test('原生返回 false 时增益不被记录', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return true;
        return false; // enable 失败
      });

      final fx = AudioEffects();
      expect(await fx.enable(600), isFalse);
      expect(fx.currentGainMb, 0);
    });

    test('平台异常时返回 false 不抛出', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return true;
        throw PlatformException(code: 'ERR', message: '模拟失败');
      });

      final fx = AudioEffects();
      expect(await fx.enable(600), isFalse);
    });
  });

  group('setGain', () {
    test('调用 setGain 并更新当前增益', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return true;
        return true;
      });

      final fx = AudioEffects();
      expect(await fx.setGain(1200), isTrue);
      expect(fx.currentGainMb, 1200);

      final call = calls.firstWhere((c) => c.method == 'setGain');
      expect(call.arguments['gainMb'], 1200);
    });

    test('平台异常时返回 false', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return true;
        throw PlatformException(code: 'ERR');
      });

      final fx = AudioEffects();
      expect(await fx.setGain(600), isFalse);
    });
  });

  group('disable', () {
    test('调用 disable 并清零增益', () async {
      mockHandler((call) async => true);

      final fx = AudioEffects();
      await fx.enable(600);
      expect(fx.currentGainMb, 600);

      await fx.disable();
      expect(fx.currentGainMb, 0);
      expect(calls.any((c) => c.method == 'disable'), isTrue);
    });

    test('不支持时也安全（不抛异常）', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return false;
        return true;
      });

      final fx = AudioEffects();
      await expectLater(fx.disable(), completes);
      expect(fx.currentGainMb, 0);
    });

    test('平台异常时静默处理', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return true;
        throw PlatformException(code: 'ERR');
      });

      final fx = AudioEffects();
      await expectLater(fx.disable(), completes);
    });
  });

  group('isSupported 缓存', () {
    test('只探测一次', () async {
      mockHandler((call) async {
        if (call.method == 'isSupported') return true;
        return true;
      });

      final fx = AudioEffects();
      await fx.isSupported();
      await fx.isSupported();
      await fx.isSupported();

      final probes = calls.where((c) => c.method == 'isSupported').length;
      expect(probes, 1, reason: '应缓存探测结果');
    });
  });

  group('MissingPluginException 降级', () {
    test('无原生实现时 enable 返回 false', () async {
      // 不注册 handler → 触发 MissingPluginException
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      final fx = AudioEffects();
      // 在测试环境 defaultTargetPlatform 为 android 时才会真正调用
      final supported = await fx.isSupported();
      if (supported) {
        expect(await fx.enable(600), isFalse);
      } else {
        expect(await fx.enable(600), isFalse);
      }
    });
  });

  group('AudioDeviceMonitor', () {
    test('初始未监听', () {
      final m = AudioDeviceMonitor();
      expect(m.isListening, isFalse);
    });

    test('stop 在未启动时安全', () async {
      final m = AudioDeviceMonitor();
      await expectLater(m.stop(), completes);
      expect(m.isListening, isFalse);
    });

    test('start 在测试环境不抛异常（无原生实现时降级）', () async {
      final m = AudioDeviceMonitor();
      var called = false;
      await expectLater(
        m.start(onDisconnected: () => called = true),
        completes,
      );
      // 测试环境无真实设备事件，不应触发回调
      expect(called, isFalse);
      await m.stop();
      expect(m.isListening, isFalse);
    });

    test('重复 start 不会累积监听（先 stop 再 start）', () async {
      final m = AudioDeviceMonitor();
      await m.start(onDisconnected: () {});
      await m.start(onDisconnected: () {});
      await m.stop();
      expect(m.isListening, isFalse);
    });
  });
}
