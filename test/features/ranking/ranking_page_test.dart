import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/features/ranking/ranking_page.dart';
import 'package:soft_sound/services/edge_gate.dart';
import 'package:soft_sound/services/kuwo_rank_api.dart';
import 'package:soft_sound/services/lrts_rank_api.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 排行榜页回归测试。
///
/// 用户反馈的是发现页那张卡（见 ranking_entry_test.dart），但同一个根因
/// —— Edge 后端的项目级并发配额（429 projectConcurrencyLimitExceeded）
/// —— 也会让点进去的排行榜页「空着」。这里锁两件事：
/// ① 429 时说人话（「服务正忙」），而不是误导成「网络失败 / 暂无数据」；
/// ② 请求成功但确实没数据时，给的是「这个榜单暂时没有内容」+ 可重试。
void main() {
  Future<void> pump(WidgetTester tester, KuwoRankApi api) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [kuwoRankApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: RankingPage()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  KuwoRankApi apiWith(ResponseBody Function(RequestOptions) onFetch) =>
      KuwoRankApi(
        gate: EdgeGate(minGap: Duration.zero),
        retryDelay: Duration.zero,
        dio: Dio()..httpClientAdapter = _StubAdapter(onFetch),
      );

  testWidgets('一直 429 → 显示「服务正忙」，不是「网络失败」', (tester) async {
    await pump(
      tester,
      apiWith((_) => _resp('{"code":"projectConcurrencyLimitExceeded"}', 429)),
    );
    // 首次 + 1 次重试都失败后才会落到错误态
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text(AppStrings.rankBusy), findsWidgets);
    expect(find.text(AppStrings.loadFailedNetwork), findsNothing,
        reason: '429 不是网络问题，报「网络失败」会把用户引到错误方向');
    expect(find.text(AppStrings.reload), findsWidgets, reason: '必须能重试');
  });

  testWidgets('请求成功但榜为空 → 「这个榜单暂时没有内容」+ 可重试',
      (tester) async {
    await pump(
      tester,
      apiWith((o) {
        if (o.uri.path.endsWith('kuwo-rank-tabs')) {
          return _resp('{"tabs":[{"id":"13","name":"热播榜"}]}');
        }
        return _resp('{"list":[],"total":0}');
      }),
    );
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text(AppStrings.rankEmpty), findsOneWidget);
    expect(find.text(AppStrings.noData), findsNothing,
        reason: '空榜要说清是「这个榜没内容」，不是笼统的「暂无数据」');
    expect(find.text(AppStrings.rankBusy), findsNothing);
  });

  test('源2（懒人榜）拿不到数据 → 抛错，绝不伪装成「这个榜没内容」', () async {
    // 真实观测：lrts-rank 接口能返回 100 本，但 429 时会拿不到。
    // 旧实现把失败静默成空列表，页面于是永远显示「这个榜单暂时没有内容」，
    // 把「请求失败」伪装成「榜单真的空了」。这里直接锁 service 层的语义。
    final api = LrtsRankApi(
      gate: EdgeGate(minGap: Duration.zero),
      retryDelay: Duration.zero,
      dio: Dio()
        ..httpClientAdapter = _StubAdapter(
            (_) => _resp('{"code":"projectConcurrencyLimitExceeded"}', 429)),
    );

    await expectLater(
      api.fetchRankBooks(LrtsRankApi.tabs.first),
      throwsA(isA<EdgeUnavailableException>()),
    );
  });

  testWidgets('正常有数据 → 渲染书名与排名', (tester) async {
    await pump(
      tester,
      apiWith((o) {
        if (o.uri.path.endsWith('kuwo-rank-tabs')) {
          return _resp('{"tabs":[{"id":"13","name":"热播榜"}]}');
        }
        return _resp('{"list":[{"id":"1","title":"鬼吹灯1有声剧",'
            '"rank":"1","playCnt":"391.5万","songNum":297}],"total":48}');
      }),
    );
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('鬼吹灯1有声剧'), findsOneWidget);
    expect(find.text(AppStrings.rankBusy), findsNothing);
    expect(find.text(AppStrings.rankEmpty), findsNothing);
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
