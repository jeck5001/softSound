import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/play_history_repository.dart';
import '../../services/chapter_catalog_service.dart';
import '../../services/source_parser.dart';
import '../../services/player_service.dart';
import '../../services/audio_downloader.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_strings.dart';
import '../../services/chapter_segments.dart';
import '../../theme/app_widgets.dart';
import '../../theme/brand_widgets.dart';
import '../source_manager/source_manager_page.dart';
import '../bookshelf/bookshelf_page.dart';
import '../downloads/downloads_notifier.dart';

/// 书籍详情状态
class BookDetailState {
  final Book? book;
  final SourceRule? source;
  final List<Chapter> chapters;
  final bool isLoading;
  final bool isInBookshelf;
  final int? savedChapterIndex;
  final int? savedPosition;
  final String? error;

  const BookDetailState({
    this.book,
    this.source,
    this.chapters = const [],
    this.isLoading = false,
    this.isInBookshelf = false,
    this.savedChapterIndex,
    this.savedPosition,
    this.error,
  });

  BookDetailState copyWith({
    Book? book,
    SourceRule? source,
    List<Chapter>? chapters,
    bool? isLoading,
    bool? isInBookshelf,
    int? savedChapterIndex,
    int? savedPosition,
    String? error,
  }) {
    return BookDetailState(
      book: book ?? this.book,
      source: source ?? this.source,
      chapters: chapters ?? this.chapters,
      isLoading: isLoading ?? this.isLoading,
      isInBookshelf: isInBookshelf ?? this.isInBookshelf,
      savedChapterIndex: savedChapterIndex ?? this.savedChapterIndex,
      savedPosition: savedPosition ?? this.savedPosition,
      error: error,
    );
  }
}

/// 书籍详情状态管理
class BookDetailNotifier extends StateNotifier<BookDetailState> {
  final SourceParser _parser = SourceParser();
  final BookRepository _bookRepo;
  final PlayHistoryRepository _historyRepo;

  /// 目录服务（带缓存合并）。未注入时退化为直接问网络。
  ChapterCatalogService? _catalog;

  bool _isCancelled = false;

  BookDetailNotifier(this._bookRepo, this._historyRepo)
      : super(const BookDetailState());

  /// 名字可信度：占位/纯数字 id 最低，空串更低。
  /// 用于「详情结果不许把好名字换成占位名」的比较。
  static int _nameQuality(String name) {
    final t = name.trim();
    if (t.isEmpty) return 0;
    if (PlayerNotifier.isPlaceholderBook(Book(
          bookId: '',
          sourceId: '',
          name: t,
          detailUrl: '',
        ))) {
      return 1;
    }
    if (int.tryParse(t) != null) return 1;
    return 2;
  }

  /// 注入目录服务（含跨会话缓存）。
  void attachCatalog(ChapterCatalogService service) => _catalog = service;

  /// 重新拉取详情与章节（用户下拉刷新 / 想知道有没有更新时）。
  Future<void> reload() async {
    final book = state.book;
    final source = state.source;
    if (book == null || source == null) return;
    await loadBook(book, source);
  }

  Future<void> loadBook(Book book, SourceRule source) async {
    _isCancelled = false;
    state = BookDetailState(book: book, source: source, isLoading: true);

    try {
      final isInBookshelf = await _bookRepo.isInBookshelf(book.bookId);
      final progress = await _historyRepo.getProgress(book.bookId);
      if (_isCancelled || !mounted) return;

      final fetchedDetail = await _parser.getBookDetail(source, book);
      if (_isCancelled || !mounted) return;

      // 详情拉失败时，别让标题停在占位串上（「加载书籍信息…」或纯数字 id）。
      // 注意：占位形态有**两种来源** ——
      //   · 榜单/分类页跳转 → name 是纯数字 id
      //   · 书架/搜索/历史跳转（路由只带 bookId）→ name 是
      //     AppStrings.loadingBookInfo
      // 旧判定只看纯数字，于是路由进来那条路径会**静默卡在占位串**上。
      final startsAsPlaceholder = PlayerNotifier.isPlaceholderBook(book) ||
          int.tryParse(book.name.trim()) != null;

      // 兜底：详情失败但本地库里存过这本书 → 用库里的真名/封面/集数，
      // 而不是把占位串显示给用户。
      Book? detailBook = fetchedDetail;
      if (detailBook == null && startsAsPlaceholder) {
        final stored = await _bookRepo.getBookById(book.bookId);
        if (stored != null && !PlayerNotifier.isPlaceholderBook(stored)) {
          detailBook = book.copyWith(
            name: stored.name,
            author: stored.author,
            narrator: stored.narrator,
            intro: stored.intro,
            coverUrl: stored.coverUrl?.isNotEmpty ?? false
                ? stored.coverUrl
                : book.coverUrl,
            chapterCount: stored.chapterCount,
            latestChapter: stored.latestChapter,
          );
        }
      }
      // 详情结果不许把好名字换成占位名。
      // 酷我的 `getBookDetail` 是 `=> book` 原样返回，返回的对象可能
      // 就是个 name 为占位串的 Book；若直接采用，会把路由带进来的
      // 真名（搜索/书架/首页都有）覆盖回「加载书籍信息…」。
      if (detailBook != null &&
          detailBook.bookId == book.bookId &&
          _nameQuality(detailBook.name) < _nameQuality(book.name)) {
        detailBook = detailBook.copyWith(
          name: book.name,
          author: book.author,
          narrator: book.narrator,
          coverUrl: (book.coverUrl?.isNotEmpty ?? false)
              ? book.coverUrl
              : detailBook.coverUrl,
          intro: (book.intro?.isNotEmpty ?? false) ? book.intro : detailBook.intro,
        );
      }
      final detailFailed = detailBook == null && startsAsPlaceholder;

      // 目录走「网络 + 缓存合并」：本次失败的页由历史缓存补上。
      final expected = (detailBook ?? book).chapterCount ?? 0;
      final chapters = _catalog != null
          ? await _catalog!
              .loadChapters(source, detailBook ?? book, expectedTotal: expected)
          : await _parser.getChapterList(source, book);
      if (_isCancelled || !mounted) return;

      state = state.copyWith(
        book: detailBook ?? book,
        chapters: chapters,
        isLoading: false,
        isInBookshelf: isInBookshelf,
        savedChapterIndex: progress?.chapterIndex,
        savedPosition: progress?.position,
        // 优先报"服务不可用"，因为那才是用户能行动的原因；
        // 只有请求成功但没有章节时才说"未找到章节"。
        error: detailFailed
            ? AppStrings.sourceUnavailable
            : (chapters.isEmpty ? AppStrings.chapterNotFound : null),
      );
    } catch (e) {
      if (_isCancelled || !mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: '${AppStrings.loadFailedPrefix}$e',
      );
    }
  }

  Future<void> toggleBookshelf() async {
    if (state.book == null) return;
    
    if (state.isInBookshelf) {
      await _bookRepo.removeFromBookshelf(state.book!.bookId);
      state = state.copyWith(isInBookshelf: false);
    } else {
      await _bookRepo.addToBookshelf(state.book!);
      state = state.copyWith(isInBookshelf: true);
    }
  }

  void cancel() {
    _isCancelled = true;
  }

  void clear() {
    _isCancelled = true;
    state = const BookDetailState();
  }

  @override
  void dispose() {
    _isCancelled = true;
    super.dispose();
  }
}

/// 书籍详情 Provider
final bookDetailProvider =
    StateNotifierProvider<BookDetailNotifier, BookDetailState>((ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final historyRepo = ref.watch(playHistoryRepositoryProvider);
  final notifier = BookDetailNotifier(bookRepo, historyRepo);
  // 目录走带缓存的合并加载（大目录分页拉不全时可靠历史缓存补齐）
  notifier.attachCatalog(ref.watch(chapterCatalogProvider));
  return notifier;
});

/// 书籍详情页面
class BookDetailPage extends ConsumerStatefulWidget {
  final String bookId;

  /// 跳转方已知的书名（轮播/榜单卡自带标题，避免详情加载前显示占位名）。
  final String? initialName;

  /// 列表页透传的封面（榜单/分类/首页自带真实 cover）。
  ///
  /// 详情接口返回前先用它，避免「从榜单点进去没有封面图」。
  final String? initialCover;

  const BookDetailPage({
    super.key,
    required this.bookId,
    this.initialName,
    this.initialCover,
  });

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  @override
  void initState() {
    super.initState();
    // 首帧后再加载：loadBook 同步更新 state，
    // 在 initState 里直接调用会抛 "setState during build"。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadBookFromSearch();
    });
  }

  /// 按 bookId 前缀找到对应书源并加载详情。
  ///
  /// bookId 形如 `kuwo_16150041` / `lrts_94326793`，
  /// 前缀即 sourceId；再构造一个最小 Book 触发完整的
  /// getBookDetail → getChapterList 流程。
  Future<void> _loadBookFromSearch() async {
    // 书源是异步从 assets 加载的；进入详情页时可能还是空列表。
    // 轮询等待最多 3 秒。
    var sources = ref.read(sourcesProvider);
    for (var i = 0; i < 12 && sources.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      sources = ref.read(sourcesProvider);
    }
    if (sources.isEmpty) return; // 书源彻底没加载出来，维持 not-found

    for (final source in sources) {
      final bookIdPrefix = '${source.sourceId}_';
      if (!widget.bookId.startsWith(bookIdPrefix)) continue;

      final upstreamId = widget.bookId.substring(bookIdPrefix.length);
      final book = Book(
        bookId: widget.bookId,
        sourceId: source.sourceId,
        name: (widget.initialName?.isNotEmpty ?? false)
            ? widget.initialName!
            : AppStrings.loadingBookInfo,
        // 列表页透传的封面：详情接口回来之前先显示，避免空白封面
        coverUrl: (widget.initialCover?.isNotEmpty ?? false)
            ? widget.initialCover
            : null,
        // 分类页/搜索页跳转时只有 id；详情由 getBookDetail 补全
        detailUrl: upstreamId,
      );
      ref.read(bookDetailProvider.notifier).loadBook(book, source);
      return;
    }

    // 没有匹配的书源：书源列表为空（未加载完）或 id 前缀不认识 → 显示 not-found
    if (sources.isEmpty) return;
    final fallbackSource = sources.firstWhere(
      (s) => s.enabled,
      orElse: () => sources.first,
    );
    final slash = widget.bookId.indexOf('_');
    final fallback = Book(
      bookId: widget.bookId,
      sourceId: fallbackSource.sourceId,
      name: AppStrings.loadingBookInfo,
      detailUrl: slash >= 0
          ? widget.bookId.substring(slash + 1)
          : widget.bookId,
    );
    ref.read(bookDetailProvider.notifier).loadBook(fallback, fallbackSource);
  }

  int _tab = 1; // 0 简介 / 1 目录（聆阅默认落在目录）
  bool _asc = true;
  int _rangePage = 0;

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(bookDetailProvider);

    return Scaffold(
      body: SafeArea(
        child: detailState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : detailState.book == null
                ? _buildNotFound()
                : _buildContent(detailState),
      ),
    );
  }

  Widget _buildNotFound() {
    return AppEmptyState(
      icon: Icons.book_outlined,
      title: AppStrings.bookNotExist,
      description: AppStrings.offlineHint1,
      actionLabel: AppStrings.backHome,
      onAction: () => context.go('/home'),
    );
  }

  /// 聆阅详情页版式：渐变头 + 描边封面 + 立即播放 + meta chips + 简介/目录分段。
  Widget _buildContent(BookDetailState d) {
    final c = context.appColors;
    final book = d.book!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 章节区间（聆阅 100 集一页）——与播放页目录共用同一套规则
    final total = d.chapters.length;
    // 上游声明的总集数：判断「目录不全」的唯一依据
    final expected = book.chapterCount ?? 0;
    final ranges = ChapterSegments.ranges(total);
    if (_rangePage >= ranges.length) _rangePage = 0;
    var visible = ranges.isEmpty
        ? <Chapter>[]
        : d.chapters.sublist(ranges[_rangePage].$1, ranges[_rangePage].$2);
    if (!_asc) visible = visible.reversed.toList();

    // 下拉刷新：上游更新章节后，用户不必退出重进就能拿到新目录。
    return RefreshIndicator(
      onRefresh: () => ref.read(bookDetailProvider.notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
        // 渐变头部区
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF7C3AED).withValues(alpha: 0.28),
                      c.background,
                    ]
                  : [
                      const Color(0xFFE4DAFA),
                      c.background,
                    ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LyIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop()),
                  const Spacer(),
                  if (total > 0)
                    LyIconButton(
                      icon: Icons.download_outlined,
                      onTap: () => _showDownloadSheet(book, d),
                    ),
                  const SizedBox(width: 10),
                  LyIconButton(
                    icon: d.isInBookshelf
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    bg: d.isInBookshelf
                        ? const Color(0xFFE11D48)
                        : const Color(0xFFFDF2F4),
                    fg: d.isInBookshelf
                        ? Colors.white
                        : const Color(0xFFE11D48),
                    onTap: () {
                      ref
                          .read(bookDetailProvider.notifier)
                          .toggleBookshelf();
                      ref.invalidate(bookshelfProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LyCover(
                    url: book.coverUrl ?? '',
                    width: 128,
                    height: 172,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LyDarkChip(
                          book.sourceId == 'lrts'
                              ? '懒人'
                              : (book.sourceId == 'xiaoKu' ? '酷我' : '有声'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          book.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.foreground,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (book.author?.isNotEmpty ?? false)
                          Text(
                            book.author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.mutedForeground, fontSize: 14),
                          ),
                        if (book.narrator?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${book.narrator} 演播',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.mutedForeground, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // 立即播放 + 收藏
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: total == 0
                          ? null
                          : () => _startPlaying(
                              d.savedChapterIndex ?? 0,
                              d.savedPosition),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: lyHardShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 26),
                            const SizedBox(width: 6),
                            Text(
                              d.savedChapterIndex != null
                                  ? '继续播放'
                                  : '立即播放',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // meta chips（聆阅：时长 / 集数 / 分类）
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_totalDurationLabel(total > 0 ? d.chapters : const [])
                      .isNotEmpty)
                    LyMetaChip(
                      _totalDurationLabel(d.chapters),
                      color: const Color(0xFF0D9488),
                      icon: Icons.schedule_rounded,
                    ),
                  LyMetaChip(
                    '$total 集',
                    color: const Color(0xFF7C3AED),
                  ),
                  LyMetaChip(
                    book.sourceId == 'lrts'
                        ? '懒人听书'
                        : (book.sourceId == 'xiaoKu' ? '酷我听书' : '有声书'),
                    color: const Color(0xFFEA580C),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 简介 / 目录 分段
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: LySegment(
            labels: const ['简介', '目录'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),

        if (_tab == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LyBrutalCard(
              child: Text(
                book.intro?.isNotEmpty ?? false
                    ? book.intro!
                    : AppStrings.noIntro,
                style: TextStyle(
                    color: c.mutedForeground, fontSize: 14, height: 1.6),
              ),
            ),
          )
        else ...[
          // 目录不全告警：与 Book.chapterCount（上游声明总数）比对。
          // 之前 `state.error` 被赋值却从未渲染，所以详情页对
          // 「拉不全 / 服务不可用」完全静默 —— 用户只能干等。
          if (total == 0 && d.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LyBrutalCard(
                child: Text(
                  d.error!,
                  style: TextStyle(
                    color: const Color(0xFFB45309),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else if (expected > 0 && total > 0 && total < expected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LyBrutalCard(
                child: Text(
                  '目录可能不全：已加载 $total 集，共 $expected 集。'
                  '下拉刷新可继续补齐（已拉到的部分会保留）。',
                  style: TextStyle(
                    color: const Color(0xFFB45309),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          // 区间 chips + 排序
          if (total > 100 || total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var r = 0; r < ranges.length; r++)
                    GestureDetector(
                      onTap: () => setState(() => _rangePage = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: r == _rangePage
                              ? const Color(0xFF7C3AED)
                              : c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: r == _rangePage
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFDDD6FE),
                          ),
                          boxShadow:
                              r == _rangePage ? lyHardShadowSm : null,
                        ),
                        child: Text(
                          ChapterSegments.label(ranges[r]),
                          style: TextStyle(
                            color: r == _rangePage
                                ? Colors.white
                                : c.foreground,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => setState(() => _asc = !_asc),
                    child: LyMetaChip(
                      _asc ? '正序' : '倒序',
                      color: c.mutedForeground,
                      icon: Icons.swap_vert_rounded,
                    ),
                  ),
                ],
              ),
            ),

          if (total == 0)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  d.error ?? '暂无章节',
                  style: TextStyle(color: c.mutedForeground),
                ),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++)
              _chapterRow(d, visible[i], _asc
                  ? ranges[_rangePage].$1 + i
                  : ranges[_rangePage].$2 - 1 - i),
        ],
        ],
      ),
    );
  }

  /// 章节行（聆阅：白卡 + 序号紫块 + 时长）。
  Widget _chapterRow(BookDetailState d, Chapter chapter, int realIndex) {
    final c = context.appColors;
    final saved = d.savedChapterIndex == realIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => _startPlaying(realIndex, null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: saved ? const Color(0xFF7C3AED) : c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${realIndex + 1}',
                  style: const TextStyle(
                    color: Color(0xFF6D28D9),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  chapter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.foreground, fontSize: 14),
                ),
              ),
              if (chapter.isVip)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.lock_outline,
                      size: 16, color: Color(0xFFEA580C)),
                ),
              Text(
                _fmtDur(chapter.duration),
                style: TextStyle(color: c.mutedForeground, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDur(int? s) {
    if (s == null || s <= 0) return '';
    final m = s ~/ 60, ss = s % 60;
    return '$m:${ss.toString().padLeft(2, '0')}';
  }

  static String _totalDurationLabel(List<Chapter> chs) {
    final s = chs.fold<int>(0, (a, b) => a + (b.duration ?? 0));
    if (s <= 0) return '';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  /// 下载选集弹层 —— 对应聆阅的「选集下载 / 自定义下载」。
  ///
  /// 勾选章节后串行下载，进度实时写入 `download_chapters` 表。
  Future<void> _showDownloadSheet(Book book, BookDetailState detailState) async {
    final source = detailState.source;
    if (source == null) return;

    final selected = <int>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final c = sheetContext.appColors;
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppStrings.downloadCustom,
                              style: TextStyle(
                                color: c.foreground,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (selected.length ==
                                    detailState.chapters.length) {
                                  selected.clear();
                                } else {
                                  selected
                                    ..clear()
                                    ..addAll(List.generate(
                                      detailState.chapters.length,
                                      (i) => i,
                                    ));
                                }
                              });
                            },
                            child: Text(
                              selected.length == detailState.chapters.length
                                  ? AppStrings.downloadCancelSelectAll
                                  : AppStrings.downloadSelectAll,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${AppStrings.downloadSelectChapters}'
                          '（已选 ${selected.length}）',
                          style:
                              TextStyle(color: c.mutedForeground, fontSize: 12),
                        ),
                      ),
                    ),
                    Divider(height: 16, color: c.border),
                    Expanded(
                      child: ListView.builder(
                        itemCount: detailState.chapters.length,
                        itemBuilder: (context, i) {
                          final ch = detailState.chapters[i];
                          return CheckboxListTile(
                            dense: true,
                            value: selected.contains(i),
                            onChanged: (v) => setSheetState(() {
                              if (v ?? false) {
                                selected.add(i);
                              } else {
                                selected.remove(i);
                              }
                            }),
                            title: Text(
                              ch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.foreground,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: ch.duration == null
                                ? null
                                : Text(
                                    '${ch.duration}${AppStrings.unitSecond}',
                                    style: TextStyle(
                                      color: c.mutedForeground,
                                      fontSize: 11,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.download),
                          label: Text(
                            selected.isEmpty
                                ? AppStrings.downloadSelectChapters
                                : '${AppStrings.startDownload} (${selected.length})',
                          ),
                          onPressed: selected.isEmpty
                              ? null
                              : () async {
                                  Navigator.of(sheetContext).pop();
                                  await _startDownload(
                                    book: book,
                                    source: source,
                                    chapters: detailState.chapters
                                        .where((ch) =>
                                            selected.contains(ch.index))
                                        .toList(),
                                  );
                                },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 执行下载并给出结果反馈。
  Future<void> _startDownload({
    required Book book,
    required SourceRule source,
    required List<Chapter> chapters,
  }) async {
    final downloader = ref.read(audioDownloaderProvider);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.downloadStarted)),
    );

    final result = await downloader.downloadChapters(
      bookId: book.bookId,
      sourceId: source.sourceId,
      chapters: chapters,
      source: source,
    );

    // 刷新下载页与缓存用量
    ref.read(downloadsProvider.notifier).refresh();
    ref.invalidate(cacheUsageProvider);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${AppStrings.downloaded} ${result.ok}'
          '${result.failed > 0 ? ' · ${AppStrings.downloadFailed} ${result.failed}' : ''}',
        ),
      ),
    );
  }

  void _startPlaying(int chapterIndex, int? position) {
    final detailState = ref.read(bookDetailProvider);
    if (detailState.book == null ||
        detailState.source == null ||
        detailState.chapters.isEmpty) {
      return;
    }

    ref.read(playerProvider.notifier).initBook(
          source: detailState.source!,
          book: detailState.book!,
          chapters: detailState.chapters,
          startChapterIndex: chapterIndex,
          startPosition: position,
        );

    context.push('/player');
  }
}

/// 用于从搜索结果传递书籍数据的扩展
extension BookDetailPageExt on BookDetailPage {
  static void loadBook(WidgetRef ref, Book book, SourceRule source) {
    ref.read(bookDetailProvider.notifier).loadBook(book, source);
  }
}
