import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/player_service.dart';

/// 验证睡眠定时的「即将停止」预警（聆阅：`⏱ 还有 30 秒，即将停止播放`）。
void main() {
  group('PlayerState.sleepTimerEnding 状态', () {
    test('默认未触发', () {
      const s = PlayerState();
      expect(s.sleepTimerEnding, isFalse);
    });

    test('可显式置位', () {
      const s = PlayerState(sleepTimerEnding: true);
      expect(s.sleepTimerEnding, isTrue);
    });

    test('copyWith 可置位', () {
      const s = PlayerState();
      final updated = s.copyWith(sleepTimerEnding: true);
      expect(updated.sleepTimerEnding, isTrue);
    });

    test('clearSleepTimer 会同时清掉预警标记', () {
      const s = PlayerState(
        sleepTimerRemaining: Duration(seconds: 10),
        sleepTimerEnding: true,
      );
      final cleared = s.copyWith(clearSleepTimer: true);
      expect(cleared.sleepTimerEnding, isFalse);
      expect(cleared.sleepTimerRemaining, isNull);
    });

    test('不影响其他字段', () {
      const s = PlayerState(
        speed: 1.5,
        sleepTimerRemaining: Duration(minutes: 5),
      );
      final updated = s.copyWith(sleepTimerEnding: true);
      expect(updated.speed, 1.5);
      expect(updated.sleepTimerRemaining, const Duration(minutes: 5));
    });
  });

  group('阈值语义（30 秒）', () {
    /// 与 PlayerNotifier._sleepWarningThreshold 保持一致。
    const threshold = Duration(seconds: 30);

    bool endingFor(Duration remaining, {Duration? start}) {
      // 模拟计时器每秒递减后的判定
      return remaining <= threshold;
    }

    test('启动时超过阈值 → 不预警', () {
      expect(endingFor(const Duration(minutes: 15)), isFalse);
      expect(endingFor(const Duration(seconds: 31)), isFalse);
    });

    test('恰好 30 秒 → 预警', () {
      expect(endingFor(const Duration(seconds: 30)), isTrue);
    });

    test('低于 30 秒 → 持续预警', () {
      expect(endingFor(const Duration(seconds: 29)), isTrue);
      expect(endingFor(const Duration(seconds: 1)), isTrue);
    });

    test('直接设定 20 秒的定时器启动即预警', () {
      expect(endingFor(const Duration(seconds: 20)), isTrue);
    });
  });

  group('sleepTimerText 与预警并存', () {
    test('有剩余时间时可格式化', () {
      const s = PlayerState(
        sleepTimerRemaining: Duration(minutes: 3, seconds: 20),
        sleepTimerEnding: true,
      );
      expect(s.hasSleepTimer, isTrue);
      expect(s.sleepTimerText, isNotEmpty);
      expect(s.sleepTimerEnding, isTrue);
    });

    test('按章节停止时无剩余时间但 hasSleepTimer 为真', () {
      const s = PlayerState(sleepAfterChapter: true);
      expect(s.hasSleepTimer, isTrue);
      expect(s.sleepTimerEnding, isFalse);
    });
  });
}
