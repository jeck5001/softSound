import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/xiaoku_source_adapter.dart';

/// 酷我字幕链路测试。
///
/// 契约来源：聆阅字节码 #18025/#18026 `fetchKuwoLyric(rid, host)` ——
/// Edge `kuwo-play?rid=&host=` 响应 `{url, lyric, quality}`。
/// fixture `kuwo_play_real.json` 为 2026-10-16 真实响应
/// （音频 URL 已脱敏，字幕保留前 12 行）。
void main() {
  SourceRule source() => SourceRule.fromJson({
        'sourceId': 'xiaoKu',
        'sourceName': '酷我',
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

  Chapter chapterWith(String rid) => Chapter(
        chapterId: rid,
        bookId: 'xiaoKu_1',
        index: 0,
        name: '测试章节',
        url: rid,
      );

  group('parseLyricResponse（真实报文）', () {
    late String realBody;
    setUpAll(() {
      realBody = File('test/fixtures/kuwo_play_real.json').readAsStringSync();
    });

    test('真实 kuwo-play 响应可解析出 LRC', () {
      final a = XiaoKuSourceAdapter(dio: Dio());
      final lyric = a.parseLyricResponse(realBody);
      expect(lyric, isNotNull);
      expect(lyric, startsWith('[00:00.00]'));
      expect(lyric, contains('他一定很爱你'));
    });

    test('lyric 非字符串 → null（字节码 typeof===string 语义）', () {
      final a = XiaoKuSourceAdapter(dio: Dio());
      expect(a.parseLyricResponse('{"lyric":123}'), isNull);
      expect(a.parseLyricResponse('{"url":"http://a"}'), isNull);
      expect(a.parseLyricResponse('{"lyric":"   "}'), isNull);
      expect(a.parseLyricResponse('not json'), isNull);
    });
  });

  group('getLyric（Edge 链路与 429 重试）', () {
    test('命中 kuwo-play 且 URL 带 rid/host 参数与鉴权头', () async {
      final captured = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          captured.add(o);
          return _resp(File('test/fixtures/kuwo_play_real.json')
              .readAsStringSync());
        });
      final a = XiaoKuSourceAdapter(dio: dio)..lyricRetryDelay = Duration.zero;

      final lyric = await a.getLyric(source(), chapterWith('1028308'));
      expect(lyric, contains('[00:'));
      expect(captured, hasLength(1));
      final uri = captured.single.uri;
      expect(uri.path, endsWith('/kuwo-play'));
      expect(uri.queryParameters['rid'], '1028308');
      expect(uri.queryParameters.containsKey('host'), isTrue);
      expect(captured.single.headers['apikey'], isNotNull);
      expect(captured.single.headers['Authorization'],
          startsWith('Bearer '));
    });

    test('429 限流自动重试后成功', () async {
      var calls = 0;
      final ok =
          File('test/fixtures/kuwo_play_real.json').readAsStringSync();
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          calls++;
          if (calls == 1) {
            return _resp('{"code":"projectConcurrencyLimitExceeded"}', 429);
          }
          return _resp(ok);
        });
      final a = XiaoKuSourceAdapter(dio: dio)..lyricRetryDelay = Duration.zero;

      final lyric = await a.getLyric(source(), chapterWith('1'));
      expect(lyric, contains('[00:'));
      expect(calls, 2);
    });

    test('持续 429 → 重试耗尽返回 null', () async {
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          calls++;
          return _resp('{"code":"projectConcurrencyLimitExceeded"}', 429);
        });
      final a = XiaoKuSourceAdapter(dio: dio)..lyricRetryDelay = Duration.zero;

      expect(await a.getLyric(source(), chapterWith('1')), isNull);
      expect(calls, XiaoKuSourceAdapter.lyricRetries + 1);
    });

    test('rid 为空不发请求', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) => throw StateError('不应请求'));
      final a = XiaoKuSourceAdapter(dio: dio);
      expect(await a.getLyric(source(), chapterWith('')), isNull);
    });
  });
}

/// 可编程假 HTTP 适配器。
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
