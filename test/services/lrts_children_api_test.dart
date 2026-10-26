import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/lrts_children_api.dart';
import 'package:soft_sound/services/nuxt_payload.dart';

/// 懒人听书频道页契约测试。
///
/// fixture 为 2026-10-26 真实抓取的
/// `https://m.lrts.me/category/book?title=儿童&rootId=6&index=-2`
/// （裁剪为仅含 `window.__NUXT__` 的等价页面，82 KB）。
///
/// 契约来源：聆阅 Hermes 字节码 #18090 `fetchLrtsChildren` /
/// #18091 `mapChildBook` / #18093 页签过滤谓词。
void main() {
  final api = LrtsChildrenApi();

  group('NuxtPayload 解码（真实页面）', () {
    late NuxtPayload payload;

    setUpAll(() {
      final html = File(
        'test/fixtures/lrts_children_real.html',
      ).readAsStringSync();
      payload = NuxtPayload.tryParse(html)!;
    });

    test('window.__NUXT__ 可解（IIFE + 压缩字面量）', () {
      final data = payload.pageData!;
      expect(data['title'], '儿童');
      expect('${data['rootId']}', '6');
      expect(data['finished'], isTrue);
    });

    test('压缩形参被还原（数字/字符串/布尔混合实参）', () {
      final data = payload.pageData!;
      final tabs = data['tabList'] as List;
      // 首项只有 name，无 id
      expect((tabs.first as Map)['name'], '推荐');
      expect((tabs.first as Map).containsKey('id'), isFalse);
      // 次项 id 来自形参（实参表里的字符串 '6'）
      expect('${(tabs[1] as Map)['id']}', '6');
    });

    test('\\u002F 转义解码为 /', () {
      final data = payload.pageData!;
      final first = (data['recommendList'] as List).first as Map;
      expect('${first['cover']}', contains('https://bookpic.lrts.me/'));
      expect('${first['cover']}', isNot(contains(r'\u002F')));
    });

    test('无 __NUXT__ / 畸形输入 → null 而非抛异常', () {
      expect(NuxtPayload.tryParse('<html></html>'), isNull);
      expect(NuxtPayload.tryParse('window.__NUXT__ = ;</script>'), isNull);
    });
  });

  group('parseHtml（真实频道页）', () {
    late LrtsChildrenData data;

    setUpAll(() {
      final html = File(
        'test/fixtures/lrts_children_real.html',
      ).readAsStringSync();
      data = api.parseHtml(html);
    });

    test('标题与 rootId 来自页面自身', () {
      expect(data.title, '儿童');
      expect(data.rootId, '6');
    });

    test('页签过滤规则与字节码 #18093 一致', () {
      // 原始 tabList 16 项：推荐 / 全部 / 14 个子类；
      // 过滤掉「推荐」「全部」以及 id==='6' 的「全部」项后剩 14 项。
      expect(data.tabs, hasLength(14));
      expect(data.tabs.map((t) => t.name), isNot(contains('推荐')));
      expect(data.tabs.map((t) => t.name), isNot(contains('全部')));
      expect(data.tabs.map((t) => t.id), isNot(contains('6')));
      expect(data.tabs.map((t) => t.id), isNot(contains('0')));
      // 首个子类与线上页面一致
      expect(data.tabs.first, const LrtsChannelTab(id: '63', name: '益智故事'));
    });

    test('首栏为「听友推荐」，其后为子类栏目', () {
      expect(data.sections.first.label, '听友推荐');
      expect(data.sections.first.books, hasLength(8));
      expect(data.sections.length, greaterThan(10));
      expect(
        data.sections.map((s) => s.label),
        containsAll(['儿歌童谣', '益智故事', '少儿科普']),
      );
    });

    test('书字段按 mapChildBook 规则映射', () {
      final b = data.sections.first.books.first;
      expect(b.title, '芽芽大事件百科|今天也有大事情');
      expect(b.id, '57372902');
      // author 取 nickName 优先
      expect(b.author, '芽芽故事');
      // cover 走 https
      expect(b.cover, startsWith('https://bookpic.lrts.me/'));
      // rating 恒为聆阅写死的 9.5
      expect(b.rating, 9.5);
      // playCount → 「N.N万播放」
      expect(b.listeners, '22.4万播放');
      expect(b.category, '儿童');
    });

    test('allBooks 去重且覆盖全部栏目', () {
      final ids = data.allBooks.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'allBooks 有重复 id');
      final inSections = <String>{
        for (final s in data.sections)
          for (final b in s.books) b.id,
      };
      expect(ids.toSet(), inSections);
    });

    test('畸形 HTML → empty 不抛', () {
      final empty = api.parseHtml('<html><body>无数据</body></html>');
      expect(empty.isEmpty, isTrue);
      expect(empty.sections, isEmpty);
      expect(empty.tabs, isEmpty);
    });

    test('无 subTypeRecommendList 时仍保留推荐栏', () {
      final html = File(
        'test/fixtures/lrts_children_real.html',
      ).readAsStringSync();
      // 用真实页面但把子栏目字段名改掉，模拟上游字段漂移
      final mutated = html.replaceAll('subTypeRecommendList', 'subTypeRenamed');
      final d = api.parseHtml(mutated);
      expect(d.sections, hasLength(1));
      expect(d.sections.single.label, '听友推荐');
      expect(d.allBooks, hasLength(8));
    });
  });

  group('categoryUrl', () {
    test('标题 URL 编码、rootId 与 index 参数与字节码一致', () {
      expect(
        LrtsChildrenApi.categoryUrl(title: '儿童', rootId: '6'),
        'https://m.lrts.me/category/book?title=%E5%84%BF%E7%AB%A5&rootId=6&index=-2',
      );
      expect(
        LrtsChildrenApi.categoryUrl(title: '有声小说', rootId: '1'),
        'https://m.lrts.me/category/book?title=%E6%9C%89%E5%A3%B0%E5%B0%8F%E8%AF%B4&rootId=1&index=-2',
      );
    });

    test('UA 为聆阅字节码内联的 iPhone UA', () {
      expect(LrtsChildrenApi.userAgent, contains('iPhone'));
      expect(LrtsChildrenApi.userAgent, contains('Safari/604.1'));
    });
  });
}
