import 'package:json_annotation/json_annotation.dart';

part 'play_state.g.dart';

/// 播放状态数据模型
@JsonSerializable()
class PlayState {
  /// 当前播放的书籍ID
  final String? bookId;

  /// 当前播放的章节ID
  final String? chapterId;

  /// 当前播放的章节索引
  final int chapterIndex;

  /// 播放位置（毫秒）
  final int position;

  /// 章节总时长（毫秒）
  final int duration;

  /// 播放速度
  final double speed;

  /// 是否正在播放
  final bool isPlaying;

  /// 更新时间
  final DateTime updateTime;

  PlayState({
    this.bookId,
    this.chapterId,
    this.chapterIndex = 0,
    this.position = 0,
    this.duration = 0,
    this.speed = 1.0,
    this.isPlaying = false,
    DateTime? updateTime,
  }) : updateTime = updateTime ?? DateTime.now();

  factory PlayState.fromJson(Map<String, dynamic> json) =>
      _$PlayStateFromJson(json);

  Map<String, dynamic> toJson() => _$PlayStateToJson(this);

  PlayState copyWith({
    String? bookId,
    String? chapterId,
    int? chapterIndex,
    int? position,
    int? duration,
    double? speed,
    bool? isPlaying,
    DateTime? updateTime,
  }) {
    return PlayState(
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      isPlaying: isPlaying ?? this.isPlaying,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  /// 计算播放进度百分比
  double get progress => duration > 0 ? position / duration : 0;

  /// 格式化当前位置
  String get positionText => _formatDuration(position);

  /// 格式化总时长
  String get durationText => _formatDuration(duration);

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final hours = (minutes / 60).floor();

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
