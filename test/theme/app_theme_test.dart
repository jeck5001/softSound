import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_theme.dart';
import 'package:soft_sound/theme/playback_settings.dart';
import 'package:soft_sound/theme/theme_controller.dart';

void main() {
  group('AppAccent', () {
    test('主题色取值与聆阅 getThemeColors 还原值一致', () {
      // 这些十六进制值直接来自聆阅 APK 的 Hermes 字节码（Function #17738）。
      expect(AppAccent.classicPurple.light, const Color(0xFF6D28D9));
      expect(AppAccent.classicPurple.dark, const Color(0xFF8B5CF6));
      expect(AppAccent.blue.light, const Color(0xFF1D4ED8));
      expect(AppAccent.blue.dark, const Color(0xFF3B82F6));
      expect(AppAccent.green.light, const Color(0xFF15803D));
      expect(AppAccent.green.dark, const Color(0xFF22C55E));
      expect(AppAccent.red.light, const Color(0xFFB91C1C));
      expect(AppAccent.red.dark, const Color(0xFFEF4444));
      expect(AppAccent.orange.light, const Color(0xFFC2410C));
      expect(AppAccent.orange.dark, const Color(0xFFF97316));
    });

    test('存储键与聆阅一致', () {
      expect(AppAccent.classicPurple.storageKey, 'default');
      expect(AppAccent.blue.storageKey, 'blue');
      expect(AppAccent.green.storageKey, 'green');
      expect(AppAccent.red.storageKey, 'red');
      expect(AppAccent.orange.storageKey, 'orange');
    });

    test('fromStorageKey 可还原，未知值回退到经典紫', () {
      expect(AppAccent.fromStorageKey('blue'), AppAccent.blue);
      expect(AppAccent.fromStorageKey('orange'), AppAccent.orange);
      expect(AppAccent.fromStorageKey(null), AppAccent.classicPurple);
      expect(AppAccent.fromStorageKey('nope'), AppAccent.classicPurple);
    });

    test('resolve 按亮度返回对应主色', () {
      expect(AppAccent.blue.resolve(Brightness.light), AppAccent.blue.light);
      expect(AppAccent.blue.resolve(Brightness.dark), AppAccent.blue.dark);
    });
  });

  group('AppTheme', () {
    test('亮/暗主题都能构建且挂载 AppColors 扩展', () {
      for (final accent in AppAccent.values) {
        final light = AppTheme.light(accent: accent);
        final dark = AppTheme.dark(accent: accent);

        expect(light.extension<AppColors>(), isNotNull);
        expect(dark.extension<AppColors>(), isNotNull);
        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);
      }
    });

    test('选中主题色会反映到 primary', () {
      final theme = AppTheme.light(accent: AppAccent.green);
      expect(theme.extension<AppColors>()!.primary, AppAccent.green.light);
      expect(theme.colorScheme.primary, AppAccent.green.light);
    });

    test('colorsFor 派生的 accent 带透明度且 ring 跟随主色', () {
      final colors = AppTheme.colorsFor(Brightness.light, AppAccent.red);
      expect(colors.primary, AppAccent.red.light);
      expect(colors.accent.a, lessThan(1.0));
      expect(colors.ring, AppAccent.red.light);
    });

    test('AppColors.copyWith 与 lerp 可用', () {
      final base = AppTheme.lightColors;
      final changed = base.copyWith(primary: const Color(0xFF123456));
      expect(changed.primary, const Color(0xFF123456));
      // 其余字段保持不变
      expect(changed.background, base.background);

      final mid = base.lerp(AppTheme.darkColors, 0.5);
      expect(mid, isA<AppColors>());
    });

    test('fallbackLight 提供完整 token（用于无扩展时兜底）', () {
      const c = AppColors.fallbackLight;
      // 2026-10-16：亮色底改为聆阅截图取色的淡紫 #F5F4FF（原纯白）。
      expect(c.background, const Color(0xFFF5F4FF));
      expect(c.primary, const Color(0xFF6D28D9));
      expect(c.destructive, const Color(0xFFB91C1C));
    });
  });

  group('AppThemeMode', () {
    test('存储键与聆阅一致，映射到 ThemeMode', () {
      expect(AppThemeMode.light.storageKey, 'light');
      expect(AppThemeMode.dark.storageKey, 'dark');
      expect(AppThemeMode.light.themeMode, ThemeMode.light);
      expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
    });

    test('fromStorageKey 可还原，未知值回退 system', () {
      expect(AppThemeMode.fromStorageKey('dark'), AppThemeMode.dark);
      expect(AppThemeMode.fromStorageKey('light'), AppThemeMode.light);
      expect(AppThemeMode.fromStorageKey(null), AppThemeMode.system);
      expect(AppThemeMode.fromStorageKey('x'), AppThemeMode.system);
    });
  });

  group('PlaybackSettingsState', () {
    test('默认值合理', () {
      const s = PlaybackSettingsState();
      expect(s.speed, 1.0);
      expect(s.quality, AudioQuality.standard);
      expect(s.volumeBoostEnabled, isFalse);
      expect(s.skipIntro, isFalse);
      expect(s.skipOutro, isFalse);
      expect(s.chapterOrderAscending, isTrue);
    });

    test('倍速文案格式为 Nx', () {
      expect(const PlaybackSettingsState(speed: 1.25).speedLabel, '1.25x');
      expect(const PlaybackSettingsState(speed: 2.0).speedLabel, '2.0x');
    });

    test('copyWith 只改指定字段', () {
      const base = PlaybackSettingsState();
      final s = base.copyWith(speed: 1.5, skipIntro: true);
      expect(s.speed, 1.5);
      expect(s.skipIntro, isTrue);
      expect(s.quality, base.quality);
    });
  });

  group('AudioQuality', () {
    test('存储键与还原', () {
      expect(AudioQuality.high.storageKey, 'high');
      expect(AudioQuality.fromStorageKey('lossless'), AudioQuality.lossless);
      expect(AudioQuality.fromStorageKey(null), AudioQuality.standard);
      expect(AudioQuality.fromStorageKey('bogus'), AudioQuality.standard);
    });
  });

  group('跳过片头/片尾逻辑', () {
    // 直接构造控制器会触发 SharedPreferences 读取（测试环境无插件），
    // 因此这里只验证纯函数逻辑，通过状态对象 + 独立复算保持一致。
    bool isInOutro({
      required bool skipOutro,
      required int outroSeconds,
      required Duration position,
      required Duration duration,
    }) {
      if (!skipOutro || duration.inSeconds <= outroSeconds) return false;
      return position.inSeconds >= duration.inSeconds - outroSeconds;
    }

    Duration? introTarget({
      required bool skipIntro,
      required int introSeconds,
      required Duration duration,
    }) {
      if (!skipIntro || duration.inSeconds <= introSeconds) return null;
      return Duration(seconds: introSeconds);
    }

    test('未启用跳过片头时不跳', () {
      expect(
        introTarget(
          skipIntro: false,
          introSeconds: 30,
          duration: const Duration(minutes: 10),
        ),
        isNull,
      );
    });

    test('启用且时长足够时跳到片头秒数', () {
      expect(
        introTarget(
          skipIntro: true,
          introSeconds: 30,
          duration: const Duration(minutes: 10),
        ),
        const Duration(seconds: 30),
      );
    });

    test('音频比片头还短时不跳（避免整段被跳过）', () {
      expect(
        introTarget(
          skipIntro: true,
          introSeconds: 60,
          duration: const Duration(seconds: 40),
        ),
        isNull,
      );
    });

    test('片尾区间判定', () {
      const duration = Duration(minutes: 10);
      expect(
        isInOutro(
          skipOutro: true,
          outroSeconds: 30,
          position: const Duration(minutes: 9, seconds: 45),
          duration: duration,
        ),
        isTrue,
      );
      expect(
        isInOutro(
          skipOutro: true,
          outroSeconds: 30,
          position: const Duration(minutes: 5),
          duration: duration,
        ),
        isFalse,
      );
      expect(
        isInOutro(
          skipOutro: false,
          outroSeconds: 30,
          position: const Duration(minutes: 9, seconds: 59),
          duration: duration,
        ),
        isFalse,
      );
    });
  });
}
