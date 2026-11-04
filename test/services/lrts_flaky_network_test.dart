import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/lrts_source_adapter.dart';

/// 网络抖动不能被当成"这书只有这么多集"。
///
/// 用户截图（2026-11-04）：播放页目录「已加载 300 集，共 923 集」。
/// 300 正好是 5 页 × 60 —— 不是随机丢页，而是：
///
/// ```dart
/// bool get _lastFailureRetryable => _lastGetStatus == 429 || _lastGetStatus >= 500;
/// ```
/// socket 异常 / 超时 / DNS 抖动时 `_lastGetStatus` 是 **0**，
/// 于是被判成「不可重试」→ 该页立即记失败 → 连续 4 页就触发熔断。
/// 手机网络下连抖 4 次非常常见，结果**把瞬时故障误判成上游就这么点内容**。
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
    bookId: 'lrts_923test',
    sourceId: 'lrts',
    name: '夜无疆',
    detailUrl: '923test',
    chapterCount: 923,
  );

  String page(int from, int to) => jsonEncode({
        'apiStatus': 0,
        'sections': 923,
        'list': [
          for (var i = from; i <= to; i++)
            {'section': '$i', 'id': 'tok$i', 'name': '第$i集'},
        ],
      });

  /// 前 [failRequests] 次请求全部抛网络异常（超时/断流），之后全部成功。
  ///
  /// 网络异常时 `_lastGetStatus == 0`，旧实现判成"不可重试"，
  /// 于是 1 次失败就记 1 个失败页，连 4 页即熔断。
  Dio outage({
    required int failRequests,
    int failRequestsAfterSuccesses = 0,
  }) {
    var n = 0;
    var served = 0; // 成功返回过的页（按页号顺序发号）
    final dio = Dio();
    dio.httpClientAdapter = _A(() {
      n++;
      final inOutage = n > failRequestsAfterSuccesses &&
          n <= failRequestsAfterSuccesses + failRequests;
      if (inOutage) {
        throw DioException(
          requestOptions: RequestOptions(path: 'x'),
          type: DioExceptionType.connectionTimeout,
          error: 'socket hang up',
        );
      }
      served++;
      final from = (served - 1) * 60 + 1;
      final to = served * 60 > 923 ? 923 : served * 60;
      if (from > 923) {
        return ResponseBody.fromString(
          jsonEncode({'apiStatus': 0, 'sections': 923, 'list': []}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString(
        page(from, to),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });
    return dio;
  }

  // 注：退避与页间隔用构造参数压到 1ms，
  // 否则模拟"持续故障"的用例要真等几十秒。
  LrtsSourceAdapter fast({
    required int failRequests,
    int failRequestsAfterSuccesses = 0,
  }) =>
      LrtsSourceAdapter(
        dio: outage(
          failRequests: failRequests,
          failRequestsAfterSuccesses: failRequestsAfterSuccesses,
        ),
        retryBaseDelay: const Duration(milliseconds: 1),
        interPageDelay: const Duration(milliseconds: 1),
      );

  test('网络抖动期间拿到的页不能丢：故障过后应补齐', () async {
    // 复刻用户截图：整本 923 集需 16 页，先成功 5 页（=300 集），
    // 随后连续一段网络层故障。旧实现（status 0 判为不可重试 + 连 4 页熔断）
    // 会就此停在 300 集，且因为报文"看起来正常"而不报不全。
    final adapter = fast(failRequestsAfterSuccesses: 5, failRequests: 12);
    final chapters = await adapter.getChapterList(source, book);

    expect(
      chapters.length,
      greaterThan(300),
      reason: '网络抖动是暂时的，不能因此判定"目录就这么多集"',
    );
    expect(adapter.lastFetchWasPartial, isFalse,
        reason: '最终拿全了就不该再标不全');
  });

  test('网络异常会重试该页，而不是记一次就放弃', () async {
    // 只让第 1 次请求失败：应当重试并成功拿到第 1 页
    final adapter = fast(failRequests: 1);
    final chapters = await adapter.getChapterList(source, book);
    expect(chapters.length, 923);
  });

  test('网络异常被归类为可重试（status 0 不是 4xx）', () {
    final src = File(
      'lib/services/typed_sources/lrts_source_adapter.dart',
    ).readAsStringSync();
    final m = RegExp(r'_lastFailureRetryable\s*=>([\s\S]{0,220}?);').firstMatch(src);
    expect(m, isNotNull);
    expect(
      m!.group(1)!.contains('_lastGetStatus == 0'),
      isTrue,
      reason: 'socket 异常/超时时 status 为 0，必须算暂时性故障',
    );
  });

  test('熔断阈值不能太低', () {
    final src = File(
      'lib/services/typed_sources/lrts_source_adapter.dart',
    ).readAsStringSync();
    final m =
        RegExp(r'_abortAfterConsecutiveFailures = (\d+)').firstMatch(src);
    expect(m, isNotNull);
    expect(
      int.parse(m!.group(1)!),
      greaterThanOrEqualTo(6),
      reason: '连抖 4 次在手机网络下很常见，阈值太低等于把抖动当定局',
    );
  });

  test('请求必须带显式超时（否则卡死连接会挂住整个目录加载）', () {
    final src = File(
      'lib/services/typed_sources/lrts_source_adapter.dart',
    ).readAsStringSync();
    expect(src.contains('receiveTimeout'), isTrue);
    expect(src.contains('connectTimeout'), isTrue);
  });

  test('翻页之间要有礼貌间隔（零间隔齐发易触发上游连接级限流）', () {
    final src = File(
      'lib/services/typed_sources/lrts_source_adapter.dart',
    ).readAsStringSync();
    expect(src.contains('_interPageDelay'), isTrue);
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
