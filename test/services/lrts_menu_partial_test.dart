import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/lrts_source_adapter.dart';

/// 「目录加载不全」的真正根因回归测试（2026-11-04 用户三次反馈）。
///
/// 前面几轮都以为是网络/服务端不稳，实测**直连 m.lrts.me 完全可靠**
/// （793 章 / 14 页 / 0 缺失 / 全 200）。所以问题在我们自己的判定：
///
/// ```dart
/// final chapters = parseChapterResponse(book, json);
/// if (chapters.isEmpty) break;      // ← 当成"翻到头"
/// ```
///
/// 但限流/网关错误的报文是这样的（**没有 list 字段**）：
/// ```json
/// {"requestId":"…","code":"projectConcurrencyLimitExceeded","message":"…"}
/// ```
/// `parseChapterResponse` 拿不到 list 就返回空数组 → 旧代码判定"翻到头"
/// → **静默丢掉后半段，并且不标记为不全**。
///
/// 正确区分：
/// - 有 `list` 且为空 → 真的翻到头
/// - 没有 `list` → 异常响应，记为失败页、标记目录不全
void main() {
  final source = SourceRule.fromJson({
    'sourceId': 'lrts',
    'sourceName': '懒人听书',
    'sourceUrl': 'https://m.lrts.me',
    'sourceType': 'typed-audio',
    'search': {
      'url': 'typed://lrts/search',
      'bookList': 'typed',
      'bookName': 'typed',
      'bookUrl': 'typed',
    },
    'detail': {'chapterList': 'typed'},
    'chapter': {'chapterName': 'typed', 'chapterUrl': 'typed'},
    'audio': {'audioUrl': 'typed'},
  });

  final book = Book(
    bookId: 'lrts_29513169',
    sourceId: 'lrts',
    name: '测试书',
    detailUrl: '29513169',
    chapterCount: 120,
  );

  String menuPage(int from, int to, {int sections = 120}) {
    final list = [
      for (var i = from; i <= to; i++)
        {'section': '$i', 'id': 'tok$i', 'name': '第$i集'},
    ];
    return jsonEncode({'apiStatus': 0, 'sections': sections, 'list': list});
  }

  /// 真实限流报文（实测抓取的结构）。
  const rateLimitedBody = '{"requestId":"abc123",'
      '"code":"projectConcurrencyLimitExceeded",'
      '"message":"当前访问人数较多，已达到应用并发请求上限。"}';

  Dio scripted(List<(int, String)> responses) {
    var i = 0;
    final dio = Dio();
    dio.httpClientAdapter = _Adapter(() {
      final (code, body) =
          i < responses.length ? responses[i] : responses[responses.length - 1];
      i++;
      return ResponseBody.fromString(
        body,
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    return dio;
  }

  test('限流报文（无 list）不能被当成"翻到头"而静默截断', () async {
    // 第 1 页正常，第 2 页遇到限流
    final adapter = LrtsSourceAdapter(
      dio: scripted([
        (200, menuPage(1, 60)),
        (429, rateLimitedBody),
      ]),
    );
    final chapters = await adapter.getChapterList(source, book);

    expect(
      adapter.lastFetchWasPartial,
      isTrue,
      reason: '只拿到 60/120 章却报"完整"，就是用户看到的目录不全还没提示',
    );
    expect(chapters.length, lessThan(120));
  });

  test('真正的末页（list 为空数组）算完整，不误报不全', () async {
    final adapter = LrtsSourceAdapter(
      dio: scripted([
        (200, menuPage(1, 60, sections: 70)),
        (200, menuPage(61, 70, sections: 70)),
      ]),
    );
    final chapters = await adapter.getChapterList(source, book);
    expect(chapters.length, 70);
    expect(adapter.lastFetchWasPartial, isFalse);
  });

  test('缺页时按 section 保留绝对序号，补拉不错位', () async {
    // 第 1 页成功，第 2 页限流，第 3 页成功 → 1..60 + 121..150
    final adapter = LrtsSourceAdapter(
      dio: scripted([
        (200, menuPage(1, 60)),
        (429, rateLimitedBody),
        (200, menuPage(121, 180)),
      ]),
    );
    final chapters = await adapter.getChapterList(source, book);
    // 前 60 与后 60 都拿到
    expect(chapters.length, 120);
    // 绝对序号被保留（第一页 1 起）
    expect(chapters.first.sectionIndex, 1);
  });

  test('网关 5xx 报文（无 list）同样记为失败页', () async {
    final adapter = LrtsSourceAdapter(
      dio: scripted([
        (200, menuPage(1, 60)),
        (
          500,
          '{"msg":"InvalidWorkerCreation: worker boot error",'
              '"workerKey":"x:lrts-menu"}'
        ),
      ]),
    );
    await adapter.getChapterList(source, book);
    expect(adapter.lastFetchWasPartial, isTrue);
  });

  test('全页正常时不多打 partial 标记', () async {
    final adapter = LrtsSourceAdapter(
      dio: scripted([
        (200, menuPage(1, 60)),
        (200, menuPage(61, 120)),
      ]),
    );
    final chapters = await adapter.getChapterList(source, book);
    expect(chapters.length, 120);
    expect(adapter.lastFetchWasPartial, isFalse);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this._build);
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
