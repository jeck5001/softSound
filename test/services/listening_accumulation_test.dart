import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/player_service.dart';

/// 验证收听时长的累计判定规则。
///
/// 核心：只有**正常前进**才计入；seek 跳转与回退不计入，
/// 避免用户拖动进度条虚增等级（对应聆阅的「真实听书时长统计」）。
void main() {
  group('shouldCountListening 正常前进', () {
    test('1 秒前进计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          const Duration(seconds: 10),
          const Duration(seconds: 11),
        ),
        isTrue,
      );
    });

    test('亚秒前进计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          const Duration(milliseconds: 1000),
          const Duration(milliseconds: 1200),
        ),
        isTrue,
      );
    });

    test('恰好 5 秒计入（边界内）', () {
      expect(
        PlayerNotifier.shouldCountListening(Duration.zero, const Duration(seconds: 5)),
        isTrue,
      );
    });

    test('从 0 开始的小增量计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          Duration.zero,
          const Duration(milliseconds: 250),
        ),
        isTrue,
      );
    });
  });

  group('shouldCountListening 不计入的情形', () {
    test('位置未变（暂停）不计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          const Duration(seconds: 10),
          const Duration(seconds: 10),
        ),
        isFalse,
      );
    });

    test('回退（seek 后退）不计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          const Duration(seconds: 60),
          const Duration(seconds: 30),
        ),
        isFalse,
      );
    });

    test('超过 5 秒的跳跃视为 seek，不计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          const Duration(seconds: 10),
          const Duration(seconds: 300),
        ),
        isFalse,
      );
    });

    test('快进 15 秒不计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          const Duration(seconds: 100),
          const Duration(seconds: 115),
        ),
        isFalse,
      );
    });

    test('刚好超过 5 秒（5.001s）不计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          Duration.zero,
          const Duration(milliseconds: 5001),
        ),
        isFalse,
      );
    });

    test('章内跳转（切章重置后的大增量）不计入', () {
      expect(
        PlayerNotifier.shouldCountListening(
          Duration.zero,
          const Duration(minutes: 5),
        ),
        isFalse,
      );
    });
  });

  group('累计语义', () {
    test('连续正常播放逐步累计（模拟 10 次 1 秒）', () {
      var previous = Duration.zero;
      var total = Duration.zero;

      for (var i = 0; i < 10; i++) {
        final current = previous + const Duration(seconds: 1);
        if (PlayerNotifier.shouldCountListening(previous, current)) {
          total += const Duration(seconds: 1);
        }
        previous = current;
      }

      expect(total, const Duration(seconds: 10));
    });

    test('中间穿插 seek 不会虚增', () {
      var previous = Duration.zero;
      var total = Duration.zero;

      // 正常 3 秒
      for (var i = 0; i < 3; i++) {
        final current = previous + const Duration(seconds: 1);
        if (PlayerNotifier.shouldCountListening(previous, current)) {
          total += const Duration(seconds: 1);
        }
        previous = current;
      }
      // 拖动到 10 分钟处
      const jumped = Duration(minutes: 10);
      if (PlayerNotifier.shouldCountListening(previous, jumped)) {
        total += jumped - previous;
      }
      previous = jumped;
      // 再正常 2 秒
      for (var i = 0; i < 2; i++) {
        final current = previous + const Duration(seconds: 1);
        if (PlayerNotifier.shouldCountListening(previous, current)) {
          total += const Duration(seconds: 1);
        }
        previous = current;
      }

      expect(total, const Duration(seconds: 5),
          reason: '只有 5 秒真实播放被计入，10 分钟跳转不应计入');
    });
  });
}
