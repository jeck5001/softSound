import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/remote_config_api.dart';

/// 远程配置契约测试。
///
/// fixture 为 2026-10-26 对
/// `POST {edge}/functions/v1/remote-config` 的真实响应
/// （429 重试 1 次后 200，791 字节）。
///
/// 契约来源：聆阅 Hermes 字节码 #20358（`remote-config` 模块，
/// 含 `DEFAULT_CONFIG` 字面量）与 #20382（`announcementHash`）、
/// #17988/#17989（`resolvePlayHost` / `buildPlayUrl`）。
void main() {
  final api = RemoteConfigApi();
  late Map<String, dynamic> real;

  setUpAll(() {
    real =
        jsonDecode(
              File('test/fixtures/remote_config_real.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  group('parseResponse（真实响应）', () {
    late RemoteConfig cfg;

    setUpAll(() {
      cfg = api.parseResponse(
        File('test/fixtures/remote_config_real.json').readAsStringSync(),
      )!;
    });

    test('code/data 双层结构被正确解包', () {
      expect(real['code'], 0);
      expect(cfg.serverTime, isNotEmpty);
    });

    test('版本段字段齐全', () {
      final v = cfg.version;
      expect(v.versionCode, 1);
      expect(v.versionName, '1.1.7');
      expect(v.updateDescription, contains('排行榜'));
      expect(v.downloadUrl, startsWith('https://'));
      expect(v.hasUpdate, isTrue);
      expect(v.forceUpdate, isTrue);
      expect(v.effectiveDownloadUrl, v.downloadUrl);
    });

    test('公告段字段齐全', () {
      final a = cfg.announcement!;
      expect(a.title, '公告');
      expect(a.content, isNotEmpty);
      expect(a.hasUsableLink, isTrue);
      expect(a.linkText, '去看看');
      expect(a.openExternal, isFalse);
    });

    test('play_api 当前为关闭（故不影响酷我直连播放）', () {
      expect(cfg.playApi.enabled, isFalse);
      expect(cfg.playApi.isActive, isFalse);
      expect(cfg.playApi.buildPlayUrl(type: 'convert', rid: '1028308'), '');
    });

    test('非 0 code → null', () {
      expect(api.parseResponse('{"code":500,"data":{}}'), isNull);
    });

    test('缺 data / 畸形 JSON → null', () {
      expect(api.parseResponse('{"code":0}'), isNull);
      expect(api.parseResponse('not json'), isNull);
      expect(api.parseResponse('[]'), isNull);
    });
  });

  group('版本比较与更新判定（逐段数字，非字符串）', () {
    test('compareVersions 逐段比较', () {
      expect(RemoteConfig.compareVersions('1.1.7', '1.1.7'), 0);
      expect(RemoteConfig.compareVersions('1.1.8', '1.1.7'), greaterThan(0));
      expect(RemoteConfig.compareVersions('1.2', '1.1.9'), greaterThan(0));
      expect(RemoteConfig.compareVersions('1.1.10', '1.1.9'), greaterThan(0));
      expect(RemoteConfig.compareVersions('1.0', '1.0.1'), lessThan(0));
      expect(RemoteConfig.compareVersions('2', '1.99.99'), greaterThan(0));
    });

    test('同版本不提示更新（即便服务端 has_update=true）', () {
      final cfg = api.parseData({
        'version': {
          'version_code': 1,
          'version_name': '1.1.7',
          'has_update': true,
          'force_update': true,
        },
      });
      expect(cfg.shouldPromptUpdate('1.1.7'), isFalse);
    });

    test('服务端版本更高才提示', () {
      final cfg = api.parseData({
        'version': {'version_name': '1.2.0', 'has_update': true},
      });
      expect(cfg.shouldPromptUpdate('1.1.7'), isTrue);
      expect(cfg.shouldPromptUpdate('1.2.0'), isFalse);
    });

    test('has_update=false 时不提示', () {
      final cfg = api.parseData({
        'version': {'version_name': '9.9.9', 'has_update': false},
      });
      expect(cfg.shouldPromptUpdate('1.1.7'), isFalse);
    });
  });

  group('DEFAULT_CONFIG 等价物（字节码字面量）', () {
    test('fallback 各段与字节码默认值一致', () {
      const d = RemoteConfig.fallback;
      expect(d.version.versionCode, 0);
      expect(d.version.versionName, '');
      expect(d.version.hasUpdate, isFalse);
      expect(d.version.forceUpdate, isFalse);
      expect(d.announcement, isNull);
      expect(d.playApi.enabled, isFalse);
      expect(d.playApi.url, '');
    });

    test('缺字段的 data 按默认值填充', () {
      final cfg = api.parseData(const {});
      expect(cfg.version.versionName, '');
      expect(cfg.announcement, isNull);
      expect(cfg.playApi.enabled, isFalse);
    });

    test('空标题+空内容的公告视为无公告', () {
      final cfg = api.parseData({
        'announcement': {'title': '', 'content': '', 'has_link': false},
      });
      expect(cfg.announcement, isNull);
    });

    test('更新说明为空时回落默认文案', () {
      final cfg = api.parseData({
        'version': {'version_name': '1.2.0', 'update_description': '   '},
      });
      expect(cfg.version.effectiveDescription, '修复已知问题，优化使用体验');
    });

    test('主下载地址为空时用备用地址', () {
      final cfg = api.parseData({
        'version': {
          'download_url': '',
          'download_url2': 'https://b.example/x.apk',
        },
      });
      expect(cfg.version.effectiveDownloadUrl, 'https://b.example/x.apk');
    });
  });

  group('announcementHash（字节码 #20382 djb2，逐字等价）', () {
    test('与 JS 实现结果一致（真实公告）', () {
      // node: let h=5381; h=((h<<5)+h+code)>>>0; h.toString(36) → '1kr0eu9'
      expect(
        Announcement.announcementHash(
          title: '公告',
          content: '又给大家开发了，音乐，影视，短剧，还有听书简版的，点击下方去看看按钮下载。',
          linkUrl: 'https://wwayk.lanzoum.com/b00tcsrj3a',
          linkText: '去看看',
        ),
        '1kr0eu9',
      );
    });

    test('字段变化即指纹变化（内容更新会重新提示）', () {
      const base = Announcement(
        title: '公告',
        content: 'A',
        linkUrl: 'https://x',
        linkText: '去看看',
      );
      final changed = Announcement(
        title: base.title,
        content: 'B',
        linkUrl: base.linkUrl,
        linkText: base.linkText,
      );
      expect(base.hash, isNot(changed.hash));
    });

    test('空公告也有稳定指纹（不抛异常）', () {
      expect(const Announcement(title: '', content: '').hash, isNotEmpty);
    });
  });

  group('play_api 代理（字节码 #17988/#17989）', () {
    test('host 取 origin 且去掉 :80', () {
      const a = PlayApiConfig(enabled: true, url: 'http://example.com:80/x/y');
      expect(a.host, 'http://example.com');
      const b = PlayApiConfig(
        enabled: true,
        url: 'https://api.example.com/path',
      );
      expect(b.host, 'https://api.example.com');
    });

    test('buildPlayUrl 与字节码拼接顺序一致', () {
      const c = PlayApiConfig(
        enabled: true,
        url: 'https://api.example.com/kuwo',
      );
      expect(
        c.buildPlayUrl(type: 'convert', rid: '1028308'),
        'https://api.example.com/kuwo.php?type=convert&rid=1028308',
      );
    });

    test('enabled=false 或 url 为空 → 不启用', () {
      expect(
        const PlayApiConfig(enabled: false, url: 'https://x').isActive,
        isFalse,
      );
      expect(const PlayApiConfig(enabled: true, url: '   ').isActive, isFalse);
    });
  });
}
