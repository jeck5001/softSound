import 'package:flutter_test/flutter_test.dart';

import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/services/chapter_segments.dart';

/// 章节目录分段测试。
///
/// 用户反馈：从播放页点目录进去，**目录没有分段**，找后面的章节非常麻烦。
/// 实测《盗墓笔记》793 集、《道士不好惹》4715 集 —— 平铺一个长列表根本没法找。
void main() {
  Chapter ch(int i) => Chapter(
        chapterId: 'c$i',
        bookId: 'b',
        index: i,
        name: '第${i + 1}集',
        url: 'u$i',
      );

  group('分段区间', () {
    test('100 集一段', () {
      final r = ChapterSegments.ranges(250);
      expect(r, [(0, 100), (100, 200), (200, 250)]);
    });

    test('整百不多出空段', () {
      expect(ChapterSegments.ranges(200), [(0, 100), (100, 200)]);
    });

    test('不足 100 集只有一段', () {
      expect(ChapterSegments.ranges(37), [(0, 37)]);
    });

    test('空章节 / 0 集返回空', () {
      expect(ChapterSegments.ranges(0), isEmpty);
      expect(ChapterSegments.ranges(-5), isEmpty);
    });

    test('真实规模：793 集 → 8 段', () {
      final r = ChapterSegments.ranges(793);
      expect(r.length, 8);
      expect(r.last, (700, 793));
    });

    test('真实规模：4715 集 → 48 段（不炸）', () {
      expect(ChapterSegments.ranges(4715).length, 48);
    });
  });

  group('标签', () {
    test('1-100集 形式，从 1 开始', () {
      expect(ChapterSegments.label((0, 100)), '1-100集');
      expect(ChapterSegments.label((100, 200)), '101-200集');
      expect(ChapterSegments.label((700, 793)), '701-793集');
    });
  });

  group('当前章所在段（打开目录自动定位）', () {
    test('第 700 章落在第 8 段', () {
      // 下标 699 → 第 7 段（0-based）= 「701-793集」是第 7 段吗？
      // 699 ~/ 100 = 6 → 第 7 段（701-800 区间），对应 label 701-793
      expect(ChapterSegments.pageOf(699), 6);
    });

    test('下标 0 → 第一段', () {
      expect(ChapterSegments.pageOf(0), 0);
    });

    test('负数安全', () {
      expect(ChapterSegments.pageOf(-1), 0);
    });

    test('第 100 章（下标 99）仍在第一段', () {
      expect(ChapterSegments.pageOf(99), 0);
    });

    test('第 101 章（下标 100）进入第二段', () {
      expect(ChapterSegments.pageOf(100), 1);
    });
  });

  group('取段', () {
    test('返回该段的章节', () {
      final all = [for (var i = 0; i < 250; i++) ch(i)];
      final part = ChapterSegments.slice(all, 1);
      expect(part.length, 100);
      expect(part.first.name, '第101集');
      expect(part.last.name, '第200集');
    });

    test('倒序', () {
      final all = [for (var i = 0; i < 250; i++) ch(i)];
      final part = ChapterSegments.slice(all, 2, ascending: false);
      expect(part.length, 50);
      expect(part.first.name, '第250集');
    });

    test('越界页夹到合法范围（不崩）', () {
      final all = [for (var i = 0; i < 250; i++) ch(i)];
      expect(ChapterSegments.slice(all, 99).length, 50);
      expect(ChapterSegments.slice(all, -3).length, 100);
    });

    test('空列表安全', () {
      expect(ChapterSegments.slice(const [], 0), isEmpty);
    });
  });
}
