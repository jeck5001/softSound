import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/subtitle_parser.dart';

void main() {
  const parser = SubtitleParser();

  group('标准 LRC 解析', () {
    test('基本时间标签 [mm:ss.xx]', () {
      final cues = parser.parse('''
[00:01.00]第一句
[00:05.50]第二句
[00:10.00]第三句
''');

      expect(cues, hasLength(3));
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].text, '第一句');
      expect(cues[1].start, const Duration(seconds: 5, milliseconds: 500));
      expect(cues[2].start, const Duration(seconds: 10));
    });

    test('cue 结束时间等于下一条起始时间', () {
      final cues = parser.parse('''
[00:01.00]A
[00:05.00]B
''');

      expect(cues[0].end, const Duration(seconds: 5));
      expect(cues[0].covers(const Duration(seconds: 3)), isTrue);
      expect(cues[0].covers(const Duration(seconds: 6)), isFalse);
    });

    test('无毫秒的 [mm:ss]', () {
      final cues = parser.parse('[00:07]七秒');
      expect(cues.single.start, const Duration(seconds: 7));
    });

    test('三位毫秒 [mm:ss.xxx]', () {
      final cues = parser.parse('[00:03.250]句');
      expect(cues.single.start, const Duration(seconds: 3, milliseconds: 250));
    });

    test('一位小数按十分之一秒解析', () {
      final cues = parser.parse('[00:02.5]句');
      expect(cues.single.start, const Duration(seconds: 2, milliseconds: 500));
    });

    test('两位小数按百分之一秒解析', () {
      final cues = parser.parse('[00:02.25]句');
      expect(cues.single.start, const Duration(seconds: 2, milliseconds: 250));
    });

    test('分钟可超过两位', () {
      final cues = parser.parse('[100:00.00]很久以后');
      expect(cues.single.start, const Duration(minutes: 100));
    });

    test('一行多个时间标签展开为多条', () {
      final cues = parser.parse('[00:01.00][00:05.00]同一句');
      expect(cues, hasLength(2));
      expect(cues[0].text, '同一句');
      expect(cues[1].text, '同一句');
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[1].start, const Duration(seconds: 5));
    });
  });

  group('元信息与偏移', () {
    test('忽略 ti/ar/al/by 元信息行', () {
      final cues = parser.parse('''
[ti:歌名]
[ar:歌手]
[al:专辑]
[by:某人]
[00:01.00]正文
''');
      expect(cues, hasLength(1));
      expect(cues.single.text, '正文');
    });

    test('offset 正向偏移整体时间', () {
      final cues = parser.parse('''
[offset:500]
[00:01.00]句
''');
      expect(cues.single.start, const Duration(milliseconds: 1500));
    });

    test('offset 负向偏移整体时间', () {
      final cues = parser.parse('''
[offset:-500]
[00:02.00]句
''');
      expect(cues.single.start, const Duration(milliseconds: 1500));
    });

    test('offset 导致负时间时钳为 0', () {
      final cues = parser.parse('''
[offset:-5000]
[00:01.00]句
''');
      expect(cues.single.start, Duration.zero);
    });
  });

  group('乱序与排序', () {
    test('乱序时间标签被排序', () {
      final cues = parser.parse('''
[00:10.00]第三
[00:01.00]第一
[00:05.00]第二
''');
      expect(cues.map((c) => c.text).toList(), ['第一', '第二', '第三']);
      expect(cues[0].start, const Duration(seconds: 1));
    });
  });

  group('降级与健壮性', () {
    test('null 输入返回空', () {
      expect(parser.parse(null), isEmpty);
    });

    test('空字符串返回空', () {
      expect(parser.parse(''), isEmpty);
      expect(parser.parse('   \n  \n'), isEmpty);
    });

    test('纯文本无时间标签 → 单条 cue', () {
      final cues = parser.parse('这是一整段没有时间戳的字幕');
      expect(cues, hasLength(1));
      expect(cues.single.start, Duration.zero);
      expect(cues.single.text, '这是一整段没有时间戳的字幕');
    });

    test('纯文本配合总时长设定结束时间', () {
      final cues = parser.parse(
        '整段文本',
        totalDuration: const Duration(minutes: 3),
      );
      expect(cues.single.end, const Duration(minutes: 3));
    });

    test('只有时间标签没有文本的行被忽略', () {
      final cues = parser.parse('''
[00:01.00]
[00:02.00]有文本
''');
      expect(cues, hasLength(1));
      expect(cues.single.text, '有文本');
    });

    test('CRLF 与 LF 换行都能处理', () {
      final crlf = parser.parse('[00:01.00]A\r\n[00:02.00]B');
      final lf = parser.parse('[00:01.00]A\n[00:02.00]B');
      expect(crlf, hasLength(2));
      expect(lf, hasLength(2));
      expect(crlf[0].text, lf[0].text);
    });

    test('畸形标签不抛异常', () {
      expect(() => parser.parse('[99:99.999]怪'), returnsNormally);
      expect(() => parser.parse('[:]怪'), returnsNormally);
      expect(() => parser.parse('[abc]怪'), returnsNormally);
      expect(() => parser.parse('[]'), returnsNormally);
    });

    test('最后一条 cue 无总时长时往后 5 秒', () {
      final cues = parser.parse('[00:01.00]唯一');
      expect(cues.single.end, const Duration(seconds: 6));
    });

    test('最后一条 cue 用总时长收尾', () {
      final cues = parser.parse(
        '[00:01.00]A\n[00:02.00]B',
        totalDuration: const Duration(minutes: 10),
      );
      expect(cues.last.end, const Duration(minutes: 10));
    });
  });

  group('textAt 位置查询', () {
    final cues = parser.parse('''
[00:00.00]第一句
[00:05.00]第二句
[00:10.00]第三句
''');

    test('命中起点', () {
      expect(parser.textAt(cues, Duration.zero), '第一句');
      expect(parser.textAt(cues, const Duration(seconds: 5)), '第二句');
    });

    test('命中区间中部', () {
      expect(parser.textAt(cues, const Duration(seconds: 3)), '第一句');
      expect(parser.textAt(cues, const Duration(seconds: 7)), '第二句');
    });

    test('命中边界（前闭后开）', () {
      // 第 4.999 秒仍属第一句
      expect(
        parser.textAt(cues, const Duration(milliseconds: 4999)),
        '第一句',
      );
      // 第 5 秒起属第二句
      expect(parser.textAt(cues, const Duration(seconds: 5)), '第二句');
    });

    test('超出末尾区间返回 null', () {
      // 最后一条结束时间为 start+5s = 15s
      expect(parser.textAt(cues, const Duration(seconds: 20)), isNull);
    });

    test('空列表返回 null', () {
      expect(parser.textAt(const [], const Duration(seconds: 1)), isNull);
    });
  });

  group('indexAt 索引查询', () {
    final cues = parser.parse('''
[00:00.00]A
[00:05.00]B
''');

    test('返回命中索引', () {
      expect(parser.indexAt(cues, Duration.zero), 0);
      expect(parser.indexAt(cues, const Duration(seconds: 6)), 1);
    });

    test('未命中返回 -1', () {
      expect(parser.indexAt(cues, const Duration(seconds: 30)), -1);
      expect(parser.indexAt(const [], Duration.zero), -1);
    });
  });

  group('SubtitleCue 相等性', () {
    test('字段相同则相等', () {
      const a = SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'x',
      );
      const b = SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'x',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('字段不同则不相等', () {
      const a = SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'x',
      );
      const b = SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'y',
      );
      expect(a, isNot(b));
    });
  });
}
