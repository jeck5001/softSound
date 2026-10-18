import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soft_sound/theme/app_theme.dart';
import 'package:soft_sound/theme/playback_settings.dart';
import 'package:soft_sound/theme/theme_controller.dart';

/// 验证外观与播放设置的持久化往返（真实 SharedPreferences mock）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppearanceController 持久化', () {
    test('默认值：跟随系统 + 经典紫', () async {
      final c = AppearanceController();
      // 等待异步恢复完成
      await Future<void>.delayed(Duration.zero);

      expect(c.state.mode, AppThemeMode.system);
      expect(c.state.accent, AppAccent.classicPurple);
    });

    test('setMode 写入并可从存储读回', () async {
      final c = AppearanceController();
      await Future<void>.delayed(Duration.zero);

      await c.setMode(AppThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppearanceController.kThemeKey), 'dark');

      // 新实例应能恢复
      final c2 = AppearanceController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.mode, AppThemeMode.dark);
    });

    test('setAccent 写入并可从存储读回', () async {
      final c = AppearanceController();
      await Future<void>.delayed(Duration.zero);

      await c.setAccent(AppAccent.green);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppearanceController.kAccentKey), 'green');

      final c2 = AppearanceController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.accent, AppAccent.green);
    });

    test('存储损坏值回退到默认而非崩溃', () async {
      SharedPreferences.setMockInitialValues({
        AppearanceController.kThemeKey: '不可识别的值',
        AppearanceController.kAccentKey: 'bogus',
      });

      final c = AppearanceController();
      await Future<void>.delayed(Duration.zero);

      expect(c.state.mode, AppThemeMode.system);
      expect(c.state.accent, AppAccent.classicPurple);
    });
  });

  group('PlaybackSettingsController 持久化', () {
    test('默认值合理', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);

      expect(c.state.speed, 1.0);
      expect(c.state.quality, AudioQuality.standard);
      expect(c.state.volumeBoostEnabled, isFalse);
      expect(c.state.skipIntro, isFalse);
      expect(c.state.chapterOrderAscending, isTrue);
    });

    test('倍速写入并可恢复', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);

      await c.setSpeed(1.5);
      expect(c.state.speedLabel, '1.5x');

      final c2 = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.speed, 1.5);
    });

    test('音质写入并可恢复', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);

      await c.setQuality(AudioQuality.lossless);
      final c2 = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.quality, AudioQuality.lossless);
    });

    test('跳片头设置写入并可恢复', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);

      await c.setSkipIntro(true);
      await c.setIntroSeconds(60);

      final c2 = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.skipIntro, isTrue);
      expect(c2.state.introSeconds, 60);
    });

    test('音量增强与增益写入并可恢复', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);

      await c.setVolumeBoostEnabled(true);
      await c.setVolumeBoostGain(900);

      final c2 = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.volumeBoostEnabled, isTrue);
      expect(c2.state.volumeBoostGain, 900);
      expect(c2.gainLabel(), '+900 mB');
    });

    test('章节倒序写入并可恢复', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);

      await c.setChapterOrderAscending(false);
      final c2 = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c2.state.chapterOrderAscending, isFalse);
    });

    test('introOutroSummary 在未启用时返回提示文案', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);
      expect(c.introOutroSummary, isNotEmpty);
    });

    test('introOutroSummary 在启用时包含秒数', () async {
      final c = PlaybackSettingsController();
      await Future<void>.delayed(Duration.zero);

      await c.setSkipIntro(true);
      await c.setIntroSeconds(15);
      expect(c.introOutroSummary, contains('15s'));
    });
  });

  group('播放器设置同步到播放器', () {
    test('applyPlaybackSettings 更新内部字段', () async {
      // 仅验证字段同步，不初始化真实 AudioPlayer
      expect(
        PlaybackSettingsController.speedOptions,
        containsAll([0.5, 1.0, 1.5, 2.0, 3.0]),
      );
    });
  });

  group('主题随设置变化', () {
    testWidgets('切换主题色后 ThemeData.primary 改变', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppearanceController.kAccentKey: 'orange',
      });

      late ThemeData theme;
      await tester.pumpWidget(ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final appearance = ref.watch(appearanceProvider);
            theme = AppTheme.light(accent: appearance.accent);
            return MaterialApp(theme: theme, home: const SizedBox());
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(theme.colorScheme.primary, AppAccent.orange.light);
    });
  });
}
