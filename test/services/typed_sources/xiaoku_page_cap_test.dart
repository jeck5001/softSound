import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/xiaoku_source_adapter.dart';

/// 酷我目录翻页终止条件回归测试。
///
/// 用户截图（2026-11-04）：《夜无疆》详情页显示 **300 集**，
/// 并出现「目录可能不全：已加载 300 集，共 …」（当时占位符还没插值）。
///
/// 实测上游行为（真实请求，走本机代理）：
/// ```
/// albumid=66695527  songnum=1237
/// 请求 rn=1000 → 每页实际只返回 300 条（上游截顶）
/// pn=0 / pn=1 都是 300 条 → 翻页本身完全正常
/// ```
///
/// 旧代码：
/// ```dart
/// if (page.length < chapterPageSize) break;   // 300 < 1000 → 判为末页
/// ```
/// → **第 0 页就停**，永远只有 300 集。
///
/// 正确：总数已知时只能用 `out.length >= total` 收；
/// "本页不满" 只在**没有总数信息**时才可当末页依据。
void main() {
  SourceRule source() => SourceRule.fromJson({
        'sourceId': 'xiaoKu',
        'sourceName': '小酷听书（酷我）',
        'sourceUrl': 'http://search.kuwo.cn',
        'sourceType': 'typed-audio',
        'search': {
          'url': 'typed://xiaoKu/search',
          'bookList': 'typed',
          'bookName': 'typed',
          'bookUrl': 'typed',
        },
        'detail': {'chapterList': 'typed'},
        'chapter': {'chapterName': 'typed', 'chapterUrl': 'typed'},
        'audio': {'audioUrl': 'typed'},
      });

  final book = Book(
    bookId: 'xiaoKu_66695527',
    sourceId: 'xiaoKu',
    name: '夜无疆',
    detailUrl: '66695527',
    chapterCount: 1237,
  );

  /// 生成一页响应：`songnum` 为总集数，`musiclist` 有 `count` 条。
  String pageBody({
    required int songnum,
    required int from,
    required int count,
  }) {
    final list = [
      for (var i = 0; i < count; i++)
        {
          'musicrid': '${from + i}',
          'name': '第${from + i + 1}集',
          'duration': '600',
        },
    ];
    return '{"songnum":"$songnum","musiclist":${jsonEncode(list)}}';
  }

  /// 模拟上游把 rn 截顶到 [serverPageCap] 条/页。
  Dio cappedUpstream({
    required int songnum,
    int serverPageCap = 300,
    void Function(int requests)? onRequest,
  }) {
    var pn = 0;
    final dio = Dio();
    dio.httpClientAdapter = _A(() {
      onRequest?.call(pn);
      final thisPn = pn;
      pn++;
      final remaining = songnum - thisPn * serverPageCap;
      final n = remaining <= 0 ? 0 : (remaining > serverPageCap ? serverPageCap : remaining);
      return ResponseBody.fromString(
        pageBody(
          songnum: songnum,
          from: thisPn * serverPageCap,
          count: n,
        ),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    return dio;
  }

  test('上游把每页截顶到 300 时，必须继续翻页直到拿满 songnum', () async {
    var requests = 0;
    final adapter = XiaoKuSourceAdapter(
      dio: cappedUpstream(songnum: 1237, onRequest: (_) => requests++),
    );

    final chapters = await adapter.getChapterList(source(), book);

    expect(
      chapters.length,
      1237,
      reason: '旧实现在第 0 页就 break，只会得到 300 —— 正是用户看到的',
    );
    expect(requests, 5, reason: 'ceil(1237/300) = 5 页');
  });

  test('绝不能在首页就停止（旧 bug 的直接复现守卫）', () async {
    final adapter = XiaoKuSourceAdapter(
      dio: cappedUpstream(songnum: 1237),
    );
    final chapters = await adapter.getChapterList(source(), book);
    expect(
      chapters.length,
      greaterThan(300),
      reason: '"本页不满一页"不等于末页：请求 rn 会被上游截顶',
    );
  });

  test('章节序号连续且不重复', () async {
    final adapter = XiaoKuSourceAdapter(
      dio: cappedUpstream(songnum: 700),
    );
    final chapters = await adapter.getChapterList(source(), book);
    expect(chapters.length, 700);
    expect(chapters.map((c) => c.index).toList(),
        List.generate(700, (i) => i));
    expect(chapters.map((c) => c.chapterId).toSet().length, 700);
  });

  test('总数未知时仍可用"本页不满"收束（不能死循环）', () {
    final src = File(
      'lib/services/typed_sources/xiaoku_source_adapter.dart',
    ).readAsStringSync();
    // 只看代码：注释里会引用旧写法作为说明（`page.length < chapterPageSize`）
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      code.contains('page.length < expectedPageSize'),
      isTrue,
      reason: '保留无总数场景下的末页判断',
    );
    expect(
      code.contains('page.length < chapterPageSize) break'),
      isFalse,
      reason: '这行就是停在 300 的元凶',
    );
  });
}

class _A implements HttpClientAdapter {
  _A(this._build);
  final ResponseBody Function() _build;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      _build();

  @override
  void close({bool force = false}) {}
}
