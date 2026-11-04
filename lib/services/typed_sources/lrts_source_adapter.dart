import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import '../../theme/playback_settings.dart';
import '../chapter_order.dart';
import 'source_utils.dart';
import 'typed_source_adapter.dart';

/// 懒人听书（lrts）适配器。
///
/// 依据 2026-10-13 对 `m.lrts.me` 的**真实请求**逆向而来：
///
/// | 操作 | 端点 | 说明 |
/// |---|---|---|
/// | 书籍详情 | `GET /ajax/getBookInfo?id={bookId}` | 返回 60 字段 JSON |
/// | 章节列表 | `GET /ajax/getBookMenu?bookId={bookId}` | 返回 `list[]`，默认前 30 章 |
///
/// 真实响应的关键字段（已用 `test/fixtures/lrts_*_real.json` 固化）：
/// - 详情：`name` `announcer` `author` `cover`/`bestCover` `desc`
///   `sections`（总章数） `play`（播放量） `fatherTypeName` `labels[]`
///   `feeType` `payType` `cantListen` `cantDown`
/// - 章节：`id`/`sectionId`（音频 token） `section`（序号）
///   `name` `length`（秒） `feeType` `payType` `cantListen` `path`（常为空）
///
/// 已知限制：
/// - `path` 在真实响应中为空字符串，音频地址需另经服务端换取，
///   因此 [getAudioUrl] 默认返回 null（详见方法注释）。
/// - `getBookMenu` 单次只返回部分章节，需按 `sectionId` 翻页。
class LrtsSourceAdapter implements TypedSourceAdapter {
  /// `connectTimeout` 只能在 BaseOptions 上设（连接早于请求发生）。
  /// 不给默认值的话 Dio 永不超时，一次卡死的连接就能让整个目录挂住。
  ///
  /// [retryBaseDelay] / [interPageDelay] 仅为单测可注入的退避与节奏参数，
  /// 默认值就是线上值；不改的话，模拟"持续故障"的用例要真等几十秒。
  LrtsSourceAdapter({
    Dio? dio,
    Duration retryBaseDelay = const Duration(milliseconds: 400),
    Duration interPageDelay = _kInterPageDelayDefault,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
            )),
        _retryBaseDelay = retryBaseDelay,
        _interPageDelay = interPageDelay;

  final Dio _dio;

  /// 单次页内重试的退避基数。
  final Duration _retryBaseDelay;

  /// 页与页之间的礼貌间隔。
  final Duration _interPageDelay;
  final Logger _logger = Logger();

  /// 移动端 UA —— 真实请求验证过，桌面 UA 可能被拒。
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const String _base = 'https://m.lrts.me';

  /// tingshu8 解析代理（聆阅的兜底中转，字节码 #18064/#18078/#17910）。
  ///
  /// 无鉴权、无 Supabase 并发限流；2026-10-16 实测 `?id=` 可直出音频链接。
  /// `?name=`/`?albumId=` 形态已确认（`{code,success,data:{list}}`），
  /// 但当日实测返回空列表（代理侧搜索/目录通道不稳定），故仅作兜底不作主力。
  static const String _phpBase = 'http://www.tingshu8.top/yuan1/lrts.php';

  /// 聆阅的 Supabase Edge Functions（2026-10-14 模拟器抓包确认）。
  ///
  /// 搜索与音频地址都走这里；anon key 从 APK 提取并经实测有效。
  /// 服务端有并发限流（429 projectConcurrencyLimitExceeded），需重试。
  static const String _fnBase =
      'https://backend.appmiaoda.com/projects/supabase345057433544081408/functions/v1';

  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhw'
      'IjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9'
      '.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc';

  /// Edge Function 请求（带鉴权头）。
  Future<String?> _fnGet(String path) async {
    try {
      final r = await _dio.get<String>(
        '$_fnBase$path',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (c) => c != null && c < 600,
          headers: {
            'apikey': _anonKey,
            'Authorization': 'Bearer $_anonKey',
            'User-Agent': _userAgent,
          },
        ),
      );
      return r.data;
    } catch (e) {
      _logger.w('lrts fn request failed: $path', error: e);
      return null;
    }
  }

  @override
  String get sourceId => 'lrts';

  /// 搜索（经聆阅的 Edge Function 代理，实测可用）。
  ///
  /// 响应形态：`{books: [{id,title,author,narrator,cover,...}], total?}`。
  /// Edge 失败/为空时兜底 tingshu8 `lrts.php?name=`（字节码 #18064；
  /// 无 429 限流，但代理侧搜索结果不稳定——2026-10-16 实测可能为空列表）。
  ///
  /// Edge `lrts-search` 在服务端已损坏（实测返回
  /// `{"error":"html is not defined","books":[]}`），
  /// 但每次搜索仍会先打它两次再兜底 —— 白白多两趟往返。
  /// 记录「坏到什么时候」，期间直接走 PHP 兜底。
  static DateTime? _edgeSearchBrokenUntil;

  /// 供测试重置。
  @visibleForTesting
  static void resetEdgeSearchHealth() => _edgeSearchBrokenUntil = null;

  static bool get _edgeSearchBroken =>
      _edgeSearchBrokenUntil != null &&
      DateTime.now().isBefore(_edgeSearchBrokenUntil!);

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];

    if (_edgeSearchBroken) {
      _logger.d('lrts-search 已知不可用，直接走 PHP 兜底');
      return _searchViaPhp(source, kw);
    }

    // 聆阅同款分页（#18069：`lrts-search?name=&page=`）：取两页合并去重。
    final encoded = Uri.encodeComponent(kw);
    final seen = <String>{};
    final merged = <Book>[];
    for (var page = 1; page <= 2; page++) {
      final body = await _fnGet('/lrts-search?name=$encoded&page=$page');
      if (body == null) break;
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        // 服务端报错（html is not defined）→ 标记 10 分钟内不再尝试
        if (json['error'] != null) {
          _edgeSearchBrokenUntil = DateTime.now().add(const Duration(minutes: 10));
          _logger.w('lrts-search 服务端报错，改走 PHP 兜底: ${json['error']}');
          break;
        }
        final books = parseSearchResult(source, json);
        if (books.isEmpty) break;
        for (final b in books) {
          if (seen.add(b.bookId)) merged.add(b);
        }
      } catch (e) {
        _logger.w('lrts search parse failed (page $page)', error: e);
        break;
      }
    }
    if (merged.isNotEmpty) return merged;
    return _searchViaPhp(source, kw);
  }

  /// tingshu8 搜索兜底：`lrts.php?name=` → `{code, data:{list:[...]}}`。
  Future<List<Book>> _searchViaPhp(SourceRule source, String kw) async {
    try {
      final r = await _dio.get<String>(
        '$_phpBase?name=${Uri.encodeComponent(kw)}',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (c) => c != null && c < 500,
          headers: const {'User-Agent': _userAgent},
        ),
      );
      final body = r.data;
      if (body == null) return [];
      return parsePhpSearchResult(source, body);
    } catch (e) {
      _logger.d('lrts php search failed (fallback path)', error: e);
      return [];
    }
  }

  /// 解析 php 搜索响应。独立方法便于单测。
  ///
  /// list 项字段名未在真实报文里取到（当日实测均为空列表），
  /// 按 lrts 系响应惯用字段宽容取值（title/name、id、cover、author…）。
  List<Book> parsePhpSearchResult(SourceRule source, String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return const [];
      final data = json['data'];
      if (data is! Map) return const [];
      final list = data['list'];
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map)
            Book(
              bookId: '${source.sourceId}_${item['id']}',
              sourceId: source.sourceId,
              name: _str(item['title'] ?? item['name']) ?? '未知书名',
              author: _str(item['author']),
              narrator: _str(item['narrator'] ?? item['announcer']),
              coverUrl: _str(item['cover']),
              intro: _str(item['description'] ?? item['intro']),
              detailUrl: '${item['id']}',
              chapterCount: _int(item['chapters'] ?? item['songNum']),
            ),
      ];
    } catch (e) {
      _logger.w('lrts php search parse failed', error: e);
      return const [];
    }
  }

  /// 解析 `lrts-search` 响应。独立方法便于用真实 fixture 单测。
  List<Book> parseSearchResult(SourceRule source, Map<String, dynamic> json) {
    final books = json['books'];
    if (books is! List) return const [];
    return [
      for (final item in books)
        if (item is Map)
          Book(
            bookId: '${source.sourceId}_${item['id']}',
            sourceId: source.sourceId,
            name: _str(item['title']) ?? '未知书名',
            author: _str(item['author']),
            narrator: _str(item['narrator']),
            coverUrl: _str(item['cover']),
            intro: _str(item['description']),
            detailUrl: '${item['id']}',
            chapterCount: _int(item['chapters']),
          ),
    ];
  }

  /// 从公开榜单页解析书籍列表（无需登录）。
  ///
  /// `GET /rankList` 为 Nuxt SSR 页面，内嵌 97 本书的 `/book/{id}` 链接。
  /// 这是该源当前唯一可用的**内容发现**入口。
  Future<List<Book>> getRankList(SourceRule source) async {
    final html = await _get('/rankList', source);
    if (html == null) return [];
    try {
      return parseRankList(source, html);
    } catch (e) {
      _logger.w('lrts parseRankList failed', error: e);
      return [];
    }
  }

  /// 从榜单页 HTML 提取书籍 id 列表。
  ///
  /// 独立方法便于用真实页面 fixture 单测。
  /// 注意：榜单页只给 id，不含书名等元数据；
  /// 因此这里返回**占位 Book**（name 用 id），详情需再调 [getBookDetail]。
  List<Book> parseRankList(SourceRule source, String html) {
    final ids = RegExp(
      r'/book/(\d{5,})',
    ).allMatches(html).map((m) => m.group(1)!).toSet().toList();
    return [
      for (final id in ids)
        Book(
          bookId: '${source.sourceId}_$id',
          sourceId: source.sourceId,
          // 榜单页无书名，用 id 占位；进入详情后会补全
          name: id,
          detailUrl: id,
        ),
    ];
  }

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async {
    final bookId = book.detailUrl;
    if (bookId.trim().isEmpty) return null;

    _lastGetFailed = false;
    final response = await _getWithRetry(
      '/ajax/getBookInfo?id=$bookId',
      source,
      attempts: 2,
    );
    if (response == null) {
      // response == null 有两种含义：
      // 1. 网络/服务端故障（_lastGetFailed == true）→ 应提示"稍后重试"
      // 2. 上游返回了空 → 视为该书不存在
      return null;
    }

    try {
      final json = jsonDecode(response) as Map<String, dynamic>;
      // 注意：这里**不能** `?? book` 回退。
      // 旧实现回退成占位 book（name = id），详情页于是把占位名当成书名，
      // 用户看到的就是永远停在「加载书籍信息…」—— 正是本次反馈的现象。
      // 解析不出来就如实返回 null，让 UI 报「书源暂时不可用」。
      return parseBookInfo(source, bookId, json);
    } catch (e) {
      _logger.w('lrts getBookDetail parse failed', error: e);
      return null;
    }
  }

  /// 从 `getBookInfo` 响应构造 [Book]。
  ///
  /// 独立方法便于用真实 fixture 单测。
  Book? parseBookInfo(
    SourceRule source,
    String bookId,
    Map<String, dynamic> json,
  ) {
    // apiStatus != 0 表示接口层错误（如资源已下线）
    if (json['apiStatus'] != null && json['apiStatus'] != 0) {
      _logger.d('lrts apiStatus=${json['apiStatus']} msg=${json['msg']}');
      return null;
    }

    final name = _str(json['name']);
    if (name == null || name.isEmpty) return null;

    return Book(
      bookId: '${source.sourceId}_$bookId',
      sourceId: source.sourceId,
      name: name,
      author: _str(json['author']),
      narrator: _str(json['announcer']),
      coverUrl: _str(json['bestCover']) ?? _str(json['cover']),
      intro: _str(json['desc']),
      detailUrl: bookId,
      chapterCount: _int(json['sections']),
    );
  }

  /// 上一次 [getChapterList] 是否可能不完整（页数不够 / 中途失败）。
  ///
  /// 供 UI 决定是否提示「目录可能不全，下拉刷新重试」。
  bool get lastFetchWasPartial => _lastFetchWasPartial;
  bool _lastFetchWasPartial = false;

  /// 拉单页章节，失败重试（Edge 429 / 网络抖动）。
  ///
  /// 大目录要连拉近百页，中间任何一页失败都会让目录缺一段；
  /// 重试 + 指数退避能显著降低这种概率。
  Future<Map<String, dynamic>?> _getMenuPageWithRetry({
    required String bookId,
    required int page,
    required int pageSize,
    required SourceRule source,
    int attempts = 3,
    Duration? baseDelay,
  }) async {
    for (var i = 0; i < attempts; i++) {
      final response = await _get(
        '/ajax/getBookMenu?bookId=$bookId&pageNum=$page&pageSize=$pageSize&sortType=0',
        source,
      );
      if (response != null) {
        try {
          final decoded = jsonDecode(response);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (e) {
          _logger.w('lrts 第 $page 页解析失败（第 ${i + 1} 次）', error: e);
        }
      } else if (!_lastFailureRetryable) {
        // 404 之类不是暂时性故障，重试没有意义，直接放弃这一页
        _logger.w('lrts 第 $page 页非暂时性失败，不再重试');
        return null;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(
          (baseDelay ?? _retryBaseDelay) * (1 << i),
        );
      }
    }
    return null;
  }

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async {
    final bookId = book.detailUrl;
    if (bookId.trim().isEmpty) return [];

    // 真实抓包确认的分页参数：pageNum/pageSize/sortType（聆阅实际请求形态）。
    //
    // ⚠️ 失败页**绝不能中断后面的翻页**。
    // 旧实现在第 N 页失败时 `break`，于是后面几百章全丢，
    // 用户看到的就是「目录不全」，而且没有任何提示。
    // 之所以敢跳过单页继续往后翻：每章响应里都带 `section`
    // （该书内的绝对序号，见 parseChapterResponse），
    // 所以缺页不会让后续章节错位，补拉时按 index 去重即可。
    const pageSize = 60;
    final byIndex = <int, Chapter>{};
    final failedPages = <int>[];
    var sections = 0;
    var consecutiveFailures = 0;
    var reachedEnd = false;

    for (var page = 1; page <= _maxMenuPages; page++) {
      final json = await _getMenuPageWithRetry(
        bookId: bookId,
        page: page,
        pageSize: pageSize,
        source: source,
      );
      if (json == null) {
        failedPages.add(page);
        consecutiveFailures++;
        // 熔断：连续多页失败说明服务整体不可用，
        // 继续往后翻只是白等（97 页 × 重试会拖几分钟）。
        if (consecutiveFailures >= _abortAfterConsecutiveFailures) {
          _logger.w('lrts 连续 $consecutiveFailures 页失败，中止翻页'
              '（已取 ${byIndex.length} 章）');
          break;
        }
        continue;
      }
      consecutiveFailures = 0;

      // ⚠️ 必须区分「真的翻到头」与「报文异常」：
      // 429 限流 / 5xx 的错误体里**没有 list 字段**（形如
      // {"requestId":…,"code":"projectConcurrencyLimitExceeded",…}），
      // 旧实现把它当成"空列表 = 翻到头"直接 break，
      // 于是目录静默缺掉后半段、且不报「不全」——
      // 这正是用户反复看到「目录加载不全」的机制。
      if (!_hasListField(json)) {
        _logger.w('lrts 第 $page 页报文无 list 字段（异常响应），记为失败页');
        failedPages.add(page);
        consecutiveFailures++;
        if (consecutiveFailures >= _abortAfterConsecutiveFailures) {
          _logger.w('lrts 连续 $consecutiveFailures 页异常，中止翻页');
          break;
        }
        continue;
      }
      final chapters = parseChapterResponse(book, json);
      if (chapters.isEmpty) {
        reachedEnd = true; // list 存在但为空 = 真的翻到头了
        break;
      }
      for (final c in chapters) {
        byIndex[c.index] = c;
      }
      final s = json['sections'];
      if (s is int && s > 0) sections = s;
      if (sections > 0 && byIndex.length >= sections) {
        // 取满上游声明的总数 = 完整，不是"不全"
        reachedEnd = true;
        break;
      }
      await Future<void>.delayed(_interPageDelay);
    }

    // 补拉失败页：退避更长（限流往往需要时间恢复），但仍设上限防卡死。
    for (final page in failedPages) {
      final json = await _getMenuPageWithRetry(
        bookId: bookId,
        page: page,
        pageSize: pageSize,
        source: source,
        attempts: 2,
        baseDelay: _retryBaseDelay * 4,
      );
      if (json == null || !_hasListField(json)) continue;
      for (final c in parseChapterResponse(book, json)) {
        byIndex[c.index] = c;
      }
      final s = json['sections'];
      if (s is int && s > 0) sections = s;
      await Future<void>.delayed(_interPageDelay);
    }

    final sorted = byIndex.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    // 重新按连续位置编号（缺页时 index 会有空洞，播放器按下标取章需要连续）
    final dense = <Chapter>[];
    for (var i = 0; i < sorted.length; i++) {
      dense.add(sorted[i].copyWith(index: i));
    }

    _lastFetchWasPartial =
        !reachedEnd || (sections > 0 && dense.length < sections);
    if (_lastFetchWasPartial) {
      _logger.w('lrts 目录可能不全：取到 ${dense.length} 章'
          '${sections > 0 ? '，声明 $sections 章' : ''}（失败页 ${failedPages.length} 个）');
    }
    return _normalizeOrder(dense);
  }

  /// 响应体是否含 `list` 字段。
  ///
  /// 上游正常返回**一定有 list**（哪怕空数组）；
  /// 没有 list 就说明这不是章节报文（限流/网关错误/未部署的函数）。
  static bool _hasListField(Map<String, dynamic> json) => json.containsKey('list');

  /// 连续失败多少页后中止翻页（服务整体不可用时不白等）。
  ///
  /// 4 太激进：手机网络连续抖 4 次很常见，会把"暂时不行"误判成"这书就这样"。
  static const int _abortAfterConsecutiveFailures = 10;

  static const Duration _kInterPageDelayDefault = Duration(milliseconds: 200);

  /// 章节顺序兜底（聆阅 #17865 `ensureChaptersAscending`）：
  /// 上游若明显倒序（≥70% 相邻集号递减）则整表翻转并重建索引。
  List<Chapter> _normalizeOrder(List<Chapter> chapters) {
    if (chapters.length <= 1) return chapters;
    if (!looksReversed(chapters, (c) => c.name)) return chapters;
    _logger.i('lrts 章节疑似倒序，已按聆阅 #17865 规则翻转（${chapters.length} 章）');
    return [
      for (var i = 0; i < chapters.length; i++)
        chapters[chapters.length - 1 - i].copyWith(
          index: i,
          chapterId: SourceUtils.chapterId(
            chapters[chapters.length - 1 - i].bookId,
            i,
          ),
        ),
    ];
  }

  /// 翻页上限（防死循环；4610 章 ≈ 77 页，取 120 留裕量）。
  static const int _maxMenuPages = 120;

  /// 从 `getBookMenu` 响应解析章节列表。
  ///
  /// 独立方法便于用真实 fixture 单测。
  List<Chapter> parseChapterResponse(Book book, Map<String, dynamic> json) {
    // 防御：list 可能缺失或不是数组（上游异常报文）
    final rawList = json['list'];
    final list = rawList is List ? rawList : const <dynamic>[];
    final chapters = <Chapter>[];

    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;

      // 优先用 section 序号（真实响应为 '1'、'2'…），退化到数组下标
      final sectionIndex = _int(item['section']) ?? (i + 1);
      // 章节 token：真实响应中 id 与 sectionId 相同，形如 '1581422800010001'
      final token = _str(item['id']) ?? _str(item['sectionId']);
      if (token == null || token.isEmpty) continue;

      final name = _str(item['name']) ?? '第$sectionIndex集';

      // feeType/payType 非 0 视为付费；cantListen 为 1 视为不可听
      final feeType = _int(item['feeType']) ?? 0;
      final payType = _int(item['payType']) ?? 0;
      final cantListen = _int(item['cantListen']) ?? 0;
      final isVip = feeType != 0 || payType != 0 || cantListen == 1;

      // 真实响应中 path 常为空；非空时可直接当作音频地址
      final path = _str(item['path']);
      final audioUrl = (path != null && path.isNotEmpty) ? path : null;

      chapters.add(
        Chapter(
          chapterId: token,
          bookId: book.bookId,
          index: sectionIndex - 1, // 对外索引从 0 开始
          // 保留上游绝对序号：目录缓存靠它跨会话补齐缺页而不错位
          sectionIndex: sectionIndex,
          name: name,
          // url 承载章节 token，供后续换取音频地址
          url: token,
          audioUrl: audioUrl,
          duration: _int(item['length']),
          isVip: isVip,
        ),
      );
    }

    return chapters;
  }

  /// 上游无字幕接口（字节码确认 lrts/六翼/喜马拉雅等播放响应不含 lyric）。
  @override
  Future<String?> getLyric(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  }) async => null;

  @override
  Future<String?> getAudioUrl(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  }) async {
    // 若章节列表已带直链，直接使用。
    if (chapter.audioUrl != null && chapter.audioUrl!.isNotEmpty) {
      return chapter.audioUrl;
    }

    // 章节 token 形态：`书id*集号`（如 94326793*1，抓包+存储层双重确认）。
    // 经聆阅 Edge Function 换取：响应 {code:200, data:{url, albumId, section}}。
    final token = chapter.url;
    if (token.isEmpty) return null;

    final sectionNo = (chapter.index + 1).toString();
    final bid = bookIdOf(chapter);
    final candidates = <String>[
      token.contains('*') ? token : '$token*$sectionNo',
      '$bid*$sectionNo',
    ];

    for (final id in candidates) {
      final url = await _fetchPlayUrl(id);
      if (url != null) return url;
    }
    _logger.w('lrts: 章节 $token 无法取得音频地址');
    return null;
  }

  /// 从 chapter.bookId（形如 `lrts_94326793`）反推书 id。
  String bookIdOf(Chapter chapter) {
    final bid = chapter.bookId;
    final i = bid.indexOf('_');
    return i >= 0 ? bid.substring(i + 1) : bid;
  }

  /// 解析音频 URL：按聆阅字节码 #18078 的顺序——
  /// 1. 先走 tingshu8 解析代理 `lrts.php?id={token}`（无 key、无 429，实测直出 m4a 直链）；
  /// 2. 失败再走 Edge `lrts-play`（并发限流时重试）。
  Future<String?> _fetchPlayUrl(String id) async {
    final php = await _fetchPlayUrlFromPhp(id);
    if (php != null) return php;

    for (var attempt = 0; attempt <= maxPlayRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 10));
      }
      final body = await _fnGet('/lrts-play?id=${Uri.encodeComponent(id)}');
      if (body == null) continue;

      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (json['code'] == 'projectConcurrencyLimitExceeded') {
          _logger.d('lrts-play 限流，重试 $attempt/$maxPlayRetries');
          continue;
        }
        final data = json['data'];
        if (json['code'] == 200 && data is Map) {
          final url = _str(data['url']);
          if (url != null) return url;
        }
        if (json['code'] == 400) return null; // token 无效
      } catch (e) {
        _logger.w('lrts-play parse failed', error: e);
      }
    }
    return null;
  }

  /// tingshu8 兜底代理（字节码 #18078）。
  ///
  /// `GET http://www.tingshu8.top/yuan1/lrts.php?id={token}` →
  /// `{code:200, success:true, data:{url}}`。
  /// 2026-10-16 实测：token `94326793*1` 返回真实 tencentmusic m4a 直链。
  Future<String?> _fetchPlayUrlFromPhp(String id) async {
    try {
      final r = await _dio.get<String>(
        '$_phpBase?id=${Uri.encodeComponent(id)}',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (c) => c != null && c < 500,
          headers: const {'User-Agent': _userAgent},
        ),
      );
      final body = r.data;
      if (body == null) return null;
      return parsePhpPlayResponse(body);
    } catch (e) {
      _logger.d('lrts php play failed (fallback path)', error: e);
      return null;
    }
  }

  /// 解析 php 播放响应。独立方法便于单测。
  String? parsePhpPlayResponse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final data = json['data'];
      if (data is! Map) return null;
      final url = _str(data['url']);
      // 字节码：String(url).trim() 且以 http 开头才算有效
      if (url == null || !url.startsWith('http')) return null;
      return url;
    } catch (e) {
      return null;
    }
  }

  /// lrts-play 的 429 重试次数。
  static const int maxPlayRetries = 3;

  // ------------------------------------------------------------------ 内部

  /// 单次请求（**不做重试**）。
  ///
  /// ⚠️ 重试刻意不放在这里：分页拉目录本身已有 `_getMenuPageWithRetry`
  /// （3 次 + 退避）。两处都重试会变成 3×3 = 9 次/页，
  /// 一本 5795 集的书有 97 页 → 最坏 873 次请求、纯退避等待数分钟，
  /// 结果反而是**目录拉不完 / 整体超时**，把容错做成了故障放大器。
  ///
  /// 所以：这里只发一次，失败如实返回；重试由调用方按语义决定。
  Future<String?> _get(String path, SourceRule source) async {
    _lastGetStatus = 0;
    try {
      final response = await _dio.get<String>(
        '$_base$path',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (code) => code != null,
          // 必须显式设超时：Dio 默认**没有**超时，卡住的连接会一直挂着，
          // 既拖慢整个目录加载，也让失败原因不可判定。
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': _userAgent,
            'Referer': '$_base/',
            ...?source.header,
          },
        ),
      );
      final code = response.statusCode ?? 0;
      _lastGetStatus = code;
      if (code == 200) return response.data;
      _logger.w('lrts 请求失败 ($code): $path');
      return null;
    } catch (e) {
      _logger.w('lrts request failed: $path', error: e);
      return null;
    }
  }

  /// 上一次 [_get] 的 HTTP 状态码（0 = 网络异常/未知）。
  int _lastGetStatus = 0;

  /// 上一次详情请求是否因服务端故障失败。
  bool _lastGetFailed = false;

  /// 上一次失败是否属于「值得重试」的暂时性故障（429 限流 / 5xx）。
  /// 是否属于「重试有可能成功」的失败。
  ///
  /// ⚠️ 必须包含 `_lastGetStatus == 0`（socket 异常 / 超时 / DNS 抖动）：
  /// 手机网络下这类瞬时故障最常见。旧实现只认 429/5xx，
  /// 于是**一次网络抖动就把该页记为永久失败**，连续几页就触发熔断，
  /// 结果停在整 300 集（= 5 页成功 + 4 页抖动 + 熔断）——
  /// 这正是用户截图里「已加载 300 集，共 923 集」的成因。
  bool get _lastFailureRetryable =>
      _lastGetStatus == 0 || _lastGetStatus == 429 || _lastGetStatus >= 500;

  /// 上一次详情请求是否因服务端故障失败（供 UI 区分"故障"与"书不存在"）。
  bool get lastFetchFailed => _lastGetFailed;

  /// 带重试的 [_get]，**仅用于单次调用**（详情等）。
  ///
  /// 分页场景请用 `_getMenuPageWithRetry`，不要叠加 —— 见 [_get] 的说明。
  Future<String?> _getWithRetry(
    String path,
    SourceRule source, {
    int attempts = 2,
  }) async {
    for (var i = 0; i < attempts; i++) {
      final r = await _get(path, source);
      if (r != null) return r;
      // 只有暂时性故障才重试；4xx（如 404）立即返回
      if (!_lastFailureRetryable) break;
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (1 << i)));
      }
    }
    _lastGetFailed = true;
    return null;
  }

  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString().trim());
  }
}
