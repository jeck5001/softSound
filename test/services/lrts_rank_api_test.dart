import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/lrts_rank_api.dart';
import 'package:soft_sound/services/kuwo_rank_api.dart';

/// lrts 排行榜契约测试。
///
/// 来源：2026-10-16 字节码 Function #18082 挖掘 + 真实响应固化
/// （`test/fixtures/lrts_rank_75_real.json`，热播榜 rankId=75 rangeType=1）。
void main() {
  late Map<String, dynamic> real;
  setUpAll(() {
    real = jsonDecode(
      File('test/fixtures/lrts_rank_75_real.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  group('页签常量与线上 badgeList 一致（字节码 #18082 双证）', () {
    test('静态 8 项 == 真实响应 badgeList 前 8 项', () {
      final server = real['badgeList'] as List;
      expect(LrtsRankApi.tabs.length, 8);
      for (var i = 0; i < 8; i++) {
        final t = LrtsRankApi.tabs[i];
        final s = server[i] as Map;
        expect(t.rankId, s['rankId'], reason: '第 $i 项 rankId 漂移');
        expect(t.name, s['rankName'], reason: '第 $i 项名称漂移');
        expect(t.rangeType, s['rangeType'], reason: '第 $i 项 rangeType 漂移');
      }
    });

    test('关键页签值（防重构误改）', () {
      expect(LrtsRankApi.tabs.first,
          const LrtsRankTab(rankId: 75, name: '热播榜', rangeType: 1));
      expect(
        LrtsRankApi.tabs.map((t) => t.name),
        ['热播榜', '新书榜', '热搜榜', '好评榜', '收藏榜', '完结榜', '免费榜', '会员榜'],
      );
      // rangeType=3 的两个特殊榜
      expect(LrtsRankApi.tabs.where((t) => t.rangeType == 3).map((t) => t.rankId),
          [738, 14479]);
    });
  });

  group('parseRankBooks（真实报文）', () {
    final api = LrtsRankApi(dio: Dio());

    test('100 本规模、字段完整映射到通用榜行', () {
      expect(real['total'], 100);
      final books = api.parseRankBooks(real);
      expect(books.length, (real['books'] as List).length);
      final first = books.first;
      expect(first.title, contains('盗墓笔记'));
      expect(first.cover, startsWith('https://bookpic.lrts.me/'));
      expect(first.chapterCount, '793');
      expect(first.rank, '1');
    });

    test('playCnt 占位符 `–` 原样透传（真实观测）', () {
      final books = api.parseRankBooks(real);
      expect(books.any((b) => b.playCount == '–'), isTrue);
    });

    test('畸形输入 → 空（不抛）', () {
      expect(api.parseRankBooks({'books': 'x'}), isEmpty);
      expect(api.parseRankBooks({}), isEmpty);
      expect(
        api.parseRankBooks({
          'books': [
            {'id': 1},
            'bad',
          ]
        }),
        hasLength(1),
      );
    });
  });

  group('fetchRankBooks 链路', () {
    test('URL 带 rankId/rangeType 且鉴权头齐全；429 重试一次成功', () async {
      final captured = <RequestOptions>[];
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          captured.add(o);
          calls++;
          if (calls == 1) {
            return _resp('{"code":"projectConcurrencyLimitExceeded"}', 429);
          }
          return _resp(jsonEncode(real));
        });
      final api = LrtsRankApi(dio: dio, retryDelay: Duration.zero);

      final books = await api.fetchRankBooks(LrtsRankApi.tabs.first);
      expect(books, isNotEmpty);
      final uri = captured.last.uri;
      expect(uri.path, endsWith('/lrts-rank'));
      expect(uri.queryParameters['rankId'], '75');
      expect(uri.queryParameters['rangeType'], '1');
      expect(captured.last.headers['apikey'], isNotNull);
      expect(captured.last.headers['Authorization'], startsWith('Bearer '));
    });

    test('网络失败 → 空列表', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) => throw DioException(
              requestOptions: o,
            ));
      final api = LrtsRankApi(dio: dio, retryDelay: Duration.zero);
      expect(await api.fetchRankBooks(LrtsRankApi.tabs.first), isEmpty);
    });
  });

  group('kuwo-classify 真实分类树（2026-10-16 实测）', () {
    test('7 个大类，child 携带 classifyId/categoryId', () async {
      final body =
          File('test/fixtures/kuwo_classify_real.json').readAsStringSync();
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) => _resp(body));
      final api = KuwoRankApi(dio: dio);

      final sections = await api.fetchClassify();
      expect(sections.map((s) => s.name), [
        '有声小说',
        '儿童',
        '相声曲艺',
        '助眠解压',
        '两性情感',
        '音乐娱乐',
        '历史人文',
      ]);
      expect(sections.first.categoryId, '2');
      expect(sections.first.children, isNotEmpty);
      final novel = sections.first.children.first;
      expect(novel.classifyId, isNotEmpty);
      expect(novel.categoryId, '2');
    });

    test('畸形响应 → 空（不抛）', () async {
      final dio = Dio()..httpClientAdapter = _StubAdapter((o) => _resp('<html>'));
      expect(await KuwoRankApi(dio: dio).fetchClassify(), isEmpty);
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
