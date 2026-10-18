import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/xiaoku_source_adapter.dart';
import 'package:soft_sound/theme/playback_settings.dart';

/// 拦截 Dio 请求，捕获酷我实际拼接的 URL，验证音质确实生效。
class _UrlCapturingAdapter implements HttpClientAdapter {
  final List<String> urls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri.toString());
    // 返回空内容，让解析失败但不影响 URL 捕获
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _UrlCapturingAdapter capture;
  late XiaoKuSourceAdapter adapter;

  setUp(() {
    capture = _UrlCapturingAdapter();
    final dio = Dio();
    dio.httpClientAdapter = capture;
    adapter = XiaoKuSourceAdapter(dio: dio);
  });

  SourceRule kuwoSource() => SourceRule.fromJson({
        'sourceId': 'xiaoKu',
        'sourceName': '小酷听书',
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

  Chapter chapter() => Chapter(
        chapterId: 'c1',
        bookId: 'kuwo_1',
        index: 0,
        name: '第一章',
        url: '1028308',
      );

  /// 触发一次取址并返回捕获到的 URL。
  Future<String> urlFor(AudioQuality? quality) async {
    capture.urls.clear();
    await adapter.getAudioUrl(kuwoSource(), chapter(), quality: quality);
    expect(capture.urls, isNotEmpty, reason: '应发起一次取址请求');
    return capture.urls.first;
  }

  group('音质枚举', () {
    test('四档音质均有唯一存储键', () {
      final keys = AudioQuality.values.map((q) => q.storageKey).toSet();
      expect(keys, hasLength(AudioQuality.values.length));
      expect(keys, containsAll(['low', 'standard', 'high', 'lossless']));
    });

    test('默认音质为标准', () {
      expect(const PlaybackSettingsState().quality, AudioQuality.standard);
    });

    test('存储键可往返', () {
      for (final q in AudioQuality.values) {
        expect(AudioQuality.fromStorageKey(q.storageKey), q);
      }
    });

    test('未知键回退标准', () {
      expect(AudioQuality.fromStorageKey('bogus'), AudioQuality.standard);
      expect(AudioQuality.fromStorageKey(null), AudioQuality.standard);
    });
  });

  group('酷我 br 参数随音质变化', () {
    test('low → 128kmp3', () async {
      expect(await urlFor(AudioQuality.low), contains('br=128kmp3'));
    });

    test('standard → 192kmp3', () async {
      expect(await urlFor(AudioQuality.standard), contains('br=192kmp3'));
    });

    test('high → 320kmp3', () async {
      expect(await urlFor(AudioQuality.high), contains('br=320kmp3'));
    });

    test('lossless → 2000kflac', () async {
      expect(await urlFor(AudioQuality.lossless), contains('br=2000kflac'));
    });

    test('未指定音质 → 回退 320kmp3（保持历史行为）', () async {
      expect(await urlFor(null), contains('br=320kmp3'));
    });

    test('四档音质产生四种不同 URL', () async {
      final urls = <String>{};
      for (final q in AudioQuality.values) {
        urls.add(await urlFor(q));
      }
      expect(urls, hasLength(4), reason: '每档音质 URL 应不同');
    });

    test('章节 rid 正确带入 URL', () async {
      final url = await urlFor(AudioQuality.high);
      expect(url, contains('rid=1028308'));
    });
  });

  group('适配器契约', () {
    test('quality 参数可省略（向后兼容）', () {
      expect(
        () => adapter.getAudioUrl(kuwoSource(), chapter()),
        returnsNormally,
      );
    });
  });
}
