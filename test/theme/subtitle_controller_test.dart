import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/subtitle_overlay.dart';

void main() {
  const lrc = '''
[00:00.00]第一句
[00:05.00]第二句
[00:10.00]第三句
''';

  group('loadLrc', () {
    test('加载后立即显示首句', () {
      final c = SubtitleController();
      c.loadLrc(lrc);

      expect(c.state.hasCues, isTrue);
      expect(c.state.text, '第一句');
      expect(c.state.activeIndex, 0);
      expect(c.state.unavailable, isFalse);
    });

    test('空字幕标记为 unavailable', () {
      final c = SubtitleController();
      c.loadLrc('');

      expect(c.state.hasCues, isFalse);
      expect(c.state.unavailable, isTrue);
    });

    test('null 字幕标记为 unavailable', () {
      final c = SubtitleController();
      c.loadLrc(null);
      expect(c.state.unavailable, isTrue);
    });

    test('解析出 cue 数量正确', () {
      final c = SubtitleController();
      c.loadLrc(lrc);
      expect(c.state.cues, hasLength(3));
    });
  });

  group('syncTo 位置同步', () {
    test('推进到第二句', () {
      final c = SubtitleController();
      c.loadLrc(lrc);

      c.syncTo(const Duration(seconds: 6));
      expect(c.state.text, '第二句');
      expect(c.state.activeIndex, 1);
    });

    test('推进到第三句', () {
      final c = SubtitleController();
      c.loadLrc(lrc);

      c.syncTo(const Duration(seconds: 12));
      expect(c.state.text, '第三句');
      expect(c.state.activeIndex, 2);
    });

    test('回到第一句（seek 后退）', () {
      final c = SubtitleController();
      c.loadLrc(lrc);
      c.syncTo(const Duration(seconds: 12));
      c.syncTo(const Duration(seconds: 2));

      expect(c.state.text, '第一句');
      expect(c.state.activeIndex, 0);
    });

    test('超出末尾区间清空文本但保留 cues', () {
      final c = SubtitleController();
      c.loadLrc(lrc);

      // 最后一条 10s 起，无总时长 → 结束于 15s
      c.syncTo(const Duration(seconds: 30));
      expect(c.state.hasText, isFalse);
      expect(c.state.activeIndex, -1);
      expect(c.state.hasCues, isTrue, reason: 'cues 应保留以便 seek 回来');
    });

    test('无 cues 时 syncTo 无副作用', () {
      final c = SubtitleController();
      c.syncTo(const Duration(seconds: 5));
      expect(c.state.cues, isEmpty);
    });

    test('同一位置重复同步不改变状态对象', () {
      final c = SubtitleController();
      c.loadLrc(lrc);

      c.syncTo(const Duration(seconds: 1));
      final first = c.state;
      c.syncTo(const Duration(seconds: 2)); // 仍属第一句
      expect(identical(c.state, first), isTrue,
          reason: '同一 cue 内不应产生新状态');
    });
  });

  group('状态标记', () {
    test('startLoading', () {
      final c = SubtitleController();
      c.startLoading();
      expect(c.state.isLoading, isTrue);
    });

    test('markUnavailable', () {
      final c = SubtitleController();
      c.markUnavailable();
      expect(c.state.unavailable, isTrue);
      expect(c.state.hasText, isFalse);
    });

    test('clear 重置全部（含总时长）', () {
      final c = SubtitleController();
      c.loadLrc(lrc, totalDuration: const Duration(minutes: 5));
      c.clear();

      expect(c.state.cues, isEmpty);
      expect(c.state.text, isNull);
      expect(c.state.isLoading, isFalse);
      expect(c.state.unavailable, isFalse);
    });
  });

  group('兼容旧接口 setSubtitle', () {
    test('设置单条文本', () {
      final c = SubtitleController();
      c.setSubtitle('单句字幕');

      expect(c.state.text, '单句字幕');
      expect(c.state.cues, hasLength(1));
      expect(c.state.hasText, isTrue);
    });

    test('空文本标记 unavailable', () {
      final c = SubtitleController();
      c.setSubtitle('   ');
      expect(c.state.unavailable, isTrue);
    });

    test('沿用先前总时长作为结束时间', () {
      final c = SubtitleController();
      c.loadLrc(lrc, totalDuration: const Duration(minutes: 3));
      c.setSubtitle('新句');

      expect(c.state.cues.single.end, const Duration(minutes: 3));
    });
  });
}
