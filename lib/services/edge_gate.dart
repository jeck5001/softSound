import 'dart:async';

/// 聆阅 Edge 后端的**串行闸门**。
///
/// 该后端（Supabase 项目 `supabase345057433544081408`）的限流是
/// **项目级并发**配额，不是单 IP、也不是单接口：
///
/// 2026-10-22 实测（同一 anon key，本机 curl）：
/// - 3 并发 × 3 轮 → 9 次里 7 次 `429 projectConcurrencyLimitExceeded`
/// - 2 并发 × 4 轮（正是发现页挂载时的形态：classify + rank-tabs）→ 8 次里 6 次 429
/// - 严格串行、间隔 1.5s × 8 → 3 次 429
/// - 严格串行、间隔 3s × 10 → 4 次 429
///
/// 也就是说：**自家两个请求同时发出去，就会互相把对方打成 429**。
/// 所以浏览类请求一律排队，一次只放一个在飞，请求之间留一点间隔。
///
/// 播放/字幕类请求（[XiaoKuSourceAdapter]、[LrtsSourceAdapter]）**不接入**本闸门：
/// 那些请求在播放链路上，排在浏览请求后面会拖慢起播。
class EdgeGate {
  EdgeGate({this.minGap = const Duration(milliseconds: 300)});

  /// 两个请求之间的最小间隔，给服务端的并发计数一点回落时间。
  final Duration minGap;

  /// 队尾。只用于排队，**永不携带错误**（任务异常在任务自己那侧抛出）。
  Future<void> _tail = Future<void>.value();

  /// 排队执行 [task]，保证同一时刻只有一个任务在飞。
  ///
  /// [task] 的返回值/异常原样透传给调用方；异常不会污染队列。
  ///
  /// 注意：间隔只占**队列**，不占调用方 —— 结果一拿到就返回，
  /// 下一个任务才需要等 [minGap]。否则单个请求会平白多等一个间隔。
  Future<T> run<T>(Future<T> Function() task) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;

    final result = Completer<T>();
    previous.whenComplete(() async {
      try {
        result.complete(await task());
      } catch (e, st) {
        result.completeError(e, st);
      } finally {
        // 间隔在队尾占位，避免下一个请求贴着上一个发出。
        if (minGap > Duration.zero) {
          await Future<void>.delayed(minGap);
        }
        done.complete();
      }
    });

    return result.future;
  }
}

/// 全局闸门（所有 Edge 浏览请求共用同一条队）。
final EdgeGate edgeGate = EdgeGate();

/// 「这次没拿到数据」——区别于「拿到了，但内容确实是空的」。
///
/// UI 必须能分辨这两件事：前者要给「重新加载」，后者才是「暂无内容」。
/// 把失败静默降级成空列表，会让用户以为榜单真的空了。
class EdgeUnavailableException implements Exception {
  const EdgeUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'EdgeUnavailableException: $message';
}
