import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 版本号一致性守卫。
///
/// 背景：设置页曾把「聆阅」的版本号 `v1.1.7` 硬编码进本应用（本应用是 0.1.0），
/// 且「检查更新」当时是假功能。此测试把版本号与本 `pubspec.yaml` 锁在一起，
/// 防止再次出现「显示的版本不是自己的版本」。
void main() {
  test('AppStrings.appVersion 与 pubspec.yaml 的 version 一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec.yaml 应有 x.y.z 形式的 version');
    expect(AppStrings.appVersion, m!.group(1));
  });

  test('设置页不再硬编码聆阅版本号', () {
    final src = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    expect(
      src.contains('v1.1.7'),
      isFalse,
      reason: 'v1.1.7 是聆阅的版本号，不应出现在本应用设置页',
    );
    expect(
      src.contains('AppStrings.appVersion'),
      isTrue,
      reason: '设置页应展示本应用版本常量',
    );
  });
}
