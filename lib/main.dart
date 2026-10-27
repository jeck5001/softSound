import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/routes.dart';
import 'theme/app_strings.dart';
import 'theme/app_theme.dart';
import 'theme/effects_settings.dart';
import 'theme/tap_fx_layer.dart';
import 'theme/theme_controller.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 媒体会话 + 通知栏/锁屏/灵动岛控制。
  //
  // 之前**完全没有初始化** `just_audio_background`，所以：
  // - 下拉通知栏没有媒体卡片（没有 MediaSession，系统无从显示）；
  // - 锁屏没有播放控制；
  // - 小米 HyperOS 的「灵动岛 / 焦点通知」也不会出现
  //   （它读的就是持续型媒体通知 + MediaSession 元数据）。
  //
  // `androidNotificationOngoing: true` 让通知保持"进行中"，
  // 这是灵动岛/常驻媒体卡的前提。
  // 注意：audio_service 断言 `!androidNotificationOngoing || androidStopForegroundOnPause`，
  // 所以 `androidStopForegroundOnPause` 必须保持默认 true（暂停时退出前台，
  // 但通知仍然留着，只是不再"进行中"）。
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.softSound.soft_sound.channel.audio',
    androidNotificationChannelName: '轻听 · 播放控制',
    androidNotificationChannelDescription: '显示当前章节并提供播放/暂停/上下章控制',
    androidNotificationOngoing: true,
  );

  HttpOverrides.global = MyHttpOverrides();
  runApp(
    const ProviderScope(
      child: SoftSoundApp(),
    ),
  );
}

class SoftSoundApp extends ConsumerWidget {
  const SoftSoundApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appearance = ref.watch(appearanceProvider);
    final animations = ref.watch(
      effectsSettingsProvider.select((s) => s.animationsEnabled),
    );

    // 全局动效关闭时：页面转场改为瞬时切换（聆阅 `tingshu_animations_enabled`）。
    ThemeData withTransitions(ThemeData base) => animations
        ? base
        : base.copyWith(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _InstantPageTransitionsBuilder(),
                TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
                TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
                TargetPlatform.windows: _InstantPageTransitionsBuilder(),
                TargetPlatform.linux: _InstantPageTransitionsBuilder(),
              },
            ),
          );

    return MaterialApp.router(
      title: '${AppStrings.appName} · 有声书',
      debugShowCheckedModeBanner: false,
      theme: withTransitions(AppTheme.light(accent: appearance.accent)),
      darkTheme: withTransitions(AppTheme.dark(accent: appearance.accent)),
      themeMode: appearance.mode.themeMode,
      routerConfig: router,
      themeAnimationDuration:
          animations ? kThemeAnimationDuration : Duration.zero,
      // 点击粒子特效（聆阅 `tingshu_tap_fx`）：用 builder 包住整棵页面树，
      // 内部用 Listener 旁路监听，不抢任何按钮的手势。
      builder: (context, child) =>
          TapFxLayer(child: child ?? const SizedBox.shrink()),
    );
  }
}


/// 「无转场」页面切换 —— 全局动效关闭时使用（对应聆阅 `tingshu_animations_enabled`）。
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
