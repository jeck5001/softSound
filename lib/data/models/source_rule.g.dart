// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceRule _$SourceRuleFromJson(Map<String, dynamic> json) => SourceRule(
  sourceId: json['sourceId'] as String,
  sourceName: json['sourceName'] as String,
  sourceUrl: json['sourceUrl'] as String,
  sourceType: json['sourceType'] as String? ?? 'audio',
  enabled: json['enabled'] as bool? ?? true,
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  header: (json['header'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  search: SearchRule.fromJson(json['search'] as Map<String, dynamic>),
  detail: DetailRule.fromJson(json['detail'] as Map<String, dynamic>),
  chapter: ChapterRule.fromJson(json['chapter'] as Map<String, dynamic>),
  audio: AudioRule.fromJson(json['audio'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SourceRuleToJson(SourceRule instance) =>
    <String, dynamic>{
      'sourceId': instance.sourceId,
      'sourceName': instance.sourceName,
      'sourceUrl': instance.sourceUrl,
      'sourceType': instance.sourceType,
      'enabled': instance.enabled,
      'sortOrder': instance.sortOrder,
      'header': instance.header,
      'search': instance.search,
      'detail': instance.detail,
      'chapter': instance.chapter,
      'audio': instance.audio,
    };

SearchRule _$SearchRuleFromJson(Map<String, dynamic> json) => SearchRule(
  url: json['url'] as String,
  method: json['method'] as String? ?? 'GET',
  body: json['body'] as String?,
  charset: json['charset'] as String? ?? 'utf-8',
  bookList: json['bookList'] as String,
  bookName: json['bookName'] as String,
  bookUrl: json['bookUrl'] as String,
  author: json['author'] as String?,
  narrator: json['narrator'] as String?,
  cover: json['cover'] as String?,
  intro: json['intro'] as String?,
);

Map<String, dynamic> _$SearchRuleToJson(SearchRule instance) =>
    <String, dynamic>{
      'url': instance.url,
      'method': instance.method,
      'body': instance.body,
      'charset': instance.charset,
      'bookList': instance.bookList,
      'bookName': instance.bookName,
      'bookUrl': instance.bookUrl,
      'author': instance.author,
      'narrator': instance.narrator,
      'cover': instance.cover,
      'intro': instance.intro,
    };

DetailRule _$DetailRuleFromJson(Map<String, dynamic> json) => DetailRule(
  bookName: json['bookName'] as String?,
  author: json['author'] as String?,
  narrator: json['narrator'] as String?,
  cover: json['cover'] as String?,
  intro: json['intro'] as String?,
  chapterListUrl: json['chapterListUrl'] as String?,
  chapterList: json['chapterList'] as String?,
);

Map<String, dynamic> _$DetailRuleToJson(DetailRule instance) =>
    <String, dynamic>{
      'bookName': instance.bookName,
      'author': instance.author,
      'narrator': instance.narrator,
      'cover': instance.cover,
      'intro': instance.intro,
      'chapterListUrl': instance.chapterListUrl,
      'chapterList': instance.chapterList,
    };

ChapterRule _$ChapterRuleFromJson(Map<String, dynamic> json) => ChapterRule(
  chapterName: json['chapterName'] as String,
  chapterUrl: json['chapterUrl'] as String,
  isVip: json['isVip'] as String?,
  duration: json['duration'] as String?,
);

Map<String, dynamic> _$ChapterRuleToJson(ChapterRule instance) =>
    <String, dynamic>{
      'chapterName': instance.chapterName,
      'chapterUrl': instance.chapterUrl,
      'isVip': instance.isVip,
      'duration': instance.duration,
    };

AudioRule _$AudioRuleFromJson(Map<String, dynamic> json) => AudioRule(
  audioUrl: json['audioUrl'] as String,
  header: (json['header'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  apiUrl: json['apiUrl'] as String?,
  apiMethod: json['apiMethod'] as String?,
  apiBody: json['apiBody'] as String?,
  apiHeader: (json['apiHeader'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  apiResponseRule: json['apiResponseRule'] as String?,
);

Map<String, dynamic> _$AudioRuleToJson(AudioRule instance) => <String, dynamic>{
  'audioUrl': instance.audioUrl,
  'header': instance.header,
  'apiUrl': instance.apiUrl,
  'apiMethod': instance.apiMethod,
  'apiBody': instance.apiBody,
  'apiHeader': instance.apiHeader,
  'apiResponseRule': instance.apiResponseRule,
};
