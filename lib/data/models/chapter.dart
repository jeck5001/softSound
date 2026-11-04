import 'package:json_annotation/json_annotation.dart';

part 'chapter.g.dart';

/// 章节数据模型
@JsonSerializable()
class Chapter {
  /// 章节ID（由书籍ID+章节索引生成）
  final String chapterId;

  /// 所属书籍ID
  final String bookId;

  /// 章节索引（从0开始）
  final int index;

  /// 章节名称
  final String name;

  /// 章节页面URL
  final String url;

  /// 音频URL（解析后获取）
  final String? audioUrl;

  /// 时长（秒）
  final int? duration;

  /// 是否为VIP章节
  final bool isVip;

  /// 是否已缓存
  final bool isCached;

  /// 缓存文件路径
  final String? cachePath;

  /// 上游的**绝对序号**（懒人 `section`，1 起）。
  /// 目录缓存需要它：缺页时列表 index 会连续化，
  /// 但补拉/判完整性必须知道每章在书里的真实位置。
  @JsonKey(includeIfNull: false)
  final int? sectionIndex;

  Chapter({
    required this.chapterId,
    required this.bookId,
    required this.index,
    required this.name,
    required this.url,
    this.audioUrl,
    this.duration,
    this.isVip = false,
    this.isCached = false,
    this.cachePath,
    this.sectionIndex,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) =>
      _$ChapterFromJson(json);

  Map<String, dynamic> toJson() => _$ChapterToJson(this);

  Chapter copyWith({
    String? chapterId,
    String? bookId,
    int? index,
    String? name,
    String? url,
    String? audioUrl,
    int? duration,
    bool? isVip,
    bool? isCached,
    String? cachePath,
    int? sectionIndex,
  }) {
    return Chapter(
      chapterId: chapterId ?? this.chapterId,
      bookId: bookId ?? this.bookId,
      index: index ?? this.index,
      name: name ?? this.name,
      url: url ?? this.url,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      isVip: isVip ?? this.isVip,
      isCached: isCached ?? this.isCached,
      cachePath: cachePath ?? this.cachePath,
      sectionIndex: sectionIndex ?? this.sectionIndex,
    );
  }
}
