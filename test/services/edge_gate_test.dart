import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/edge_gate.dart';

/// [EdgeGate] 回归测试。
///
/// 背景（2026-10-22 实测）：聆阅 Edge 后端是**项目级并发配额**，
/// 本机 curl 实测 2 并发 × 4 轮 → 8 次里 6 次
/// `429 projectConcurrencyLimitExceeded`。也就是说 App 自己同时发出的
/// 两个浏览请求（发现页的 `kuwo-classify` + `kuwo-rank-tabs`）
/// 就会互相把对方打挂，然后各自 8 秒重试，用户看到的就是「一直加载不出来」。
///
/// 这里锁三件事：① 真串行；② 任务异常不污染队列；③ 任务结果原样透传。
void main() {
  group('EdgeGate', () {
    test('并发提交的任务严格串行，不会同时在飞', () async {
      final gate = EdgeGate(minGap: Duration.zero);
      var inFlight = 0;
      var maxInFlight = 0;

      Future<int> task(int i) => gate.run(() async {
            inFlight++;
            maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            inFlight--;
            return i;
          });

      final results = await Future.wait([task(1), task(2), task(3)]);

      expect(maxInFlight, 1, reason: '同时最多只能有一个请求在飞');
      expect(results, [1, 2, 3], reason: '结果按提交顺序返回');
    });

    test('请求之间留出 minGap 间隔，但不拖慢调用方', () async {
      final gate = EdgeGate(minGap: const Duration(milliseconds: 80));
      final start = <int>[];
      final sw = Stopwatch()..start();

      // 调用方拿到结果就返回，不等间隔
      await gate.run(() async => start.add(sw.elapsedMilliseconds));
      final afterFirst = sw.elapsedMilliseconds;
      expect(afterFirst, lessThan(60), reason: 'minGap 只占队列，不占调用方');

      // 第二个任务必须等满间隔才被放行
      await gate.run(() async => start.add(sw.elapsedMilliseconds));
      expect(start, hasLength(2));
      expect(start[1] - start[0], greaterThanOrEqualTo(70),
          reason: '两个请求之间必须有间隔，否则并发计数来不及回落');
    });

    test('任务抛错不会污染队列，后续任务照常执行', () async {
      final gate = EdgeGate(minGap: Duration.zero);

      final boom = gate.run<int>(() async => throw StateError('429'));
      await expectLater(boom, throwsA(isA<StateError>()));

      expect(await gate.run(() async => 'after-error'), 'after-error');
    });

    test('返回值/异常原样透传', () async {
      final gate = EdgeGate(minGap: Duration.zero);
      expect(await gate.run(() async => 42), 42);

      await expectLater(
        gate.run<void>(() async => throw ArgumentError('x')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
