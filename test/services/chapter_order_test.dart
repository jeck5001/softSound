import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/chapter_order.dart';

/// 章节顺序工具测试 —— 契约来自聆阅字节码 #17864 / #17865。
void main() {
  group('extractChapterNumber（正则级联，逐条对齐字节码）', () {
    test('「第 N 集/章/节/回」优先', () {
      expect(extractChapterNumber('第12集 风起'), 12);
      expect(extractChapterNumber('第 7 章'), 7);
      expect(extractChapterNumber('第003节'), 3);
      expect(extractChapterNumber('第 108 回 大结局'), 108);
    });

    test('无「第」的「N 集」', () {
      expect(extractChapterNumber('123集 番外'), 123);
      expect(extractChapterNumber('45 章'), 45);
    });

    test('开头编号 + 分隔符', () {
      expect(extractChapterNumber('007、开场'), 7);
      expect(extractChapterNumber('3. 序章'), 3);
      expect(extractChapterNumber('88_标题'), 88);
    });

    test('分隔符夹住的数字（括号/顿号等）', () {
      expect(extractChapterNumber('风起（12）云涌'), 12);
      expect(extractChapterNumber('番外-33-终'), 33);
      expect(extractChapterNumber('【5】'), 5);
    });

    test('结尾编号', () {
      expect(extractChapterNumber('大结局 120'), 120);
      expect(extractChapterNumber('尾声-9'), 9);
    });

    test('规则优先级：先命中规则 4 的「被分隔符夹住的数字」', () {
      // 「 2024 」满足 `[分隔符](\d+)[分隔符]`，按字节码级联顺序先于
      // 「结尾编号」规则命中 —— 这是上游标题的常见歧义，照搬不复刻
      // 更聪明的启发式，避免与聆阅行为分叉。
      expect(extractChapterNumber('音频 2024 版 66'), 2024);
      expect(extractChapterNumber('第 2 季 第 5 话'), 2);
    });

    test('无数字 → null', () {
      expect(extractChapterNumber('序章'), isNull);
      expect(extractChapterNumber(''), isNull);
      expect(extractChapterNumber(null), isNull);
    });
  });

  group('looksReversed（≥70% 降序才判定为倒序）', () {
    List<String> titles(Iterable<int> nums) => [for (final n in nums) '第$n集'];

    test('升序不翻转', () {
      final items = titles(List.generate(80, (i) => i + 1));
      expect(looksReversed(items, (e) => e), isFalse);
      expect(ensureAscending(items, (e) => e), same(items));
    });

    test('降序翻转', () {
      final items = titles(List.generate(80, (i) => 80 - i));
      expect(looksReversed(items, (e) => e), isTrue);
      final fixed = ensureAscending(items, (e) => e);
      expect(fixed.first, '第1集');
      expect(fixed.last, '第80集');
    });

    test('抽样点少于 3 → 不动（列表太短）', () {
      expect(looksReversed(['第3集', '第2集'], (e) => e), isFalse);
      expect(looksReversed(['第3集'], (e) => e), isFalse);
      expect(looksReversed(<String>[], (e) => e), isFalse);
    });

    test('标题无集号 → 不动（不能瞎排）', () {
      final items = List.generate(90, (i) => '无编号标题$i');
      expect(looksReversed(items, (e) => e), isFalse);
    });

    test('部分无编号时不误判（靠有编号的部分）', () {
      // 70 升 + 20 个无编号：仍应判为升序
      final items = <String>[
        for (var i = 1; i <= 70; i++) '第$i集',
        for (var i = 0; i < 20; i++) '花絮$i',
      ];
      expect(looksReversed(items, (e) => e), isFalse);
    });

    test('恰好 70% 降序即翻转（边界）', () {
      // 11 个抽样点 → 10 次相邻比较：7 降 3 升 → ratio = 0.7 → 翻转
      final nums = <int>[8, 7, 6, 5, 4, 3, 2, 1, 11, 12, 13];
      final items = titles(nums);
      expect(items.length, 11); // len <= 60 时 step = 1，抽样点即全部
      expect(looksReversed(items, (e) => e), isTrue);
    });

    test('低于 70% 不翻转', () {
      // 11 个抽样点：6 降 4 升 → 0.6 < 0.7
      final nums = <int>[7, 6, 5, 4, 3, 2, 1, 11, 12, 13, 14];
      expect(looksReversed(titles(nums), (e) => e), isFalse);
    });

    test('大量章节只抽样 1/60（性能与行为一致）', () {
      // 600 章 → step = 10 → 60 个抽样点，全部降序 → 翻转
      final items = titles(List.generate(600, (i) => 600 - i));
      expect(looksReversed(items, (e) => e), isTrue);
    });

    test('全等集号（total==0）→ 不动', () {
      final items = List.generate(90, (i) => '第5集');
      expect(looksReversed(items, (e) => e), isFalse);
    });
  });
}
