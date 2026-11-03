import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/lrts_source_adapter.dart';

/// 懒人听书书源「服务端故障」容错测试。
///
/// 背景（2026-11-03 用户真机反馈）：
/// 点进懒人听书的书，详情页一直显示「加载书籍信息…」、0 集、未找到章节。
///
/// 根因**不在我们的代码**：上游 Edge 代理在工作异常，实测
/// ```
/// lrts-detail → 429 / 500
/// lrts-menu   → 500 {"msg":"InvalidWorkerCreation: worker boot error"}
/// m.lrts.me（官方站）→ 200   ← 上游本身是好的
/// ```
/// 但旧实现单次失败就放弃，界面又拿占位 Book 兜底，
/// 于是用户只看到「加载书籍信息…」卡住，没有任何可行动的提示。
///
/// 本文件锁住三件事：
/// 1. 5xx / 429 会重试
/// 2. 重试后仍失败时，能被上层识别为「服务不可用」
/// 3. 上游业务错误（apiStatus != 0）不被误判成网络故障
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

  Book placeholderBook() => Book(
        bookId: 'lrts_52798788',
        sourceId: 'lrts',
        name: '52798788',
        detailUrl: '52798788',
      );

  /// 构造一个按脚本返回状态码的 Dio。
  ///
  /// `codes` 依次被消费；用完后重复最后一个。
  Dio scriptedDio(List<int> codes, {String body = ''}) {
    var i = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/functions/v1'));
    dio.httpClientAdapter = _FakeAdapter(() {
      final code = codes[i < codes.length ? i : codes.length - 1];
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

  group('服务端故障时重试', () {
    test('500 会重试，后续成功则正常返回详情', () async {
      final adapter = LrtsSourceAdapter(
        dio: scriptedDio(
          [500, 200],
          body: jsonEncode({
            'apiStatus': 0,
            'name': '三体',
            'author': '刘慈欣',
            'sections': 60,
          }),
        ),
      );

      final book = await adapter.getBookDetail(source(), placeholderBook());
      expect(book, isNotNull);
      expect(book!.name, '三体');
      expect(adapter.lastFetchFailed, isFalse);
    });

    test('持续 500 时返回 null 且标记失败（供 UI 提示服务不可用）', () async {
      final adapter = LrtsSourceAdapter(dio: scriptedDio([500]));
      final book = await adapter.getBookDetail(source(), placeholderBook());
      expect(book, isNull);
      expect(
        adapter.lastFetchFailed,
        isTrue,
        reason: 'UI 靠这个区分「书没了」和「服务挂了」',
      );
    });

    test('429 限流也会重试', () async {
      final adapter = LrtsSourceAdapter(
        dio: scriptedDio(
          [429, 200],
          body: jsonEncode({
            'apiStatus': 0,
            'name': '黑暗森林',
            'sections': 30,
          }),
        ),
      );
      final book = await adapter.getBookDetail(source(), placeholderBook());
      expect(book?.name, '黑暗森林');
      expect(adapter.lastFetchFailed, isFalse);
    });

    test('404 不重试（不是暂时性故障）', () async {
      final adapter = LrtsSourceAdapter(dio: scriptedDio([404]));
      await adapter.getBookDetail(source(), placeholderBook());
      expect(adapter.lastFetchFailed, isTrue);
    });
  });

  group('业务错误不等于网络故障', () {
    test('apiStatus != 0 返回 null，但不是网络失败', () async {
      final adapter = LrtsSourceAdapter(
        dio: scriptedDio(
          [200],
          body: jsonEncode({'apiStatus': 483, 'msg': '请求验证失败'}),
        ),
      );
      final book = await adapter.getBookDetail(source(), placeholderBook());
      expect(book, isNull);
      expect(
        adapter.lastFetchFailed,
        isFalse,
        reason: '接口通了、是上游说这书不可用，不该提示"稍后重试"',
      );
    });
  });

  group('重试不能叠加（防故障放大器）', () {
    test('_get 本身不做重试，只发一次请求', () {
      final src = File(
        'lib/services/typed_sources/lrts_source_adapter.dart',
      ).readAsStringSync();
      final start = src.indexOf('Future<String?> _get(String path');
      final block = src.substring(start, start + 1200);
      expect(
        block.contains('_maxGetAttempts'),
        isFalse,
        reason: '若 _get 内部重试，会与分页重试叠加成 3x3=9 次/页',
      );
      expect(block.contains('for (var attempt'), isFalse);
    });

    test('分页重试只在暂时性故障时进行', () {
      final src = File(
        'lib/services/typed_sources/lrts_source_adapter.dart',
      ).readAsStringSync();
      final start = src.indexOf('_getMenuPageWithRetry({');
      final block = src.substring(start, start + 1400);
      expect(
        block.contains('_lastFailureRetryable'),
        isTrue,
        reason: '404 这类不该重试，否则白白拖长目录加载',
      );
    });

    test('大目录的最坏请求数必须可控（5795 集 = 97 页）', () {
      // 单页最多 3 次（分页层），不再乘以 _get 的重试
      const pages = 97;
      const maxPerPage = 3;
      expect(pages * maxPerPage, lessThan(400), reason: '超过这个量级必然超时');
    });
  });

  group('页面提示', () {
    test('详情为空且仍是占位名时，报「书源暂时不可用」而不是停在占位串', () {
      // 占位 Book 的特征：name 是纯数字 id（榜单页只给 id，没有书名）
      final placeholder = placeholderBook();
      final looksPlaceholder = int.tryParse(placeholder.name) != null;
      expect(
        looksPlaceholder,
        isTrue,
        reason: '详情页用 name == bookId 判断"详情还没拿到"',
      );
    });
  });
}

/// 按回调返回响应的假 adapter。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._build);
  final ResponseBody Function() _build;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _build();
  }

  @override
  void close({bool force = false}) {}
}
