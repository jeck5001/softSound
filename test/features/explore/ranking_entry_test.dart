import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/features/explore/explore_page.dart';
import 'package:soft_sound/services/edge_gate.dart';
import 'package:soft_sound/services/kuwo_rank_api.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 发现页「排行榜」入口卡回归测试。
///
/// 用户反馈（真机截图圈出）：这张卡一直显示「加载榜单…」像卡死。
/// 根因不是网络 —— 卡片是纯静态 StatelessWidget，副标题写死了
/// `AppStrings.loadingRanking`，从不请求任何数据，所以永远停在那行字上。
/// 这里锁两件事：① 有预览时显示真实内容；② 取不到时给可点的兜底文案，
/// 而不是继续假装加载中。
void main() {
  Future<void> pump(WidgetTester tester, List<Override> overrides) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // 分类树会真的连 Edge（经串行闸门，带 300ms 间隔定时器）。
        // 本文件只关心排行榜卡，分类直接给空 —— 也让用例不碰网络。
        kuwoClassifyProvider.overrideWith((ref) async => const []),
        ...overrides,
      ],
      child: const MaterialApp(home: ExplorePage()),
    ));
    await tester.pump();
    // 挂载期间会排一个零时长定时器（Riverpod FutureProvider 调度），
    // 不排干的话测试框架在 teardown 断言 !timersPending 会误报失败。
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('kuwoRankPreviewProvider', () {
    test('串行取页签 + 榜首书名', () async {
      final calls = <String>[];
      final api = KuwoRankApi(
        gate: EdgeGate(minGap: Duration.zero),
        dio: Dio()
          ..httpClientAdapter = _StubAdapter((o) {
            calls.add(o.uri.path.split('/').last);
            if (o.uri.path.endsWith('kuwo-rank-tabs')) {
              return _resp('{"tabs":[{"id":"13","name":"热播榜",'
                  '"tags":[{"id":"27","name":"总榜"}]}]}');
            }
            return _resp('{"list":[{"id":"1","title":"鬼吹灯1有声剧",'
                '"rank":"1"}],"total":48}');
          }),
      );
      final container = ProviderContainer(
        overrides: [kuwoRankApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final p = await container.read(kuwoRankPreviewProvider.future);
      expect(p.tabName, '热播榜');
      expect(p.topTitle, '鬼吹灯1有声剧');
      // 必须串行：并行会触发 Edge 的并发限流（429 projectConcurrencyLimitExceeded）
      expect(calls, ['kuwo-rank-tabs', 'kuwo-rank-data']);
    });

    test('页签为空 → 抛错（由 UI 兜底，不返回空壳）', () async {
      final api = KuwoRankApi(
        gate: EdgeGate(minGap: Duration.zero),
        dio: Dio()
          ..httpClientAdapter = _StubAdapter((_) => _resp('{"tabs":[]}')),
      );
      final container = ProviderContainer(
        overrides: [kuwoRankApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(kuwoRankPreviewProvider.future),
        throwsA(isA<StateError>()),
      );
    });

    test('榜首为空 → 只给页签名，不编造书名', () async {
      final api = KuwoRankApi(
        gate: EdgeGate(minGap: Duration.zero),
        dio: Dio()
          ..httpClientAdapter = _StubAdapter((o) {
            if (o.uri.path.endsWith('kuwo-rank-tabs')) {
              return _resp('{"tabs":[{"id":"13","name":"热播榜"}]}');
            }
            return _resp('{"list":[],"total":0}');
          }),
      );
      final container = ProviderContainer(
        overrides: [kuwoRankApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final p = await container.read(kuwoRankPreviewProvider.future);
      expect(p.tabName, '热播榜');
      expect(p.topTitle, '');
    });
  });

  group('排行榜入口卡渲染', () {
    testWidgets('有预览时显示真实内容，不再挂着「加载榜单…」', (tester) async {
      await pump(tester, [
        kuwoRankPreviewProvider.overrideWith(
          (ref) async => (tabName: '热播榜', topTitle: '鬼吹灯1有声剧'),
        ),
      ]);

      expect(find.text('热播榜 · 鬼吹灯1有声剧'), findsOneWidget);
      expect(find.text(AppStrings.loadingRanking), findsNothing,
          reason: '数据已就绪却仍显示加载中，就是本次的 bug');
    });

    testWidgets('超长榜首书名不撑破布局（单行省略）', (tester) async {
      await pump(tester, [
        kuwoRankPreviewProvider.overrideWith(
          (ref) async => (
            tabName: '热播榜',
            // 真实观测：酷我榜首标题就是这种「书名|演播|题材」拼接
            topTitle: '鬼吹灯1有声剧|景向谁依|郑希|张震|天下霸唱|盗墓鼻祖',
          ),
        ),
      ]);

      final text = tester.widget<Text>(
        find.textContaining('热播榜 · 鬼吹灯1有声剧'),
      );
      expect(text.maxLines, 1, reason: '副标题必须单行');
      expect(text.overflow, TextOverflow.ellipsis, reason: '超出必须省略');
      expect(tester.takeException(), isNull, reason: '不允许溢出报错');
    });

    testWidgets('取不到预览时显示可点兜底，而不是永久加载中', (tester) async {
      await pump(tester, [
        kuwoRankPreviewProvider.overrideWith(
          (ref) async => throw StateError('429'),
        ),
      ]);

      expect(find.text(AppStrings.rankEntryHint), findsOneWidget);
      expect(find.text(AppStrings.loadingRanking), findsNothing);
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
