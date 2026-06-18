import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import 'source_utils.dart';
import 'typed_source_adapter.dart';

class LiuYueSourceAdapter implements TypedSourceAdapter {
  LiuYueSourceAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Logger _logger = Logger();

  @override
  String get sourceId => 'liuYue';

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final url =
        '${source.sourceUrl}/web/index/search?content=${Uri.encodeComponent(keyword)}&type=1&pageNum=1';
    final response = await _get(url, source);
    if (response == null || response.contains('File not found')) return [];

    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      if (json['code'] != 200) return [];
      final data = json['data'] as Map<String, dynamic>?;
      final list = data?['list'] as List<dynamic>? ?? const [];
      return list
          .map((item) => _bookFromSearch(source, item, keyword))
          .whereType<Book>()
          .toList();
    } catch (e) {
      _logger.w('liuYue search parse failed', error: e);
      return [];
    }
  }

  Book? _bookFromSearch(SourceRule source, dynamic item, String keyword) {
    if (item is! Map) return null;
    final book = Map<String, dynamic>.from(item);
    final code = SourceUtils.stringValue(book, ['code']);
    final title = SourceUtils.stringValue(book, ['name'])
        ?.replaceAll('<span style="color:red">', '')
        .replaceAll('</span>', '');
    if (code == null || title == null || !title.contains(keyword)) return null;

    return Book(
      bookId: '${source.sourceId}_$code',
      sourceId: source.sourceId,
      name: title,
      author: SourceUtils.stringValue(book, ['author']),
      narrator: SourceUtils.stringValue(book, ['broadcaster']),
      coverUrl: _coverUrl(SourceUtils.stringValue(book, ['coverUrlLocal'])),
      intro: SourceUtils.stringValue(book, ['descXx']),
      detailUrl: code,
      chapterCount: SourceUtils.intValue(book, ['trackTotalCount']),
    );
  }

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async => book;

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    final url = source.sourceUrl.replaceFirst('www.', 'm.') + '/list/${book.detailUrl}';
    final response = await _get(url, source);
    if (response == null) return [];

    try {
      final document = html_parser.parse(response);
      final links = document.querySelectorAll('.book-list a');
      final chapters = <Chapter>[];
      for (final link in links) {
        final number = link.text.trim();
        if (number.isEmpty) continue;
        chapters.add(
          Chapter(
            chapterId: SourceUtils.chapterId(book.bookId, chapters.length),
            bookId: book.bookId,
            index: chapters.length,
            name: '第$number集',
            url: number,
          ),
        );
      }
      return chapters;
    } catch (e) {
      _logger.w('liuYue chapter parse failed', error: e);
      return [];
    }
  }

  @override
  Future<String?> getAudioUrl(SourceRule source, Chapter chapter) async {
    return chapter.audioUrl?.isNotEmpty == true ? chapter.audioUrl : null;
  }

  Future<String?> _get(String url, SourceRule source) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(headers: SourceUtils.headers(source)),
      );
      return response.data;
    } catch (e) {
      _logger.w('liuYue request failed: $url', error: e);
      return null;
    }
  }

  String? _coverUrl(String? coverPath) {
    if (coverPath == null || coverPath.isEmpty) return null;
    if (coverPath.startsWith('http')) return coverPath;
    return 'http://img.tingshu168.com:20001/$coverPath';
  }
}
