import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/app_updater.dart';

/// 应用自更新测试。
///
/// 背景：用户问「怎么能够在线更新版本」。查证后发现原实现**不能用且危险**：
/// 它走聆阅的 `remote-config`，`download_url` 指向聆阅作者的个人网盘，
/// 版本号是聆阅的 `1.1.7`。
///
/// - 我们的版本 `0.2.x` 永远小于 `1.1.7` → **永远**提示"发现新版本"；
/// - 点下载装上的却是**聆阅** → 把本应用替换掉。
///
/// 所以自更新必须用自己的清单。本文件锁住这套逻辑的关键约束。
void main() {
  group('清单解析', () {
    test('正常清单', () {
      final m = UpdateManifest.tryParse({
        'version_code': 30,
        'version_name': '0.3.0',
        'update_description': '修复若干问题',
        'download_url': 'https://example.com/a.apk',
        'sha256': 'ABC123',
        'force_update': true,
        'min_supported_code': 5,
      });
      expect(m, isNotNull);
      expect(m!.versionCode, 30);
      expect(m.versionName, '0.3.0');
      expect(m.sha256, 'abc123', reason: '统一小写便于比对');
      expect(m.forceUpdate, isTrue);
      expect(m.minSupportedCode, 5);
      expect(m.hasDownload, isTrue);
    });

    test('缺 version_code / version_name 返回 null', () {
      expect(UpdateManifest.tryParse({'version_name': '1.0.0'}), isNull);
      expect(UpdateManifest.tryParse({'version_code': 1}), isNull);
      expect(UpdateManifest.tryParse({'version_code': 1, 'version_name': '  '}),
          isNull);
      expect(UpdateManifest.tryParse('不是对象'), isNull);
      expect(UpdateManifest.tryParse(null), isNull);
    });

    test('非 http 的下载地址视为不可用', () {
      final m = UpdateManifest.tryParse({
        'version_code': 2,
        'version_name': '0.3.0',
        'download_url': 'file:///tmp/a.apk',
      });
      expect(m!.hasDownload, isFalse);
    });
  });

  group('是否需要更新', () {
    AppUpdater u(int current) => AppUpdater(
          manifestUrl: 'https://example.com/manifest.json',
          currentVersionCode: current,
        );

    final m = UpdateManifest.tryParse({
      'version_code': 30,
      'version_name': '0.3.0',
    })!;

    test('清单版本更大 → 需要更新', () {
      expect(u(29).needsUpdate(m), isTrue);
    });

    test('相同版本 → 不需要', () {
      expect(u(30).needsUpdate(m), isFalse);
    });

    test('本地版本更高（开发中）→ 不需要', () {
      expect(u(31).needsUpdate(m), isFalse);
    });
  });

  group('强制更新判定', () {
    test('force_update 为真则强制', () {
      final m = UpdateManifest.tryParse({
        'version_code': 30,
        'version_name': '0.3.0',
        'force_update': true,
      })!;
      expect(
        AppUpdater(manifestUrl: 'https://x/m.json', currentVersionCode: 29)
            .isForced(m),
        isTrue,
      );
    });

    test('低于 min_supported_code 则强制（即使 force_update=false）', () {
      final m = UpdateManifest.tryParse({
        'version_code': 30,
        'version_name': '0.3.0',
        'min_supported_code': 25,
      })!;
      expect(
        AppUpdater(manifestUrl: 'https://x/m.json', currentVersionCode: 20)
            .isForced(m),
        isTrue,
      );
      expect(
        AppUpdater(manifestUrl: 'https://x/m.json', currentVersionCode: 26)
            .isForced(m),
        isFalse,
      );
    });
  });

  group('绝不能回退到聆阅的更新源', () {
    test('未配置时不发请求', () async {
      final u = AppUpdater(manifestUrl: '', currentVersionCode: 29);
      expect(u.isConfigured, isFalse);
      expect(await u.fetchManifest(), isNull);
    });

    test('非 http 也视为未配置', () {
      expect(
        AppUpdater(manifestUrl: 'ftp://x/m.json', currentVersionCode: 1)
            .isConfigured,
        isFalse,
      );
    });

    test('设置页不再引用聆阅的 remote-config 检查更新', () {
      final src = File(
        'lib/features/settings/settings_page.dart',
      ).readAsStringSync();
      final checkStart = src.indexOf('Future<void> _checkUpdate');
      final block = src.substring(checkStart, checkStart + 1200);
      expect(
        block.contains('remoteConfigProvider'),
        isFalse,
        reason: '聆阅的 download_url 会把本应用替换成聆阅',
      );
      expect(block.contains('appUpdaterProvider'), isTrue);
    });
  });

  group('版本号一致性（发版前提）', () {
    test('pubspec version 带 build number', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)',
              multiLine: true)
          .firstMatch(pubspec);
      expect(m, isNotNull, reason: '自更新比较的是 versionCode，必须有 +N');
      expect(m!.group(1), isNotNull);
      expect(int.parse(m.group(2)!), greaterThan(0));
    });

    test('kCurrentVersionCode 与 pubspec 的 +N 一致', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*[0-9.]+\+([0-9]+)', multiLine: true)
          .firstMatch(pubspec);
      final fromPubspec = int.parse(m!.group(1)!);
      final src = File('lib/services/app_updater.dart').readAsStringSync();
      final k = RegExp(r'kCurrentVersionCode = (\d+)').firstMatch(src);
      expect(k, isNotNull);
      expect(
        int.parse(k!.group(1)!),
        fromPubspec,
        reason: '两处不一致会导致「永远有新版本」或「永远检查不到」',
      );
    });
  });
}
