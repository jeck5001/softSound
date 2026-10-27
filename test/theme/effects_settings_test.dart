import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soft_sound/theme/effects_settings.dart';
import 'package:soft_sound/theme/tap_fx_layer.dart';

/// 特效设置与点击粒子层测试。
///
/// 契约：聆阅 `tingshu_animations_enabled`（动效总开关，默认开）
/// 与 `tingshu_tap_fx`（点击粒子，默认关）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EffectsSettingsController 持久化', () {
    test('默认值：动效开、点击特效关', () async {
      final c = EffectsSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.animationsEnabled, isTrue);
      expect(c.state.tapFxEnabled, isFalse);
      expect(c.state.tapFxActive, isFalse);
    });

    test('写入后可恢复（键名与聆阅逐字一致）', () async {
      final c = EffectsSettingsController();
      await c.setAnimationsEnabled(false);
      await c.setTapFxEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tingshu_animations_enabled'), isFalse);
      expect(prefs.getBool('tingshu_tap_fx'), isTrue);
      expect(EffectsSettingsController.kAnimationsKey,
          'tingshu_animations_enabled');
      expect(EffectsSettingsController.kTapFxKey, 'tingshu_tap_fx');

      final c2 = EffectsSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.animationsEnabled, isFalse);
      expect(c2.state.tapFxEnabled, isTrue);
    });

    test('动效关闭时点击特效不生效（即使自身开着）', () async {
      final c = EffectsSettingsController();
      await c.setTapFxEnabled(true);
      expect(c.state.tapFxActive, isTrue);
      await c.setAnimationsEnabled(false);
      expect(c.state.tapFxEnabled, isTrue);
      expect(c.state.tapFxActive, isFalse, reason: '总开关关闭后应一并停用');
    });

    test('损坏值回落默认', () async {
      SharedPreferences.setMockInitialValues({
        'tingshu_animations_enabled': 'not-a-bool',
        'tingshu_tap_fx': 42,
      });
      final c = EffectsSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.animationsEnabled, isTrue);
      expect(c.state.tapFxEnabled, isFalse);
    });
  });

  group('TapFxLayer', () {
    Widget wrap(Widget child, {bool animations = true, bool tapFx = true}) =>
        ProviderScope(
          overrides: [
            effectsSettingsProvider.overrideWith(
              (ref) => EffectsSettingsController(
                initial: EffectsSettings(
                  animationsEnabled: animations,
                  tapFxEnabled: tapFx,
                ),
              ),
            ),
          ],
          child: MaterialApp(home: Scaffold(body: TapFxLayer(child: child))),
        );

    testWidgets('点击后在落点绘制粒子，动画结束后移除', (tester) async {
      await tester.pumpWidget(wrap(const Text('内容')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.tap(find.text('内容'));
      await tester.pump(const Duration(milliseconds: 80));

      // 粒子层出现
      expect(find.byKey(const ValueKey('tap-fx-particles')), findsOneWidget);

      // 动画走完后粒子层被移除
      await tester.pump(TapFxLayer.burstDuration);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tap-fx-particles')), findsNothing);
    });

    testWidgets('特效关闭时完全不插手点击（无 Listenor 层）', (tester) async {
      await tester.pumpWidget(wrap(const Text('内容'), tapFx: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tap-fx-listener')), findsNothing);
      await tester.tap(find.text('内容'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(const ValueKey('tap-fx-particles')), findsNothing);
    });

    testWidgets('动效总开关关闭时同样不生效', (tester) async {
      await tester.pumpWidget(
        wrap(const Text('内容'), animations: false, tapFx: true),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tap-fx-listener')), findsNothing);
    });

    testWidgets('滑动不算点击：拖动后不炸粒子', (tester) async {
      await tester.pumpWidget(wrap(const Text('内容')));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('内容')));
      await gesture.moveBy(const Offset(0, 80));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byKey(const ValueKey('tap-fx-particles')), findsNothing,
          reason: '拖动不该触发特效');
    });
  });
}
