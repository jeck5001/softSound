import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/xiaoku_source_adapter.dart';

/// 酷我章节列表「直连分页全量 + Edge 兜底」测试。
///
/// 回归根因（2026-10-19 用户反馈：夜无疆只有 600 集，聆阅有 900+）：
/// 直连 `r.s?stype=albuminfo` 只请求了单页 `pn=0&rn=600`，
/// 于是所有超过 600 集的书都被**自己**截断（并非上游封顶）。
/// 2026-10-19 实测：`rn` 上限 2000，`pn` 为 0 基页号且页间连续无重叠
/// （完美世界 songnum=3867 → 4 页 1000/1000/1000/867 全部唯一）。
/// edge fixture 为真实响应（完美世界 albumId=93621135，取前 8 集）。
void main() {
  group('章节倒序防护', _reversedGuardTests);

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

  Book book() => Book(
    bookId: 'xiaoKu_93621135',
    sourceId: 'xiaoKu',
    name: '完美世界',
    detailUrl: '93621135',
  );

  final edgeBody = File(
    'test/fixtures/kuwo_episodes_edge_real.json',
  ).readAsStringSync();

  // 直连 albuminfo 形态（单引号 Python dict，与真实报文同构）；
  // musicrid 与 edge 前两集重叠，duration 为精确值。
  final directBody =
      "{'songnum':'8','musiclist':["
      "{'musicrid':'579866300','name':'完美世界 第1集 大荒；朝气蓬勃','duration':'476'},"
      "{'musicrid':'579901688','name':'完美世界 第2集 山宝','duration':'500'}"
      "]}";

  group('parseEdgeEpisodes（真实报文）', () {
    final a = XiaoKuSourceAdapter(dio: Dio());

    test('8 集全解析，url=musicrid 可直接播放', () {
      final chs = a.parseEdgeEpisodes(book(), edgeBody);
      expect(chs, hasLength(8));
      expect(chs.first.url, '579866300');
      expect(chs.first.name, contains('第1集'));
      expect(chs.first.index, 0);
      expect(chs.last.index, 7);
    });

    test('paid → isVip（真实报文均免费）', () {
      final chs = a.parseEdgeEpisodes(book(), edgeBody);
      expect(chs.every((c) => !c.isVip), isTrue);
      final paid = a.parseEdgeEpisodes(
        book(),
        '{"chapters":[{"id":"1","title":"t","duration":600,"paid":true}]}',
      );
      expect(paid.single.isVip, isTrue);
    });

    test('畸形输入 → 空', () {
      expect(a.parseEdgeEpisodes(book(), 'nope'), isEmpty);
      expect(a.parseEdgeEpisodes(book(), '{"chapters":"x"}'), isEmpty);
    });
  });

  group('getChapterList 直连分页（全量，不再被单页截断）', () {
    test('songnum 超过单页 → 按 pn 翻页取全量，index 连续、时长为直连精确值', () async {
      const total = 1250; // 刻意大于旧实现的单页 600
      var edgeHits = 0;
      final pages = <int>[];
      final sizes = <int>[];
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') {
            edgeHits++;
            return _resp(edgeBody);
          }
          final q = o.uri.queryParameters;
          final pn = int.parse(q['pn'] ?? '-1');
          final rn = int.parse(q['rn'] ?? '-1');
          pages.add(pn);
          sizes.add(rn);
          return _resp(_directPage(total: total, pn: pn, rn: rn));
        });
      final a = XiaoKuSourceAdapter(dio: dio);

      final chs = await a.getChapterList(source(), book());

      expect(
        chs,
        hasLength(total),
        reason: '必须翻页取全量；旧实现只发一页 pn=0&rn=600，把大书截断成 600 集',
      );
      expect(pages, equals([0, 1]), reason: 'pn 为 0 基页号，逐页递增到取满 songnum');
      expect(
        sizes.every((rn) => rn > 600),
        isTrue,
        reason: '单页条数必须突破旧的 600（实测上游上限 2000）',
      );
      expect(
        chs.map((c) => c.index).toList(),
        equals(List.generate(total, (i) => i)),
        reason: '跨页 index 必须连续，否则目录区间与批量下载会错位',
      );
      expect(chs.map((c) => c.chapterId).toSet(), hasLength(total));
      expect(
        chs.map((c) => c.url).toSet(),
        hasLength(total),
        reason: '跨页不得重复或漏集',
      );
      expect(chs.first.duration, 401, reason: '时长取直连精确值，不是 Edge 的粗值 600');
      expect(chs.last.name, contains('第1250集'));
      expect(edgeHits, 0, reason: '直连成功就不该再打 Edge（常被限流，且 paid 不可信）');
    });

    // 原名「末页判定：本页不足 rn 即停止翻页」。
    // 这个前提被真实上游证伪：我们请求 rn=1000，酷我每页最多只给 300 条
    // （albumid=66695527：songnum=1237，pn=0/pn=1 都恰好 300 条），
    // 于是"本页不满一页"会在第 0 页就把真分页误判成末页 ——
    // 用户反馈的「夜无疆 只有 300 集」正是这个成因。
    //
    // 本测试真正想守护的是「songnum 虚高时不要无限翻页」。改用
    // **进展判据**（本页去重后无任何新增 → 停止）来表达，既满足该诉求，
    // 又不会破坏真分页。代价是多一次请求。
    test('songnum 虚高时靠"本页无新增"收束，而不是靠"本页不满"误判末页', () async {
      var directHits = 0;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') return _resp(edgeBody);
          directHits++;
          return _resp(directBody); // songnum=8，但本页只有 2 条
        });
      final a = XiaoKuSourceAdapter(dio: dio);

      final chs = await a.getChapterList(source(), book());

      expect(chs, hasLength(2));
      expect(
        directHits,
        2,
        reason: 'songnum=8 与本页 2 条不一致时不能直接收工，'
            '要再请求一页确认"没有新增"才停止（防漏集优先于省一次请求）',
      );
      expect(chs.first.duration, 476);
    });

    test('中途某页失败 → 保留已取到的章节，不整本清空', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') return _resp(edgeBody);
          final pn = int.parse(o.uri.queryParameters['pn'] ?? '0');
          if (pn == 0) return _resp(_directPage(total: 1500, pn: 0, rn: 1000));
          throw DioException(requestOptions: o);
        });
      final a = XiaoKuSourceAdapter(dio: dio);

      final chs = await a.getChapterList(source(), book());

      expect(chs, hasLength(1000), reason: '第二页挂了也要把第一页给用户，剩下一部分目录仍可用');
      expect(chs.first.index, 0);
      expect(chs.last.index, 999);
    });

    test('直连全挂 → 回落 Edge 全量（时长为 Edge 粗值，仍可播）', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') return _resp(edgeBody);
          throw DioException(requestOptions: o);
        });
      final a = XiaoKuSourceAdapter(dio: dio);

      final chs = await a.getChapterList(source(), book());

      expect(chs, hasLength(8));
      expect(chs.first.duration, 600);
    });

    test('直连返回空集 → 回落 Edge，不返回空目录', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          if (o.uri.host == 'backend.appmiaoda.com') return _resp(edgeBody);
          return _resp("{'songnum':'0','musiclist':[]}");
        });
      final a = XiaoKuSourceAdapter(dio: dio);

      final chs = await a.getChapterList(source(), book());

      expect(chs, hasLength(8));
    });
  });

  group('parseChapterTotal', () {
    test('读出 songnum（字符串形态）', () {
      final a = XiaoKuSourceAdapter(dio: Dio());
      expect(a.parseChapterTotal(directBody), 8);
      expect(a.parseChapterTotal("{'songnum':3867}"), 3867);
      expect(a.parseChapterTotal("{'musiclist':[]}"), isNull);
    });
  });
}

/// 构造直连 albuminfo 的一页报文（单引号 Python dict，与真实上游同构）。
///
/// 集号从 1 开始，`musicrid` 与集号一一对应，duration = 400 + 集号。
String _directPage({required int total, required int pn, required int rn}) {
  final start = pn * rn;
  final n = (total - start).clamp(0, rn);
  final items = [
    for (var i = 0; i < n; i++)
      "{'musicrid':'${900000 + start + i + 1}',"
          "'name':'夜无疆 第${start + i + 1}集 剧情',"
          "'duration':'${400 + start + i + 1}'}",
  ].join(',');
  return "{'songnum':'$total','musiclist':[$items]}";
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.onFetch);
  final ResponseBody Function(RequestOptions) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => onFetch(options);

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

/// 章节倒序防护（聆阅 #17865）：Edge 偶发倒序返回时不得「从最后一集开始播」。
void _reversedGuardTests() {
  final adapter = XiaoKuSourceAdapter(dio: Dio());
  Book book() => Book(
    bookId: 'kuwo_1',
    name: 'x',
    author: '',
    coverUrl: '',
    detailUrl: '1',
    sourceId: 'xiaoKu',
  );

  String body(Iterable<int> nums) => jsonEncode({
    'chapters': [
      for (final n in nums)
        {'id': '$n', 'title': '第$n集', 'duration': 600, 'paid': false},
    ],
  });

  test('升序返回保持原样', () {
    final chapters = adapter.parseEdgeEpisodes(
      book(),
      body(List.generate(80, (i) => i + 1)),
    );
    expect(chapters.first.name, '第1集');
    expect(chapters.last.name, '第80集');
  });

  test('明显倒序（≥70%）被翻转并重建索引', () {
    final raw = adapter.parseEdgeEpisodes(
      book(),
      body(List.generate(80, (i) => 80 - i)),
    );
    // 未防护时首章是「第80集」
    expect(raw.first.name, '第80集');

    final fixed = adapter.debugNormalizeOrder(raw);
    expect(fixed.first.name, '第1集');
    expect(fixed.last.name, '第80集');
    expect(fixed.first.index, 0);
    expect(fixed.last.index, 79);
    expect(fixed.first.chapterId, 'kuwo_1_0');
  });
}
