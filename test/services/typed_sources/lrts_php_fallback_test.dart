import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/lrts_source_adapter.dart';

/// tingshu8 兜底链路测试（2026-10-16 字节码 #18078/#18064 挖掘）。
///
/// 聆阅取音频的顺序是 **php 代理优先、Edge 兜底**；
/// php 代理无鉴权、无 Supabase 并发限流（实测 `?id=` 直出真实 m4a 直链）。
void main() {
  SourceRule source() => SourceRule.fromJson({
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

  Chapter chapter(String token) => Chapter(
        chapterId: token,
        bookId: 'lrts_94326793',
        index: 0,
        name: '第1集',
        url: token,
      );

  late String phpPlayReal;
  setUpAll(() {
    phpPlayReal =
        File('test/fixtures/lrts_php_play_real.json').readAsStringSync();
  });

  group('parsePhpPlayResponse（真实报文）', () {
    final a = LrtsSourceAdapter(dio: Dio());

    test('真实 php 播放响应解析出直链', () {
      final url = a.parsePhpPlayResponse(phpPlayReal);
      expect(url, isNotNull);
      expect(url, startsWith('https://vb.stream.tencentmusic.com/'));
    });

    test('无效形态一律返回 null', () {
      expect(a.parsePhpPlayResponse('{"code":200,"data":{"url":""}}'), isNull);
      expect(a.parsePhpPlayResponse('{"data":{"url":"ftp://x"}}'), isNull);
      expect(a.parsePhpPlayResponse('{"data":[]}'), isNull);
      expect(a.parsePhpPlayResponse('nope'), isNull);
    });
  });

  group('parsePhpSearchResult', () {
    final a = LrtsSourceAdapter(dio: Dio());

    test('真实空列表报文 → 空结果（不抛）', () {
      final body =
          File('test/fixtures/lrts_php_search_real.json').readAsStringSync();
      expect(a.parsePhpSearchResult(source(), body), isEmpty);
    });

    test('合成 list 项 → Book（宽容字段：title/name、narrator/announcer）', () {
      final body = jsonEncode({
        'code': 200,
        'data': {
          'list': [
            {
              'id': 123,
              'title': '书名',
              'author': '作者',
              'announcer': '播音',
              'cover': 'https://c/1.png',
              'chapters': 66,
            },
            {'id': 124, 'name': '备用名'},
            'bad',
          ],
        },
      });
      final books = a.parsePhpSearchResult(source(), body);
      expect(books, hasLength(2));
      expect(books.first.bookId, 'lrts_123');
      expect(books.first.name, '书名');
      expect(books.first.narrator, '播音');
      expect(books.first.chapterCount, 66);
      expect(books.last.name, '备用名');
    });
  });

  group('getAudioUrl：php 优先、Edge 兜底（字节码 #18078 顺序）', () {
    test('php 命中则不再请求 Edge', () async {
      final calls = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          calls.add(o.uri.toString());
          if (o.uri.host == 'www.tingshu8.top') {
            return _resp(phpPlayReal);
          }
          return _resp('{"should":"not-be-called"}');
        });
      final a = LrtsSourceAdapter(dio: dio);

      final url = await a.getAudioUrl(source(), chapter('94326793*1'));
      expect(url, contains('tencentmusic.com'));
      expect(calls.where((u) => u.contains('tingshu8')), hasLength(1));
      expect(calls.any((u) => u.contains('/functions/v1/')), isFalse);
    });

    test('php 无果 → 回落 Edge lrts-play', () async {
      final calls = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          calls.add(o.uri.toString());
          if (o.uri.host == 'www.tingshu8.top') {
            return _resp('{"code":200,"data":{"url":""}}'); // php 空
          }
          return _resp(jsonEncode({
            'code': 200,
            'data': {'url': 'https://edge.example/audio.m4a'},
          }));
        });
      final a = LrtsSourceAdapter(dio: dio);

      final url = await a.getAudioUrl(source(), chapter('94326793*1'));
      expect(url, 'https://edge.example/audio.m4a');
      expect(calls.any((u) => u.contains('/functions/v1/lrts-play')), isTrue);
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
