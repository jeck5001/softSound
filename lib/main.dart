import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/routes.dart';
import 'theme/app_strings.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

    return MaterialApp.router(
      title: '${AppStrings.appName} · 有声书',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: appearance.accent),
      darkTheme: AppTheme.dark(accent: appearance.accent),
      themeMode: appearance.mode.themeMode,
      routerConfig: router,
    );
  }
}
