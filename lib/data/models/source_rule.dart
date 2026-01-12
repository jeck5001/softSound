import 'package:json_annotation/json_annotation.dart';

part 'source_rule.g.dart';

/// 书源规则 - 定义如何从网站抓取有声书数据
@JsonSerializable()
class SourceRule {
  /// 书源唯一标识
  final String sourceId;

  /// 书源名称
  final String sourceName;

  /// 书源基础URL
  final String sourceUrl;

  /// 书源类型: audio/text
  final String sourceType;

  /// 是否启用
  final bool enabled;

  /// 排序权重
  final int sortOrder;

  /// 全局请求头
  final Map<String, String>? header;

  /// 搜索规则
  final SearchRule search;

  /// 详情页规则
  final DetailRule detail;

  /// 章节规则
  final ChapterRule chapter;

  /// 音频规则
  final AudioRule audio;

  SourceRule({
    required this.sourceId,
    required this.sourceName,
    required this.sourceUrl,
    this.sourceType = 'audio',
    this.enabled = true,
    this.sortOrder = 0,
    this.header,
    required this.search,
    required this.detail,
    required this.chapter,
    required this.audio,
  });

  factory SourceRule.fromJson(Map<String, dynamic> json) =>
      _$SourceRuleFromJson(json);

  Map<String, dynamic> toJson() => _$SourceRuleToJson(this);
}

/// 搜索规则
@JsonSerializable()
class SearchRule {
  /// 搜索URL，{{keyword}}为关键词占位符
  final String url;

  /// 请求方法: GET/POST
  final String method;

  /// POST请求体
  final String? body;

  /// 字符编码
  final String charset;

  /// 书籍列表选择器
  final String bookList;

  /// 书名选择器
  final String bookName;

  /// 书籍URL选择器
  final String bookUrl;

  /// 作者选择器
  final String? author;

  /// 播音员选择器
  final String? narrator;

  /// 封面选择器
  final String? cover;

  /// 简介选择器
  final String? intro;

  SearchRule({
    required this.url,
    this.method = 'GET',
    this.body,
    this.charset = 'utf-8',
    required this.bookList,
    required this.bookName,
    required this.bookUrl,
    this.author,
    this.narrator,
    this.cover,
    this.intro,
  });

  factory SearchRule.fromJson(Map<String, dynamic> json) =>
      _$SearchRuleFromJson(json);

  Map<String, dynamic> toJson() => _$SearchRuleToJson(this);
}

/// 详情页规则
@JsonSerializable()
class DetailRule {
  /// 书名选择器
  final String? bookName;

  /// 作者选择器
  final String? author;

  /// 播音员选择器
  final String? narrator;

  /// 封面选择器
  final String? cover;

  /// 简介选择器
  final String? intro;

  /// 章节列表URL（为空则在当前页）
  final String? chapterListUrl;

  /// 章节列表选择器
  final String? chapterList;

  DetailRule({
    this.bookName,
    this.author,
    this.narrator,
    this.cover,
    this.intro,
    this.chapterListUrl,
    this.chapterList,
  });

  factory DetailRule.fromJson(Map<String, dynamic> json) =>
      _$DetailRuleFromJson(json);

  Map<String, dynamic> toJson() => _$DetailRuleToJson(this);
}

/// 章节规则
@JsonSerializable()
class ChapterRule {
  /// 章节名称选择器
  final String chapterName;

  /// 章节URL选择器
  final String chapterUrl;

  /// VIP标识选择器
  final String? isVip;

  /// 时长选择器
  final String? duration;

  ChapterRule({
    required this.chapterName,
    required this.chapterUrl,
    this.isVip,
    this.duration,
  });

  factory ChapterRule.fromJson(Map<String, dynamic> json) =>
      _$ChapterRuleFromJson(json);

  Map<String, dynamic> toJson() => _$ChapterRuleToJson(this);
}

/// 音频规则
@JsonSerializable()
class AudioRule {
  /// 音频URL规则，支持 css:/regex:/js:/api: 前缀
  final String audioUrl;

  /// 音频请求头
  final Map<String, String>? header;

  /// 动态接口URL（可选，用于需要先请求接口获取音频地址的情况）
  final String? apiUrl;

  /// 动态接口请求方法
  final String? apiMethod;

  /// 动态接口请求体模板
  final String? apiBody;

  /// 动态接口请求头模板（支持从页面meta标签提取变量）
  final Map<String, String>? apiHeader;

  /// 从接口响应中提取音频URL的规则（JSON路径）
  final String? apiResponseRule;

  AudioRule({
    required this.audioUrl,
    this.header,
    this.apiUrl,
    this.apiMethod,
    this.apiBody,
    this.apiHeader,
    this.apiResponseRule,
  });

  factory AudioRule.fromJson(Map<String, dynamic> json) =>
      _$AudioRuleFromJson(json);

  Map<String, dynamic> toJson() => _$AudioRuleToJson(this);
}
