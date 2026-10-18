import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/listener_stats.dart';

void main() {
  group('ListenerLevels 等级划分', () {
    test('0 分钟为 1 级', () {
      expect(ListenerLevels.forMinutes(0).level, 1);
      expect(ListenerLevels.forMinutes(0).title, contains('初级听众'));
    });

    test('达到阈值即晋级', () {
      expect(ListenerLevels.forMinutes(59).level, 1);
      expect(ListenerLevels.forMinutes(60).level, 2);
      expect(ListenerLevels.forMinutes(299).level, 2);
      expect(ListenerLevels.forMinutes(300).level, 3);
    });

    test('超高时长封顶在最高级', () {
      final max = ListenerLevels.max;
      expect(ListenerLevels.forMinutes(999999).level, max.level);
      expect(ListenerLevels.forMinutes(999999).title, max.title);
    });

    test('负值按 0 处理（不越界）', () {
      expect(ListenerLevels.forMinutes(-100).level, 1);
    });

    test('等级阈值严格递增', () {
      for (var i = 1; i < ListenerLevels.all.length; i++) {
        expect(
          ListenerLevels.all[i].requiredMinutes,
          greaterThan(ListenerLevels.all[i - 1].requiredMinutes),
          reason: '第 $i 级阈值应大于前一级',
        );
      }
    });

    test('等级序号连续从 1 开始', () {
      for (var i = 0; i < ListenerLevels.all.length; i++) {
        expect(ListenerLevels.all[i].level, i + 1);
      }
    });

    test('next 返回下一级', () {
      expect(ListenerLevels.next(0)!.level, 2);
      expect(ListenerLevels.next(60)!.level, 3);
    });

    test('满级时 next 返回 null', () {
      expect(ListenerLevels.next(999999), isNull);
    });
  });

  group('ListenerStats 派生值', () {
    test('累计分钟换算', () {
      const s = ListenerStats(totalListening: Duration(minutes: 95));
      expect(s.totalMinutes, 95);
    });

    test('当前等级随时长变化', () {
      expect(
        const ListenerStats(totalListening: Duration(minutes: 0)).currentLevel.level,
        1,
      );
      expect(
        const ListenerStats(totalListening: Duration(minutes: 90)).currentLevel.level,
        2,
      );
      expect(
        const ListenerStats(totalListening: Duration(minutes: 500)).currentLevel.level,
        3,
      );
    });

    test('距离下一级分钟数', () {
      // 1 级(0) → 2 级(60)，已听 20 分钟，还需 40
      const s = ListenerStats(totalListening: Duration(minutes: 20));
      expect(s.minutesToNextLevel, 40);
    });

    test('满级时距离为 0', () {
      const s = ListenerStats(totalListening: Duration(minutes: 100000));
      expect(s.minutesToNextLevel, 0);
      expect(s.isMaxLevel, isTrue);
    });

    test('等级内进度计算', () {
      // 1 级 0 → 2 级 60；已听 30 → 0.5
      const s = ListenerStats(totalListening: Duration(minutes: 30));
      expect(s.levelProgress, closeTo(0.5, 0.001));
    });

    test('刚晋级时进度接近 0', () {
      const s = ListenerStats(totalListening: Duration(minutes: 60));
      expect(s.levelProgress, closeTo(0.0, 0.001));
    });

    test('进度不超过 1', () {
      const s = ListenerStats(totalListening: Duration(minutes: 59));
      expect(s.levelProgress, lessThanOrEqualTo(1.0));
    });

    test('满级进度为 1', () {
      const s = ListenerStats(totalListening: Duration(minutes: 100000));
      expect(s.levelProgress, 1.0);
    });
  });

  group('时长格式化', () {
    test('秒级', () {
      const s = ListenerStats(totalListening: Duration(seconds: 45));
      expect(s.formattedListening, '45 秒');
    });

    test('纯分钟', () {
      const s = ListenerStats(totalListening: Duration(minutes: 25));
      expect(s.formattedListening, '25 分钟');
    });

    test('整小时', () {
      const s = ListenerStats(totalListening: Duration(hours: 3));
      expect(s.formattedListening, '3 小时');
    });

    test('小时+分钟', () {
      const s = ListenerStats(
        totalListening: Duration(hours: 3, minutes: 25),
      );
      expect(s.formattedListening, '3 小时 25 分钟');
    });

    test('零时长', () {
      const s = ListenerStats();
      expect(s.formattedListening, '0 秒');
    });
  });

  group('copyWith', () {
    test('只改指定字段', () {
      const base = ListenerStats(
        totalListening: Duration(minutes: 10),
        bookCount: 5,
        favoriteCount: 3,
        listenedChapters: 20,
      );
      final s = base.copyWith(bookCount: 9);

      expect(s.bookCount, 9);
      expect(s.totalListening, base.totalListening);
      expect(s.favoriteCount, base.favoriteCount);
      expect(s.listenedChapters, base.listenedChapters);
    });
  });
}
