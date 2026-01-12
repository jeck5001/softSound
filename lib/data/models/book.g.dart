// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Book _$BookFromJson(Map<String, dynamic> json) => Book(
  bookId: json['bookId'] as String,
  sourceId: json['sourceId'] as String,
  name: json['name'] as String,
  author: json['author'] as String?,
  narrator: json['narrator'] as String?,
  coverUrl: json['coverUrl'] as String?,
  intro: json['intro'] as String?,
  detailUrl: json['detailUrl'] as String,
  chapterCount: (json['chapterCount'] as num?)?.toInt(),
  latestChapter: json['latestChapter'] as String?,
  updateTime: json['updateTime'] == null
      ? null
      : DateTime.parse(json['updateTime'] as String),
  inBookshelf: json['inBookshelf'] as bool? ?? false,
  addTime: json['addTime'] == null
      ? null
      : DateTime.parse(json['addTime'] as String),
);

Map<String, dynamic> _$BookToJson(Book instance) => <String, dynamic>{
  'bookId': instance.bookId,
  'sourceId': instance.sourceId,
  'name': instance.name,
  'author': instance.author,
  'narrator': instance.narrator,
  'coverUrl': instance.coverUrl,
  'intro': instance.intro,
  'detailUrl': instance.detailUrl,
  'chapterCount': instance.chapterCount,
  'latestChapter': instance.latestChapter,
  'updateTime': instance.updateTime?.toIso8601String(),
  'inBookshelf': instance.inBookshelf,
  'addTime': instance.addTime?.toIso8601String(),
};
