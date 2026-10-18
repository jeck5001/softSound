import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soft_sound/services/app_sources.dart';
import 'package:soft_sound/services/lrts_category_api.dart';

/// 聆阅双书源体系测试。
///
/// 数据源：2026-10-16 字节码深挖（SourceSwitchBadge #21193 /
/// ExploreScreen #21184 / SOURCE1_CATEGORIES & SOURCE2_CATEGORIES #21189 /
/// lrts-category 双路 #18053），fixture 为真实响应/真实页面。
void main() {
  group('双源语义（聆阅）', () {
    test('源1=酷我 源2=懒人，badge 文案与字节码一致', () {
      expect(LySource.kuwo.badge, '源1');
      expect(LySource.lrts.badge, '源2');
      expect(LySource.kuwo.bookPrefix, 'xiaoKu');
      expect(LySource.lrts.bookPrefix, 'lrts');
    });

    test('未知值回退源1（LySource.of）', () {
      expect(LySource.of('kuwo'), LySource.kuwo);
      expect(LySource.of('lrts'), LySource.lrts);
      expect(LySource.of(null), LySource.kuwo);
      expect(LySource.of('???'), LySource.kuwo);
    });

    test('持久化键与字节码逐字一致', () {
      expect(kActiveSourceKey, 'tingshu_active_source');
    });
  });

  group('SOURCE1_CATEGORIES（酷我，字节码 #21189）', () {
    test('7 大类 65 子类；与线上 kuwo-classify 结构对齐', () {
      expect(source1Categories.length, 7);
      expect(
          source1Categories.fold<int>(
              0, (a, p) => a + p.children.length),
          65);
      final novel = source1Categories.first;
      expect(novel.name, '有声小说');
      expect(novel.categoryId, '2');
      expect(novel.icon, '📚');
      expect(novel.accent, 0xFFA855F7);
      // 玄幻奇幻 classifyId=1548（字节码字面量）
      final xh = novel.children
          .firstWhere((c) => c.name == '玄幻奇幻');
      expect(xh.classifyId, '1548');
    });
  });

  group('SOURCE2_CATEGORIES（懒人听书，字节码 #21189）', () {
    test('11 大类 82 子类', () {
      expect(source2Categories.length, 11);
      expect(
          source2Categories.fold<int>(
              0, (a, p) => a + p.children.length),
          82);
    });

    test('关键节点值（防手改漂移）', () {
      final novel = source2Categories.first;
      expect(novel.name, '有声小说');
      expect(novel.rootId, 1);
      expect(novel.lrtsId, '1');
      expect(novel.icon, '⚔️');
      expect(novel.accent, 0xFFFF6B00);
      expect(
          novel.children.map((c) => c.name).take(4).toList(),
          ['玄幻奇幻', '现代言情', '穿越架空', '奇人怪谈']);
      final shang = source2Categories
          .firstWhere((p) => p.name == '相声评书');
      expect(shang.icon, '🪕');
      expect(shang.children.first.name, '单田芳');
    });
  });

  group('ActiveSourceController 持久化', () {
    test('切换写入 prefs，重启读取', () async {
      SharedPreferences.setMockInitialValues({});
      final ctl = ActiveSourceController();
      expect(ctl.state, LySource.kuwo);
      await ctl.set(LySource.lrts);
      expect(ctl.state, LySource.lrts);

      // 模拟重启：新控制器从 prefs 恢复
      final ctl2 = ActiveSourceController();
      await Future<void>.delayed(Duration.zero);
      expect(ctl2.state, LySource.lrts);
      ctl.dispose();
      ctl2.dispose();
    });
  });

  group('LrtsCategoryApi（#18053 双路）', () {
    final api = LrtsCategoryApi(dio: Dio());

    test('Edge 真实响应：14 本 + total', () {
      final body =
          File('test/fixtures/lrts_category_63_real.json').readAsStringSync();
      final page = api.parseEdgeResponse(body);
      expect(page.books, hasLength(14));
      expect(page.total, greaterThan(0));
      final first = page.books.first;
      expect(first.title, isNotEmpty);
      expect(first.cover, startsWith('https://bookpic.lrts.me/'));
    });

    test('直连 HTML 真实页面：正则解析出书名/作者/封面', () {
      final html = File('test/fixtures/lrts_category_direct_63_real.html')
          .readAsStringSync();
      final books = api.parseDirectHtml(html);
      expect(books, isNotEmpty);
      expect(books.length, books.map((b) => b.id).toSet().length,
          reason: 'id 应去重');
      final b = books.first;
      expect(b.title, isNotEmpty);
      expect(b.cover, startsWith('https://'));
      expect(b.cover, isNot(startsWith('http://')),
          reason: '字节码要求 http→https 升级');
    });

    test('畸形输入不抛', () {
      expect(api.parseEdgeResponse('nope').books, isEmpty);
      expect(api.parseEdgeResponse('{"books":"x"}').books, isEmpty);
      expect(api.parseDirectHtml('<html></html>'), isEmpty);
    });
  });
}
