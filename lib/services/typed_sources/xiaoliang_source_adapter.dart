import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import 'source_utils.dart';
import 'typed_source_adapter.dart';

class XiaoLiangSourceAdapter implements TypedSourceAdapter {
  XiaoLiangSourceAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Logger _logger = Logger();

  @override
  String get sourceId => 'xiaoLiang';

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final url = '${source.sourceUrl}/Search?type=1&name=${Uri.encodeComponent(keyword)}';
    final response = await _get(url, source);
    if (response == null) return [];

    try {
      final document = html_parser.parse(response);
      final rows = document.querySelectorAll('.col-md-12.col-xs-12.section-box-list-item');
      final books = <Book>[];
      for (final row in rows) {
        final titleLink = row.querySelector('.box-list-item-text-title a');
        final title = titleLink?.text.trim();
        final href = titleLink?.attributes['href'];
        if (title == null || title.isEmpty || href == null || !title.contains(keyword)) {
          continue;
        }
        final fromUrl = SourceUtils.absoluteUrl(source.sourceUrl, href);
        if (fromUrl == null) continue;
        final speakers = row.querySelectorAll('.box-list-item-text-autspeaker a');
        final narrator = speakers.length > 1 ? speakers[1].text.trim() : null;
        var intro = row.querySelector('.box-list-item-text-intro')?.text.trim();
        if (intro != null && intro.length > 1000) intro = intro.substring(0, 1000);
        final cover = SourceUtils.absoluteUrl(
          source.sourceUrl,
          row.querySelector('img')?.attributes['src'],
        );
        final albumId = _albumIdFromUrl(fromUrl);
        books.add(
          Book(
            bookId: '${source.sourceId}_$albumId',
            sourceId: source.sourceId,
            name: title,
            narrator: narrator,
            coverUrl: cover,
            intro: intro,
            detailUrl: fromUrl,
          ),
        );
      }
      return books;
    } catch (e) {
      _logger.w('xiaoLiang search parse failed', error: e);
      return [];
    }
  }

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async => book;

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    final response = await _get(book.detailUrl, source);
    if (response == null) return [];

    try {
      final document = html_parser.parse(response);
      final links = document.querySelectorAll('.col-md-10.col-xs-10 a');
      final chapters = <Chapter>[];
      for (final link in links) {
        final title = link.text.trim();
        final onclick = link.attributes['onclick'] ?? '';
        final trackId = onclick
            .replaceAll("testFn('", '')
            .replaceAll("')", '')
            .trim();
        if (title.isEmpty || trackId.isEmpty || trackId == onclick) continue;
        chapters.add(
          Chapter(
            chapterId: SourceUtils.chapterId(book.bookId, chapters.length),
            bookId: book.bookId,
            index: chapters.length,
            name: title,
            url: trackId,
          ),
        );
      }
      return chapters;
    } catch (e) {
      _logger.w('xiaoLiang chapter parse failed', error: e);
      return [];
    }
  }

  @override
  Future<String?> getAudioUrl(SourceRule source, Chapter chapter) async {
    final url = '${source.sourceUrl}/api/app/docs-listen/${chapter.url}/ting-with-efi';
    final response = await _get(url, source);
    if (response == null) return null;

    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      final direct = SourceUtils.stringValue(json, ['url', 'zhuUrl', 'playUrl']);
      if (direct != null) return direct;
      // The recovered app decrypts `efi` with AES/CBC using track id and creation
      // time. Leave unsupported responses as null until the crypto dependency is
      // added and covered by fixtures.
      if (json['efi'] != null) return null;
      return null;
    } catch (e) {
      _logger.w('xiaoLiang audio parse failed', error: e);
      return null;
    }
  }

  Future<String?> _get(String url, SourceRule source) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(headers: SourceUtils.headers(source)),
      );
      return response.data;
    } catch (e) {
      _logger.w('xiaoLiang request failed: $url', error: e);
      return null;
    }
  }

  String _albumIdFromUrl(String url) {
    final parts = Uri.parse(url).pathSegments;
    if (parts.isEmpty) return SourceUtils.stableId(sourceId, url);
    return parts.length >= 3 ? parts[2] : parts.last;
  }
}
