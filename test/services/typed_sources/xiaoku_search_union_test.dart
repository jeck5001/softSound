import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/xiaoku_source_adapter.dart';

/// 酷我搜索「Edge 主路 + 直连补充并集」测试。
///
/// 根因回归（2026-10-16 用户反馈"很多书搜不到"）：
/// Edge `kuwo-search`（total=132 可翻页）与直连 `r.s`（固定 30 条）
/// 结果集交集只有一半——只走任一条都会丢书。
/// 两份 fixture 均为真实响应（同关键词「剑来」）。
void main() {
  SourceRule source() => SourceRule.fromJson({
        'sourceId': 'xiaoKu',
        'sourceName': '酷我',
        'sourceUrl': 'http://search.kuwo.cn',
        'sourceType': 'typed-audio',
        'search': {
          'url': 'typed',
          'bookList': 'typed',
          'bookName': 'typed',
          'bookUrl': 'typed',
        },
        'detail': {'chapterList': 'typed'},
        'chapter': {'chapterName': 'typed', 'chapterUrl': 'typed'},
        'audio': {'audioUrl': 'typed'},
      });

  final edgeBody =
      File('test/fixtures/kuwo_search_edge_real.json').readAsStringSync();
  final directBody =
      File('test/fixtures/kuwo_search_direct_real.txt').readAsStringSync();

  group('parseEdgeSearchResponse（真实报文）', () {
    final a = XiaoKuSourceAdapter(dio: Dio());

    test('6 本全解析，字段完整', () {
      final books = a.parseEdgeSearchResponse(source(), edgeBody);
      expect(books, hasLength(6));
      final first = books.first;
      expect(first.bookId, 'xiaoKu_56543838');
      expect(first.name, contains('剑道主宰'));
      expect(first.coverUrl, startsWith('https://img1.kuwo.cn/'));
      expect(first.intro, isNotNull);
    });

    test('chapters 空数组 → chapterCount null（不显示 0 集）', () {
      final books = a.parseEdgeSearchResponse(source(), edgeBody);
      expect(books.first.chapterCount, isNull);
    });

    test('畸形输入 → 空', () {
      expect(a.parseEdgeSearchResponse(source(), 'nope'), isEmpty);
      expect(a.parseEdgeSearchResponse(source(), '{"books":"x"}'), isEmpty);
    });
  });

  group('search() 并集（核心回归）', () {
    test('edge 与 direct 独有的书都在结果里，且无重复', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') {
            return _resp(edgeBody);
          }
          return _resp(directBody);
        });
      final a = XiaoKuSourceAdapter(dio: dio);

      final books = await a.search(source(), '剑来');
      final ids = books.map((b) => b.bookId).toList();

      // 无重复
      expect(ids.toSet().length, ids.length);
      // edge 首位（聆阅同源主路在前）
      expect(books.first.bookId, 'xiaoKu_56543838');
      // direct 独有（真实报文第一条）也在并集里
      expect(ids, contains('xiaoKu_89653338'),
          reason: '直连独有的《剑来广播剧第八季》被丢了');
      expect(books.length, greaterThan(6));
    });

    test('Edge 持续 429 → 仍有直连结果（不整体失败）', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') {
            return _resp(
                '{"code":"projectConcurrencyLimitExceeded"}', 429);
          }
          return _resp(directBody);
        });
      final a = XiaoKuSourceAdapter(dio: dio)..lyricRetryDelay = Duration.zero;

      final books = await a.search(source(), '剑来');
      expect(books, isNotEmpty);
      expect(books.map((b) => b.bookId), contains('xiaoKu_89653338'));
    });

    test('直连挂掉 → 仍有 Edge 结果', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') return _resp(edgeBody);
          throw DioException(requestOptions: o);
        });
      final a = XiaoKuSourceAdapter(dio: dio);

      final books = await a.search(source(), '剑来');
      expect(books.first.bookId, 'xiaoKu_56543838');
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.onFetch);
  final ResponseBody Function(RequestOptions) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _resp(String body, [int status = 200]) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
