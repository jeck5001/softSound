import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import '../../theme/playback_settings.dart';
import 'source_utils.dart';
import 'typed_source_adapter.dart';

class XiaoQingSourceAdapter implements TypedSourceAdapter {
  XiaoQingSourceAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Logger _logger = Logger();

  @override
  String get sourceId => 'xiaoQing';

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async {
    if (keyword.trim().isEmpty) return [];
    final url =
        'https://webapi.qtfm.cn/api/mobile/search/keyword/${Uri.encodeComponent(keyword)}';
    final response = await _get(url, source);
    if (response == null) return [];

    try {
      return parseSearchResponse(source, keyword, response);
    } catch (e) {
      _logger.w('xiaoQing search parse failed', error: e);
      return [];
    }
  }

  List<Book> parseSearchResponse(
    SourceRule source,
    String keyword,
    String response,
  ) {
    final json = jsonDecode(response) as Map<String, dynamic>;
    final channels = json['channels'] as Map<String, dynamic>?;
    final all = json['all'] as Map<String, dynamic>?;
    final data = (channels?['data'] as List<dynamic>?) ??
        (all?['data'] as List<dynamic>?) ??
        const [];
    return data
        .map((item) => _bookFromChannel(source, item, keyword))
        .whereType<Book>()
        .take(8)
        .toList();
  }

  Book? _bookFromChannel(SourceRule source, dynamic item, String keyword) {
    if (item is! Map) return null;
    final channel = Map<String, dynamic>.from(item);
    final id = SourceUtils.stringValue(channel, ['parent_id', 'id']);
    final title = SourceUtils.stringValue(channel, ['title']);
    if (id == null || title == null || title.contains('凯叔')) return null;
    if (!title.contains(keyword)) return null;
    return Book(
      bookId: '${source.sourceId}_$id',
      sourceId: source.sourceId,
      name: _cleanRequired(title),
      author: SourceUtils.stringValue(channel, ['podcaster']),
      narrator: SourceUtils.stringValue(channel, ['podcaster']),
      coverUrl: SourceUtils.stringValue(channel, ['cover']),
      intro: _clean(SourceUtils.stringValue(channel, ['description'])),
      detailUrl: id,
      chapterCount: SourceUtils.intValue(channel, ['program_count']),
    );
  }

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async => book;

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    final channelResponse =
        await _get('https://webapi.qtfm.cn/api/mobile/channels/${book.detailUrl}', source);
    if (channelResponse == null) return [];

    try {
      final channelJson = jsonDecode(channelResponse) as Map<String, dynamic>;
      final channel = channelJson['channel'] as Map<String, dynamic>?;
      final version = SourceUtils.stringValue(channel ?? const {}, ['v']) ?? '0';
      final channelType = SourceUtils.stringValue(channel ?? const {}, ['channelType']);
      final isVip = channel?['novel_monthly_vip'] == true;
      if (isVip || channelType != 'free') return [];

      final programsUrl =
          'https://webapi.qtfm.cn/api/mobile/channels/${book.detailUrl}/programs?version=$version&page_index=1';
      final programsResponse = await _get(programsUrl, source);
      if (programsResponse == null) return [];
      return parseProgramsResponse(book, programsResponse);
    } catch (e) {
      _logger.w('xiaoQing chapter parse failed', error: e);
      return [];
    }
  }

  List<Chapter> parseProgramsResponse(Book book, String response) {
    final programsJson = jsonDecode(response) as Map<String, dynamic>;
    final programs = programsJson['programs'] as List<dynamic>? ?? const [];
    final chapters = <Chapter>[];
    for (final item in programs) {
      if (item is! Map) continue;
      final program = Map<String, dynamic>.from(item);
      if (program['isFree'] == false || program['isFree'] == 'false') continue;
      final title = SourceUtils.stringValue(program, ['title']);
      final programId = SourceUtils.stringValue(program, ['programId', 'id']);
      if (title == null || programId == null) continue;
      chapters.add(
        Chapter(
          chapterId: SourceUtils.chapterId(book.bookId, chapters.length),
          bookId: book.bookId,
          index: chapters.length,
          name: _cleanRequired(title),
          url: programId,
          audioUrl: _programAudioUrl(program),
          duration: SourceUtils.intValue(program, ['duration']),
        ),
      );
    }
    return chapters;
  }

  String? _programAudioUrl(Map<String, dynamic> program) {
    return SourceUtils.stringAt(program, [
      ['mediainfo', 'audioUrl'],
      ['mediainfo', 'url'],
      ['audioUrl'],
      ['url'],
    ]);
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

  Future<String?> _get(String url, SourceRule source) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(headers: SourceUtils.headers(source)),
      );
      return response.data;
    } catch (e) {
      _logger.w('xiaoQing request failed: $url', error: e);
      return null;
    }
  }

  String? _clean(String? value) {
    return value?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  String _cleanRequired(String value) => _clean(value) ?? value.trim();
}
