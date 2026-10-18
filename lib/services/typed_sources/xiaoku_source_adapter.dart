import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import '../../theme/playback_settings.dart';
import 'source_utils.dart';
import 'typed_source_adapter.dart';

class XiaoKuSourceAdapter implements TypedSourceAdapter {
  XiaoKuSourceAdapter({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Logger _logger = Logger();

  /// 直连章节单页请求条数。
  ///
  /// 实测上游单页最多认 2000（`rn=5000` 仍只返回 2000 条），
  /// 取 1000 是「单响应体积（约 3 MB）与请求次数」的折中。
  static const int chapterPageSize = 1000;

  /// 翻页上限（防御异常 `songnum` 导致的死循环）：1000 × 40 = 4 万集。
  static const int maxChapterPages = 40;

  @override
  String get sourceId => 'xiaoKu';

  /// 搜索：Edge 主路 + 直连补充，**并集去重**（2026-10-16 实测修正）。
  ///
  /// 根因：聆阅走 Edge `kuwo-search?keyword=&pn=&rn=`（total=132 可翻页），
  /// 直连 `r.s` 固定 30 条且两条路结果集交集只有一半
  /// （edge 独有「剑来|完整版」等，direct 独有「剑来广播剧第七季」等）。
  /// 只走任一条都会「搜不到对方有的书」，故取并集：edge 在前（与聆阅同源），
  /// direct 兜底并补充；Edge 429 限流时仍有 direct 结果。
  @override
  Future<List<Book>> search(SourceRule source, String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];

    final results = await Future.wait([
      _edgeSearch(source, kw),
      _directSearch(source, kw),
    ]);

    final seen = <String>{};
    final out = <Book>[];
    for (final list in results) {
      for (final b in list) {
        if (seen.add(b.bookId)) out.add(b);
      }
    }
    return out;
  }

  /// Edge 主路（聆阅同款）：取两页共 40 条，429 退避重试。
  Future<List<Book>> _edgeSearch(SourceRule source, String kw) async {
    final encoded = Uri.encodeComponent(kw);
    final out = <Book>[];
    for (var pn = 1; pn <= 2; pn++) {
      final body = await _edgeGet(
          '/kuwo-search?keyword=$encoded&pn=$pn&rn=20', retryOnLimit: true);
      if (body == null) break;
      out.addAll(parseEdgeSearchResponse(source, body));
    }
    return out;
  }

  /// 解析 Edge `kuwo-search` 响应（书格式与 lrts-home 同构）。
  /// 独立方法便于真实报文单测。
  List<Book> parseEdgeSearchResponse(SourceRule source, String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      final books = json['books'];
      if (books is! List) return const [];
      return [
        for (final b in books)
          if (b is Map && '${b['id'] ?? ''}'.isNotEmpty)
            Book(
              bookId: '${source.sourceId}_${b['id']}',
              sourceId: source.sourceId,
              name: _clean('${b['title'] ?? ''}'),
              author: _trimNarrator(_strOrNull(b['author'])),
              narrator: _trimNarrator(_strOrNull(b['narrator'])),
              coverUrl: _strOrNull(b['cover']),
              intro: _cleanOptional(_strOrNull(b['description'])),
              detailUrl: '${b['id']}',
              chapterCount: b['chapters'] is List
                  ? ((b['chapters'] as List).isEmpty
                      ? null
                      : (b['chapters'] as List).length)
                  : int.tryParse('${b['chapters'] ?? ''}'),
            ),
      ];
    } catch (e) {
      _logger.w('xiaoKu edge search parse failed', error: e);
      return const [];
    }
  }

  static String? _strOrNull(dynamic v) {
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  /// 直连补充路（原有实现，rn 提到 30）。
  Future<List<Book>> _directSearch(SourceRule source, String kw) async {
    final encoded = Uri.encodeComponent(kw);
    final primary =
        'http://search.kuwo.cn/r.s?client=kt&all=$encoded&ft=album&newsearch=1&itemset=web_2013&cluster=0&pn=0&rn=30&rformat=json&encoding=utf8&show_copyright_off=1&vipver=MUSIC_8.0.3.0_BCS75&show_series_listen=1&version=9.1.8.1';
    final response = await _get(primary, source);
    if (response == null) return [];

    try {
      return parseSearchResponse(source, kw, response);
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

  /// 章节列表：直连分页为主，Edge 仅兜底（2026-10-19 用户反馈修复）。
  ///
  /// 根因纠正：此前注释认定「直连被上游封顶 600 集、且 pn 偏移分页返回空」，
  /// 于是只请求单页 `pn=0&rn=600`，把**自己的单页请求**当成了上游限制。
  /// 2026-10-19 实测（夜无疆 94386841 / 完美世界 93621135 / 遮天广播剧 58835793）：
  /// - `rn` 的真实封顶是 **2000**（rn=5000 仍只回 2000 条），不是 600；
  /// - `pn` 是 0 基页号，页间连续、无重叠无缺口：
  ///   完美世界 songnum=3867 → rn=1000 时 pn=0..3 依次 1000/1000/1000/867 条，
  ///   合计 3867 条且 musicrid 全部唯一；
  /// - 直连 `musicrid` 与 Edge `chapters[].id` 完全一致（907/907 重叠），可互换播放；
  /// - 直连 `duration` 是精确值（455/451/471…），Edge 恒为粗值 600。
  /// 即「超过 600 集就截断」纯粹是单页请求所致，翻页即可拿全量。
  ///
  /// Edge 降为兜底的原因：它常被服务端限流（429
  /// projectConcurrencyLimitExceeded），旧实现在 Edge 失败时静默退回单页 600 集——
  /// 这正是「聆阅里 900 多集、这里只有 600 集」的成因。
  /// 另外 Edge 的 `paid` 不可信（夜无疆实测 893/907 标 paid，
  /// 而直连 `pay=0` 且 `convert_url_with_sign` 实测能返回真实播放地址），
  /// 故不再用 Edge 覆盖直连章节的时长与 VIP 标记。
  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    final direct = await _directChapters(source, book);
    if (direct.isNotEmpty) return direct;

    final edgeBody = await _edgeGet(
      '/kuwo-episodes?albumId=${Uri.encodeComponent(book.detailUrl)}',
      retryOnLimit: true,
    );
    return edgeBody == null ? const [] : parseEdgeEpisodes(book, edgeBody);
  }

  /// 解析 Edge `kuwo-episodes`：`{chapters:[{id,title,duration,paid}]}`。
  /// 独立方法便于真实报文单测。
  List<Chapter> parseEdgeEpisodes(Book book, String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      final eps = json['chapters'];
      if (eps is! List) return const [];
      final out = <Chapter>[];
      for (final e in eps) {
        if (e is! Map) continue;
        final id = '${e['id'] ?? ''}'.trim();
        final title = '${e['title'] ?? ''}'.trim();
        if (id.isEmpty || title.isEmpty) continue;
        out.add(Chapter(
          chapterId: SourceUtils.chapterId(book.bookId, out.length),
          bookId: book.bookId,
          index: out.length,
          name: _clean(title),
          url: id, // = musicrid，与直连一致，getAudioUrl 直接可用
          duration: e['duration'] is num ? (e['duration'] as num).toInt() : null,
          isVip: e['paid'] == true,
        ));
      }
      return out;
    } catch (e) {
      _logger.w('xiaoKu edge episodes parse failed', error: e);
      return const [];
    }
  }

  /// 直连章节全量翻页（主路）。
  ///
  /// 上游单页最多 [chapterPageSize] 条，`pn` 为 0 基页号；
  /// 以响应里的 `songnum`（总集数）为终止条件，任一页拿不到内容即停止，
  /// 并保留已成功页的章节，避免整本退化为空。
  /// 首页就失败时返回空列表，由调用方回落 Edge。
  Future<List<Chapter>> _directChapters(SourceRule source, Book book) async {
    final out = <Chapter>[];
    final seen = <String>{};

    for (var pn = 0; pn < maxChapterPages; pn++) {
      final url =
          'http://search.kuwo.cn/r.s?stype=albuminfo&loginUid=0&loginSid=null&prod=kwplayer_ar_9.1.7.0&bkprod=kwbook_ar_9.1.7.0&source=kwplayer_ar_9.1.7.0_t18.apk&bksource=kwbook_ar_9.1.7.0_t18.apk&corp=kuwo&albumid=${book.detailUrl}&pn=$pn&rn=$chapterPageSize&show_copyright_off=1&vipver=MUSIC_8.2.0.0_BCS17&mobi=1&sortby=3&iskwbook=1';
      final response = await _get(url, source);
      if (response == null) {
        // 首页就挂：交给 Edge 兜底；中途挂：保留已取到的部分。
        return pn == 0 ? const [] : out;
      }

      final List<Chapter> page;
      try {
        page = parseChapterResponse(book, response, startIndex: out.length);
      } catch (e) {
        _logger.w('xiaoKu chapter parse failed', error: e);
        return pn == 0 ? const [] : out;
      }
      if (page.isEmpty) break;

      for (final c in page) {
        if (!seen.add(c.url)) continue; // 上游若重叠，按 musicrid 去重
        out.add(
          Chapter(
            chapterId: SourceUtils.chapterId(book.bookId, out.length),
            bookId: book.bookId,
            index: out.length,
            name: c.name,
            url: c.url,
            duration: c.duration,
          ),
        );
      }

      final total = parseChapterTotal(response);
      if (total == null || total <= 0) break; // 无总数信息 → 单页结果即全部
      if (out.length >= total) break;
      if (page.length < chapterPageSize) break; // 末页，无需再请求
    }
    return out;
  }

  /// 从直连 albuminfo 响应读取总集数 `songnum`（缺失/畸形返回 null）。
  int? parseChapterTotal(String response) {
    final json = SourceUtils.decodeLooseJsonObject(response);
    return SourceUtils.intValue(json ?? const {}, ['songnum', 'total']);
  }

  List<Chapter> parseChapterResponse(
    Book book,
    String response, {
    int startIndex = 0,
  }) {
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
      final index = startIndex + chapters.length;
      chapters.add(
        Chapter(
          chapterId: SourceUtils.chapterId(book.bookId, index),
          bookId: book.bookId,
          index: index,
          name: _clean(title),
          url: trackId,
          duration: SourceUtils.intValue(track, ['duration']),
        ),
      );
    }
    return chapters;
  }

  @override
  Future<String?> getAudioUrl(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  }) async {
    if (chapter.audioUrl?.isNotEmpty == true) return chapter.audioUrl;
    final url =
        'https://mobi.kuwo.cn/mobi.s?f=web&user=0&source=kwplayercar_ar_6.0.0.9_B_jiakong_vh.apk&type=convert_url_with_sign&rid=${Uri.encodeComponent(chapter.url)}&br=${_brForQuality(quality)}';
    final response = await _get(url, source);
    if (response == null) {
      _logger.w('xiaoKu getAudioUrl: 请求无响应 rid=${chapter.url}');
      return null;
    }
    if (response.contains('<html')) {
      _logger.w('xiaoKu getAudioUrl: 返回 HTML（被拦截）rid=${chapter.url}');
      return null;
    }

    try {
      final parsed = parseAudioResponse(response);
      if (parsed == null) {
        _logger.w('xiaoKu getAudioUrl: 解析失败 rid=${chapter.url}，响应前 200 字符: '
            '${response.length > 200 ? response.substring(0, 200) : response}');
      }
      return parsed;
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

  // ---------------------------------------------------------------- 字幕
  //
  // 契约来自聆阅字节码 #18025/#18026 `fetchKuwoLyric(rid, host)`：
  //   GET {edge}/kuwo-play?rid={rid}&host={host}
  //     headers: apikey / Authorization: Bearer <anonKey>
  //   → {url, lyric, quality}；lyric 为 LRC 文本（typeof==='string' 且 trim）。
  // 2026-10-14 模拟器抓包与 2026-10-16 复核均确认该形态。
  // 服务端有并发限流（429 projectConcurrencyLimitExceeded），重试 2 次。

  /// 聆阅 Edge 后端基址（与 lrts 适配器共用同一秒搭 Supabase 项目）。
  static const String edgeBase =
      'https://backend.appmiaoda.com/projects/supabase345057433544081408/functions/v1';

  /// Edge 匿名密钥（从 APK 提取，实测有效）。
  static const String edgeAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhw'
      'IjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9'
      '.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc';

  /// 429 重试次数（与 lrts 保持一致的克制值）。
  static const int lyricRetries = 2;

  /// 429 限流后的重试间隔（测试可注入 Duration.zero）。
  Duration lyricRetryDelay = const Duration(seconds: 8);

  @override
  Future<String?> getLyric(SourceRule source, Chapter chapter) async {
    final rid = chapter.url;
    if (rid.isEmpty) return null;

    for (var attempt = 0; attempt <= lyricRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(lyricRetryDelay);
      }
      final body = await _edgeGet('/kuwo-play?rid=${Uri.encodeComponent(rid)}&host=');
      if (body == null) return null; // 网络失败不重试（_edgeGet 已记日志）
      final lyric = parseLyricResponse(body);
      if (lyric != null) return lyric;
      // 限流则重试；其他有效响应（无 lyric 字段）如实返回 null
      if (!body.contains('projectConcurrencyLimitExceeded')) return null;
    }
    return null;
  }

  /// 解析 `kuwo-play` 响应中的字幕。独立方法便于用真实/合成报文单测。
  String? parseLyricResponse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final lyric = json['lyric'];
      if (lyric is! String) return null; // 字节码：typeof==='string'
      final t = lyric.trim();
      return t.isEmpty ? null : t;
    } catch (e) {
      _logger.w('xiaoKu lyric parse failed', error: e);
      return null;
    }
  }

  Future<String?> _edgeGet(String path, {bool retryOnLimit = false}) async {
    try {
      for (var attempt = 0;; attempt++) {
        final r = await _dio.get<String>(
          '$edgeBase$path',
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (c) => c != null && c < 600,
            headers: {
              'apikey': edgeAnonKey,
              'Authorization': 'Bearer $edgeAnonKey',
            },
          ),
        );
        final body = r.data;
        if (!retryOnLimit ||
            body == null ||
            !body.contains('projectConcurrencyLimitExceeded') ||
            attempt >= 2) {
          return body;
        }
        await Future<void>.delayed(lyricRetryDelay);
      }
    } catch (e) {
      _logger.w('xiaoKu edge request failed: $path', error: e);
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
      _logger.w('xiaoKu request failed: $url', error: e);
      return null;
    }
  }

  /// 清理酷我返回文本中的 HTML 标签与实体。
  ///
  /// 酷我报文常带 `&nbsp;`（如 `Right&nbsp;Here&nbsp;Waiting`）
  /// 与其他命名/数字实体，仅剥离标签是不够的。
  /// 实体解码在剥标签之后执行，避免 `&lt;b&gt;` 被当成真标签。
  /// 把音质偏好映射为酷我 `br` 参数。
  ///
  /// 酷我支持的常见取值：`128kmp3` / `192kmp3` / `320kmp3` / `2000kflac`。
  /// 未知或不支持时回退到 320kmp3（与历史行为一致）。
  String _brForQuality(AudioQuality? quality) {
    switch (quality) {
      case AudioQuality.low:
        return '128kmp3';
      case AudioQuality.standard:
        return '192kmp3';
      case AudioQuality.high:
        return '320kmp3';
      case AudioQuality.lossless:
        return '2000kflac';
      case null:
        return '320kmp3';
    }
  }

  String _clean(String value) => _decodeEntities(
        value.replaceAll(RegExp(r'<[^>]+>'), ''),
      ).trim();

  String? _cleanOptional(String? value) =>
      value == null ? null : _clean(value);

  /// 解码常见 HTML 实体（含数字实体）。
  String _decodeEntities(String input) {
    const named = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&#39;': "'",
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&hellip;': '…',
      '&mdash;': '—',
    };

    var out = input;
    named.forEach((entity, replacement) {
      out = out.replaceAll(entity, replacement);
    });

    // 数字实体：&#123; 与 &#x1F600;
    out = out.replaceAllMapped(
      RegExp(r'&#(x?[0-9a-fA-F]+);'),
      (m) {
        final raw = m.group(1)!;
        final code = raw.startsWith('x') || raw.startsWith('X')
            ? int.tryParse(raw.substring(1), radix: 16)
            : int.tryParse(raw);
        if (code == null || code <= 0 || code > 0x10FFFF) return m.group(0)!;
        try {
          return String.fromCharCode(code);
        } catch (_) {
          return m.group(0)!;
        }
      },
    );

    return out;
  }

  String? _trimNarrator(String? value) {
    if (value == null) return null;
    final clean = value.replaceAll('主播', '').replaceAll(r'\u0026', '&').trim();
    return clean.length > 8 ? clean.substring(0, 8) : clean;
  }
}
