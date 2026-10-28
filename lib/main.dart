import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import 'app/routes.dart';
import 'services/lingting_audio_handler.dart';
import 'services/player_service.dart';
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

  // 媒体会话 + 通知栏 / 锁屏 / 蓝牙按键 / 小米灵动岛。
  //
  // 用 `audio_service` 自定义 handler 而不是 `just_audio_background`：
  // 后者控制项写死为「播放/暂停 + 停止」，**没有上一章/下一章**，
  // 导致用户看到「通知栏没有下一章按钮、一章播完不接下一章」。
  //
  // `AudioService.init` 必须 **await**：它要先把前台服务与 MediaSession
  // 建好并把 handler 注册进去。之前给 3 秒超时提前放行，会让首次
  // `setAudioSource` 赶在服务就绪之前而失败（表现为「第一次播不出来」）。
  final audioHandler = await AudioService.init(
    builder: LingtingAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.softSound.soft_sound.channel.audio',
      androidNotificationChannelName: '轻听 · 播放控制',
      androidNotificationChannelDescription: '显示当前章节并提供播放/暂停/上下章控制',
      // 进行中通知是常驻媒体卡 / 灵动岛的前提；
      // audio_service 断言它必须搭配 stopForegroundOnPause=true（默认）。
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  HttpOverrides.global = MyHttpOverrides();
  runApp(
    ProviderScope(
      overrides: [
        // 把 handler 交给播放器（播放器负责注入 AudioPlayer 与切章回调）
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const SoftSoundApp(),
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
