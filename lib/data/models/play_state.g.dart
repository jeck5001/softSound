// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayState _$PlayStateFromJson(Map<String, dynamic> json) => PlayState(
  bookId: json['bookId'] as String?,
  chapterId: json['chapterId'] as String?,
  chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
  position: (json['position'] as num?)?.toInt() ?? 0,
  duration: (json['duration'] as num?)?.toInt() ?? 0,
  speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
  isPlaying: json['isPlaying'] as bool? ?? false,
  updateTime: json['updateTime'] == null
      ? null
      : DateTime.parse(json['updateTime'] as String),
);

Map<String, dynamic> _$PlayStateToJson(PlayState instance) => <String, dynamic>{
  'bookId': instance.bookId,
  'chapterId': instance.chapterId,
  'chapterIndex': instance.chapterIndex,
  'position': instance.position,
  'duration': instance.duration,
  'speed': instance.speed,
  'isPlaying': instance.isPlaying,
  'updateTime': instance.updateTime.toIso8601String(),
};
