import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import 'source_utils.dart';
import 'typed_source_adapter.dart';

class XiaoKuSourceAdapter implements TypedSourceAdapter {
  XiaoKuSourceAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Logger _logger = Logger();

  @override
  String get sourceId => 'xiaoKu';

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final encoded = Uri.encodeComponent(keyword);
    final primary =
        'http://search.kuwo.cn/r.s?client=kt&all=$encoded&ft=album&newsearch=1&itemset=web_2013&cluster=0&pn=0&rn=15&rformat=json&encoding=utf8&show_copyright_off=1&vipver=MUSIC_8.0.3.0_BCS75&show_series_listen=1&version=9.1.8.1';
    final response = await _get(primary, source);
    if (response == null) return [];

    try {
      return parseSearchResponse(source, keyword, response);
    } catch (e) {
      _logger.w('xiaoKu search parse failed', error: e);
      return [];
    }
  }

  List<Book> parseSearchResponse(
    SourceRule source,
    String keyword,
    String response,
  ) {
    final json = SourceUtils.decodeLooseJsonObject(response);
    if (json == null) return [];
    final albums = json['albumlist'] as List<dynamic>? ?? const [];
    return albums
        .map((item) => _bookFromAlbum(source, item, keyword))
        .whereType<Book>()
        .toList();
  }

  Book? _bookFromAlbum(SourceRule source, dynamic item, String keyword) {
    if (item is! Map) return null;
    final album = Map<String, dynamic>.from(item);
    final id = SourceUtils.stringValue(album, [
      'id',
      'albumId',
      'albumid',
      'DC_TARGETID',
    ]);
    final title = SourceUtils.stringValue(album, ['name', 'albumName']);
    if (id == null || title == null || !title.contains(keyword)) return null;
    final tracks = SourceUtils.intValue(
      album,
      ['musiccnt', 'songTotal', 'nowTotal'],
    );
    if (tracks != null && tracks < 1) return null;
    return Book(
      bookId: '${source.sourceId}_$id',
      sourceId: source.sourceId,
      name: _clean(title),
      author:
          _trimNarrator(SourceUtils.stringValue(album, ['artist', 'artistName'])),
      narrator:
          _trimNarrator(SourceUtils.stringValue(album, ['artist', 'artistName'])),
      coverUrl: SourceUtils.stringValue(album, ['img', 'hts_img', 'coverImg']),
      intro: _cleanOptional(SourceUtils.stringValue(album, ['info', 'title'])),
      detailUrl: id,
      chapterCount: tracks,
    );
  }

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async => book;

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    final url =
        'http://search.kuwo.cn/r.s?stype=albuminfo&loginUid=0&loginSid=null&prod=kwplayer_ar_9.1.7.0&bkprod=kwbook_ar_9.1.7.0&source=kwplayer_ar_9.1.7.0_t18.apk&bksource=kwbook_ar_9.1.7.0_t18.apk&corp=kuwo&albumid=${book.detailUrl}&pn=0&rn=600&show_copyright_off=1&vipver=MUSIC_8.2.0.0_BCS17&mobi=1&sortby=3&iskwbook=1';
    final response = await _get(url, source);
    if (response == null) return [];

    try {
      return parseChapterResponse(book, response);
    } catch (e) {
      _logger.w('xiaoKu chapter parse failed', error: e);
      return [];
    }
  }

  List<Chapter> parseChapterResponse(Book book, String response) {
    final json = SourceUtils.decodeLooseJsonObject(response);
    if (json == null) return [];
    final tracks = json['musiclist'] as List<dynamic>? ?? const [];
    final chapters = <Chapter>[];
    for (final item in tracks) {
      if (item is! Map) continue;
      final track = Map<String, dynamic>.from(item);
      final trackId = SourceUtils.stringValue(track, ['musicrid', 'id']);
      final title = SourceUtils.stringValue(track, ['name']);
      if (trackId == null || title == null) continue;
      chapters.add(
        Chapter(
          chapterId: SourceUtils.chapterId(book.bookId, chapters.length),
          bookId: book.bookId,
          index: chapters.length,
          name: _clean(title),
          url: trackId,
          duration: SourceUtils.intValue(track, ['duration']),
        ),
      );
    }
    return chapters;
  }

  @override
  Future<String?> getAudioUrl(SourceRule source, Chapter chapter) async {
    if (chapter.audioUrl?.isNotEmpty == true) return chapter.audioUrl;
    final url =
        'https://mobi.kuwo.cn/mobi.s?f=web&user=0&source=kwplayercar_ar_6.0.0.9_B_jiakong_vh.apk&type=convert_url_with_sign&rid=${Uri.encodeComponent(chapter.url)}&br=320kmp3';
    final response = await _get(url, source);
    if (response == null || response.contains('<html')) return null;

    try {
      return parseAudioResponse(response);
    } catch (e) {
      _logger.w('xiaoKu audio parse failed', error: e);
      return null;
    }
  }

  String? parseAudioResponse(String response) {
    final json = SourceUtils.decodeLooseJsonObject(response);
    if (json == null || json['code'] != 200) return null;
    final data = json['data'] as Map<String, dynamic>?;
    final audioUrl = SourceUtils.stringValue(data ?? const {}, ['url']);
    if (audioUrl == null || audioUrl.contains('.wma')) return null;
    return audioUrl;
  }

  Future<String?> _get(String url, SourceRule source) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(headers: SourceUtils.headers(source)),
      );
      return response.data;
    } catch (e) {
      _logger.w('xiaoKu request failed: $url', error: e);
      return null;
    }
  }

  String _clean(String value) => value.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  String? _cleanOptional(String? value) => value?.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  String? _trimNarrator(String? value) {
    if (value == null) return null;
    final clean = value.replaceAll('主播', '').replaceAll(r'\u0026', '&').trim();
    return clean.length > 8 ? clean.substring(0, 8) : clean;
  }
}
