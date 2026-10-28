import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// 媒体会话处理器：通知栏 / 锁屏 / 蓝牙按键 / 小米灵动岛的唯一入口。
///
/// 为什么不用 `just_audio_background`：
/// 它把控制项写死成「播放/暂停 + 停止 + 快进快退」，**没有上一章/下一章**，
/// 也没有真正的队列概念 —— 于是用户看到的现象就是
/// 「通知栏没有下一章按钮」「一章播完不会自动接下一章」。
///
/// 这里用 `audio_service` 的 [BaseAudioHandler] 自己接管：
/// - 控制项固定为 `上一章 / 播放-暂停 / 下一章`（手机锁屏、通知栏、蓝牙都读它）；
/// - [skipToNext] / [skipToPrevious] 直接转给播放器去切章；
/// - 队列（[queue]）随章节列表发布，系统据此显示「第 N / M」。
///
/// 处理器本身**不做业务判断**：切哪一章由 `PlayerNotifier` 决定，
/// 这里只转发意图 + 发布状态。
class LingtingAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioPlayer? _player;

  /// 切章意图：`+1` 下一章、`-1` 上一章。
  void Function(int delta)? onSkipChapter;

  /// 绑定播放器实例（由 `PlayerNotifier` 构造时注入）。
  void attachPlayer(AudioPlayer player) => _player = player;

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> setSpeed(double speed) async => _player?.setSpeed(speed);

  @override
  Future<void> stop() async {
    await _player?.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  /// 快进 30 秒（锁屏长按 / 通知栏快进按钮）。
  ///
  /// 夹到「时长 - 2 秒」，避免直接跳到结尾触发 completed，
  /// 让用户还能听到最后一句。
  @override
  Future<void> fastForward() async {
    final player = _player;
    if (player == null) return;
    final target = player.position + const Duration(seconds: 30);
    final total = player.duration;
    final limit = total == null
        ? target
        : (total > const Duration(seconds: 3)
            ? total - const Duration(seconds: 2)
            : total);
    await player.seek(target > limit ? limit : target);
  }

  /// 快退 15 秒（锁屏 / 通知栏快退按钮）。
  @override
  Future<void> rewind() async {
    final player = _player;
    if (player == null) return;
    final target = player.position - const Duration(seconds: 15);
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('[media] skipToNext -> ${onSkipChapter == null ? "未接线" : "切章"}');
    onSkipChapter?.call(1);
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('[media] skipToPrevious -> ${onSkipChapter == null ? "未接线" : "切章"}');
    onSkipChapter?.call(-1);
  }

  /// 发布「正在播放哪一章」以及队列。
  ///
  /// [items] 通常就是整本书的章节；[index] 是当前章。
  /// 队列里每项都带 [MediaItem] 元数据（标题/专辑/封面），
  /// 锁屏与灵动岛显示的就是它。
  void publishChapter({
    required List<MediaItem> items,
    required int index,
    required Duration position,
    required Duration duration,
    required bool playing,
    required bool buffering,
  }) {
    if (index < 0 || index >= items.length) return;
    queue.add(items);
    mediaItem.add(items[index]);
    updatePlaybackState(
      playing: playing,
      buffering: buffering,
      position: position,
      duration: duration,
      processingState: buffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
    );
  }

  /// 刷新播放状态（进度、播放/暂停、缓冲）。
  void updatePlaybackState({
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    AudioProcessingState? processingState,
  }) {
    final current = playbackState.value;
    playbackState.add(current.copyWith(
      controls: controlsFor(isPlaying: playing ?? current.playing),
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.fastForward,
        MediaAction.rewind,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState ?? current.processingState,
      playing: playing ?? current.playing,
      updatePosition: position ?? current.updatePosition,
      bufferedPosition: duration ?? current.bufferedPosition,
      speed: current.speed,
      queueIndex: queueIndexOf(mediaItem.value),
    ));
  }

  /// 三个常驻控制项：上一章 / 播放-暂停 / 下一章。
  ///
  /// 注意顺序即 `androidCompactActionIndices = [0,1,2]`，
  /// 也就是通知栏折叠态直接显示的三个按钮。
  List<MediaControl> controlsFor({required bool isPlaying}) => [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ];

  int? queueIndexOf(MediaItem? item) {
    if (item == null) return null;
    final items = queue.value;
    final i = items.indexWhere((e) => e.id == item.id);
    return i >= 0 ? i : null;
  }

  /// 供测试读取当前媒体项数量。
  @visibleForTesting
  int get debugQueueLength => queue.value.length;
}

/// 把 just_audio 的播放状态映射成 audio_service 的处理状态。
AudioProcessingState mapProcessingState(ProcessingState state) {
  switch (state) {
    case ProcessingState.idle:
      return AudioProcessingState.idle;
    case ProcessingState.loading:
      return AudioProcessingState.loading;
    case ProcessingState.buffering:
      return AudioProcessingState.buffering;
    case ProcessingState.ready:
      return AudioProcessingState.ready;
    case ProcessingState.completed:
      return AudioProcessingState.completed;
  }
}
