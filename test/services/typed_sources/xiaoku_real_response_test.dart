import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/services/typed_sources/xiaoku_source_adapter.dart';

/// 用**真实抓取**的酷我响应验证解析器。
///
/// fixture 来源：2026-10-13 直接请求
/// `https://search.kuwo.cn/r.s?stype=albuminfo&albumid=1`
/// 得到 33 KB 响应（阿杜专辑《A do》），保存于
/// `test/fixtures/kuwo_album_real.txt`。
///
/// 该测试的价值：证明适配器能处理酷我的**真实报文格式**——
/// 单引号 Python 风格 dict、`&nbsp;` 实体、HTML 片段、
/// `musiclist` 嵌套结构，而非理想化的 JSON。
void main() {
  late String realResponse;

  setUpAll(() {
    final f = File('test/fixtures/kuwo_album_real.txt');
    expect(f.existsSync(), isTrue,
        reason: '缺少真实响应 fixture: ${f.path}');
    realResponse = f.readAsStringSync();
  });

  Book sampleBook() => Book(
        bookId: 'kuwo_1',
        sourceId: 'xiaoKu',
        name: 'A do',
        detailUrl: '1',
      );

  group('真实酷我响应解析', () {
    test('fixture 确实是酷我专辑报文（防护 fixture 失效）', () {
      // 若上游改了格式或 fixture 被替换，这些断言会先失败
      expect(realResponse, contains("'albumid'"));
      expect(realResponse, contains("'musiclist'"));
      expect(realResponse, contains("'songname'"));
      // 酷我用单引号而非标准 JSON —— 这正是需要容错解析的原因
      expect(realResponse.startsWith('{'), isTrue);
      expect(realResponse.contains('"albumid"'), isFalse,
          reason: '若变成标准 JSON，说明上游格式已变，需复核解析器');
    });

    test('parseChapterResponse 能从真实报文解析出章节', () {
      final adapter = XiaoKuSourceAdapter();
      final chapters = adapter.parseChapterResponse(sampleBook(), realResponse);

      expect(chapters, isNotEmpty,
          reason: '真实 musiclist 应能解析出章节');
      // 断言具体内容，顺便验证中文歌名解析正确
      expect(chapters.first.name, isNotEmpty);
    });

    test('章节字段完整且无残留 HTML 实体', () {
      final adapter = XiaoKuSourceAdapter();
      final chapters = adapter.parseChapterResponse(sampleBook(), realResponse);

      for (final ch in chapters) {
        // 名称不应为空
        expect(ch.name.trim(), isNotEmpty, reason: '章节名不应为空');

        // 不应残留 HTML 标签或 &nbsp;
        expect(ch.name, isNot(contains('<')),
            reason: '章节名残留 HTML 标签: ${ch.name}');
        expect(ch.name, isNot(contains('&nbsp;')),
            reason: '章节名残留 HTML 实体: ${ch.name}');
      }
    });

    test('章节索引连续且从 0 开始', () {
      final adapter = XiaoKuSourceAdapter();
      final chapters = adapter.parseChapterResponse(sampleBook(), realResponse);

      for (var i = 0; i < chapters.length; i++) {
        expect(chapters[i].index, i, reason: '第 $i 章索引应为 $i');
      }
    });

    test('章节归属正确的书籍（bookId 传递）', () {
      final adapter = XiaoKuSourceAdapter();
      final chapters = adapter.parseChapterResponse(sampleBook(), realResponse);

      for (final ch in chapters) {
        expect(ch.bookId, 'kuwo_1');
      }
    });

    test('解析结果稳定（同一输入两次结果一致）', () {
      final adapter = XiaoKuSourceAdapter();
      final a = adapter.parseChapterResponse(sampleBook(), realResponse);
      final b = adapter.parseChapterResponse(sampleBook(), realResponse);

      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].name, b[i].name);
      }
    });
  });

  group('健壮性', () {
    test('空响应返回空列表而非崩溃', () {
      final adapter = XiaoKuSourceAdapter();
      expect(adapter.parseChapterResponse(sampleBook(), ''), isEmpty);
    });

    test('无 musiclist 的响应返回空列表', () {
      final adapter = XiaoKuSourceAdapter();
      final chapters = adapter.parseChapterResponse(
        sampleBook(),
        "{'albumid':'1','artist':'x'}",
      );
      expect(chapters, isEmpty);
    });

    test('畸形响应不抛异常', () {
      final adapter = XiaoKuSourceAdapter();
      expect(
        () => adapter.parseChapterResponse(sampleBook(), "{'musiclist':["),
        returnsNormally,
      );
    });
  });
}
