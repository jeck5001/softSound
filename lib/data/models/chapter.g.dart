// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chapter _$ChapterFromJson(Map<String, dynamic> json) => Chapter(
  chapterId: json['chapterId'] as String,
  bookId: json['bookId'] as String,
  index: (json['index'] as num).toInt(),
  name: json['name'] as String,
  url: json['url'] as String,
  audioUrl: json['audioUrl'] as String?,
  duration: (json['duration'] as num?)?.toInt(),
  isVip: json['isVip'] as bool? ?? false,
  isCached: json['isCached'] as bool? ?? false,
  cachePath: json['cachePath'] as String?,
);

Map<String, dynamic> _$ChapterToJson(Chapter instance) => <String, dynamic>{
  'chapterId': instance.chapterId,
  'bookId': instance.bookId,
  'index': instance.index,
  'name': instance.name,
  'url': instance.url,
  'audioUrl': instance.audioUrl,
  'duration': instance.duration,
  'isVip': instance.isVip,
  'isCached': instance.isCached,
  'cachePath': instance.cachePath,
};
