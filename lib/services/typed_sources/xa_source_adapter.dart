import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import '../../theme/playback_settings.dart';
import 'source_utils.dart';
import 'typed_source_adapter.dart';

class XaSourceAdapter implements TypedSourceAdapter {
  XaSourceAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Logger _logger = Logger();

  @override
  String get sourceId => 'XA';

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final url =
        'https://m.ximalaya.com/m-revision/page/search?kw=${Uri.encodeComponent(keyword)}&core=album&page=1&rows=20';
    final response = await _get(url, source);
    if (response == null) return [];

    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      if (json['ret'] != 0) return [];
      final data = json['data'] as Map<String, dynamic>?;
      final albumViews = data?['albumViews'] as Map<String, dynamic>?;
      final albums = albumViews?['albums'] as List<dynamic>? ?? const [];

      return albums
          .map((item) => _bookFromSearch(source, item, keyword))
          .whereType<Book>()
          .toList();
    } catch (e) {
      _logger.w('XA search parse failed', error: e);
      return [];
    }
  }

  Book? _bookFromSearch(SourceRule source, dynamic item, String keyword) {
    final wrapper = item is Map ? Map<String, dynamic>.from(item) : null;
    final infoRaw = wrapper?['albumInfo'];
    if (infoRaw is! Map) return null;
    final info = Map<String, dynamic>.from(infoRaw);

    final id = SourceUtils.stringValue(info, ['id', 'albumId']);
    final title = SourceUtils.stringValue(info, ['title']);
    if (id == null || title == null || !title.contains(keyword)) return null;
    final tracks = SourceUtils.intValue(info, ['tracks', 'trackCount']);
    if (tracks != null && tracks <= 0) return null;

    final priceType = SourceUtils.stringValue(info, ['price_type_enum']);
    final vipFreeType = SourceUtils.stringValue(info, ['vipFreeType']);
    final displayPrice = SourceUtils.stringValue(info, ['display_price_with_unit']);
    if (vipFreeType == '1' || priceType == '2' || (displayPrice?.contains('喜点') ?? false)) {
      return null;
    }

    return Book(
      bookId: '${source.sourceId}_$id',
      sourceId: source.sourceId,
      name: _cleanRequired(title),
      author: SourceUtils.stringValue(info, ['nickname', 'anchorName']),
      narrator: SourceUtils.stringValue(info, ['nickname', 'anchorName']),
      coverUrl: SourceUtils.stringValue(info, ['cover_path', 'cover']),
      intro: _clean(SourceUtils.stringValue(info, ['intro', 'shortIntro'])),
      detailUrl: id,
      chapterCount: tracks,
    );
  }

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async => book;

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    final url =
        'http://mobile.ximalaya.com/mobile/others/ca/album/track/${book.detailUrl}/true/1/200';
    final response = await _get(url, source);
    if (response == null) return [];

    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      if (json['ret'] != 0) return [];
      final tracks = json['tracks'] as Map<String, dynamic>?;
      final list = tracks?['list'] as List<dynamic>? ?? const [];
      final chapters = <Chapter>[];
      for (final item in list) {
        final track = item is Map ? Map<String, dynamic>.from(item) : null;
        if (track == null) continue;
        final title = SourceUtils.stringValue(track, ['title']);
        final trackId = SourceUtils.stringValue(track, ['trackId']);
        final audioUrl = _firstAudioUrl(track);
        if (title == null || trackId == null || audioUrl == null) continue;
        chapters.add(
          Chapter(
            chapterId: SourceUtils.chapterId(book.bookId, chapters.length),
            bookId: book.bookId,
            index: chapters.length,
            name: _cleanRequired(title),
            url: trackId,
            audioUrl: audioUrl,
            duration: SourceUtils.intValue(track, ['duration']),
            isVip: false,
          ),
        );
      }
      return chapters;
    } catch (e) {
      _logger.w('XA chapter parse failed', error: e);
      return [];
    }
  }

  /// 上游无字幕接口（字节码确认 lrts/六翼/喜马拉雅等播放响应不含 lyric）。
  @override
  Future<String?> getLyric(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  }) async =>
      null;

  @override
  Future<String?> getAudioUrl(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  }) async {
    return chapter.audioUrl?.isNotEmpty == true ? chapter.audioUrl : null;
  }

  String? _firstAudioUrl(Map<String, dynamic> track) {
    return SourceUtils.stringValue(track, [
      'playUrl64',
      'playPathAacv164',
      'playUrl32',
      'playPathAacv224',
    ]);
  }

  Future<String?> _get(String url, SourceRule source) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(headers: SourceUtils.headers(source)),
      );
      return response.data;
    } catch (e) {
      _logger.w('XA request failed: $url', error: e);
      return null;
    }
  }

  String? _clean(String? value) {
    return value
        ?.replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('\\v', '')
        .trim();
  }

  String _cleanRequired(String value) => _clean(value) ?? value.trim();
}
