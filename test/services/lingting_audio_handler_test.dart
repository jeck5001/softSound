import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:soft_sound/services/lingting_audio_handler.dart';

/// 媒体会话处理器测试。
///
/// 覆盖用户在真机上反馈的三件事：
/// 1. 通知栏/锁屏必须有「上一章 / 播放-暂停 / 下一章」三个按钮；
/// 2. 按钮必须真的能切章（意图转发给播放器）；
/// 3. 队列要发布出去，系统才知道「第 N / M 章」。
void main() {
  late LingtingAudioHandler handler;

  setUp(() {
    handler = LingtingAudioHandler();
  });

  MediaItem item(String id) => MediaItem(id: id, title: '第$id集');

  group('控制项', () {
    test('三键顺序：上一章 / 播放-暂停 / 下一章', () {
      final playing = handler.controlsFor(isPlaying: true);
      expect(playing.map((c) => c.action), [
        MediaAction.skipToPrevious,
        MediaAction.pause,
        MediaAction.skipToNext,
      ]);

      final paused = handler.controlsFor(isPlaying: false);
      expect(paused.map((c) => c.action), [
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.skipToNext,
      ]);
    });

    test('折叠态就是这三个按钮（androidCompactActionIndices）', () {
      handler.publishChapter(
        items: [item('1'), item('2')],
        index: 0,
        position: Duration.zero,
        duration: const Duration(minutes: 10),
        playing: true,
        buffering: false,
      );
      expect(handler.playbackState.value.androidCompactActionIndices,
          [0, 1, 2]);
      expect(handler.playbackState.value.controls, hasLength(3));
    });
  });

  group('切章意图', () {
    test('skipToNext / skipToPrevious 转发 ±1', () async {
      final calls = <int>[];
      handler.onSkipChapter = calls.add;

      await handler.skipToNext();
      await handler.skipToPrevious();
      await handler.skipToNext();

      expect(calls, [1, -1, 1]);
    });

    test('未接线时不抛（测试/无会话场景）', () async {
      await handler.skipToNext();
      await handler.skipToPrevious();
    });
  });

  group('队列发布', () {
    test('发布队列 + 当前项 + 播放状态', () {
      handler.publishChapter(
        items: [item('1'), item('2'), item('3')],
        index: 1,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 10),
        playing: true,
        buffering: false,
      );

      expect(handler.debugQueueLength, 3);
      expect(handler.mediaItem.value?.id, '2');
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.ready);
      expect(handler.playbackState.value.queueIndex, 1);
      expect(handler.playbackState.value.updatePosition,
          const Duration(seconds: 30));
    });

    test('缓冲中 → buffering 状态', () {
      handler.publishChapter(
        items: [item('1')],
        index: 0,
        position: Duration.zero,
        duration: Duration.zero,
        playing: false,
        buffering: true,
      );
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.buffering);
    });

    test('越界索引不崩（章节列表刚清空）', () {
      handler.publishChapter(
        items: [item('1')],
        index: 5,
        position: Duration.zero,
        duration: Duration.zero,
        playing: false,
        buffering: false,
      );
      expect(handler.debugQueueLength, 0);
    });
  });

  group('状态同步', () {
    test('updatePlaybackState 更新进度与播放态', () {
      handler.publishChapter(
        items: [item('1'), item('2')],
        index: 0,
        position: Duration.zero,
        duration: const Duration(minutes: 10),
        playing: false,
        buffering: false,
      );

      handler.updatePlaybackState(
        playing: true,
        position: const Duration(seconds: 42),
        duration: const Duration(minutes: 10),
      );

      final state = handler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.updatePosition, const Duration(seconds: 42));
      // 播放态变化后按钮要跟着变成「暂停」
      expect(state.controls[1].action, MediaAction.pause);
    });

    test('systemActions 含快进快退与上下章', () {
      handler.updatePlaybackState(playing: true);
      final actions = handler.playbackState.value.systemActions;
      expect(actions, contains(MediaAction.skipToNext));
      expect(actions, contains(MediaAction.skipToPrevious));
      expect(actions, contains(MediaAction.seek));
    });
  });

  group('无播放器时安全', () {
    test('play/pause/seek/stop 不抛', () async {
      await handler.play();
      await handler.pause();
      await handler.seek(const Duration(seconds: 1));
      await handler.fastForward();
      await handler.rewind();
      await handler.stop();
    });
  });

  group('处理状态映射', () {
    test('just_audio → audio_service', () {
      expect(mapProcessingState(ProcessingState.idle),
          AudioProcessingState.idle);
      expect(mapProcessingState(ProcessingState.loading),
          AudioProcessingState.loading);
      expect(mapProcessingState(ProcessingState.buffering),
          AudioProcessingState.buffering);
      expect(mapProcessingState(ProcessingState.ready),
          AudioProcessingState.ready);
      expect(mapProcessingState(ProcessingState.completed),
          AudioProcessingState.completed);
    });
  });
}
