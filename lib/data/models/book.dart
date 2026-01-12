import 'package:json_annotation/json_annotation.dart';

part 'book.g.dart';

/// 有声书数据模型
@JsonSerializable()
class Book {
  /// 书籍ID（由书源ID+书籍URL生成）
  final String bookId;

  /// 所属书源ID
  final String sourceId;

  /// 书名
  final String name;

  /// 作者
  final String? author;

  /// 播音员
  final String? narrator;

  /// 封面URL
  final String? coverUrl;

  /// 简介
  final String? intro;

  /// 书籍详情页URL
  final String detailUrl;

  /// 章节数量
  final int? chapterCount;

  /// 最新章节名称
  final String? latestChapter;

  /// 更新时间
  final DateTime? updateTime;

  /// 是否在书架中
  final bool inBookshelf;

  /// 加入书架时间
  final DateTime? addTime;

  Book({
    required this.bookId,
    required this.sourceId,
    required this.name,
    this.author,
    this.narrator,
    this.coverUrl,
    this.intro,
    required this.detailUrl,
    this.chapterCount,
    this.latestChapter,
    this.updateTime,
    this.inBookshelf = false,
    this.addTime,
  });

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);

  Map<String, dynamic> toJson() => _$BookToJson(this);

  Book copyWith({
    String? bookId,
    String? sourceId,
    String? name,
    String? author,
    String? narrator,
    String? coverUrl,
    String? intro,
    String? detailUrl,
    int? chapterCount,
    String? latestChapter,
    DateTime? updateTime,
    bool? inBookshelf,
    DateTime? addTime,
  }) {
    return Book(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      detailUrl: detailUrl ?? this.detailUrl,
      chapterCount: chapterCount ?? this.chapterCount,
      latestChapter: latestChapter ?? this.latestChapter,
      updateTime: updateTime ?? this.updateTime,
      inBookshelf: inBookshelf ?? this.inBookshelf,
      addTime: addTime ?? this.addTime,
    );
  }
}
