import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/book.dart';
import '../data/models/source_rule.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/play_history_repository.dart';
import '../features/source_manager/source_manager_page.dart';
import '../theme/app_strings.dart';
import 'player_service.dart';

/// 「上次播放」快照 —— 启动时用来恢复播放会话。
///
/// 来源是本地 `play_history` 表（播放、切章、退出都会写）。
/// 之前**只写不读**：进度存了，但 App 重启后从不查，于是「上次播放的」
/// 永远消失。聆阅在首页有 `ResumeListenHint`（继续收听卡片）负责这件事，
/// 文案（字节码 #21364 逐字）：`上次收听的有声书` / `上次收听记录已就绪` /
/// `续播` / ` 章 · 听到 `。
@immutable
class LastPlayed {
  const LastPlayed({
    required this.book,
    required this.source,
    required this.progress,
  });

  final Book book;
  final SourceRule source;
  final PlayProgress progress;

  /// 第几章（1 基，给用户看）。
  int get chapterNumber => progress.chapterIndex + 1;

  /// 「12:34」。
  String get positionLabel => formatClock(Duration(milliseconds: progress.position));

  /// 卡片副标题：`第 9 章 · 听到 12:04`。
  ///
  /// `chapterListenedTo` 的字面量是 `章 · 听到 `（聆阅原文），
  /// 前面要补空格，否则会拼成 `第 9章`。
  String get subtitle =>
      '第 $chapterNumber ${AppStrings.chapterListenedTo}$positionLabel';

  /// `mm:ss` / `h:mm:ss`。
  static String formatClock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// 读取「上次播放」。
///
/// 关键点：`play_history` 只存 `bookId`，书本体在 `books` 表里 ——
/// 而**只有加过书架的书才会进 books 表**。所以对「听过但没收藏」的书，
/// 这里返回 null（宁可没有卡片，也不编造书名）。
class LastPlayedService {
  LastPlayedService({
    required PlayHistoryRepository historyRepo,
    required BookRepository bookRepo,
    required List<SourceRule> Function() sources,
  })  : _historyRepo = historyRepo,
        _bookRepo = bookRepo,
        _sources = sources;

  final PlayHistoryRepository _historyRepo;
  final BookRepository _bookRepo;
  final List<SourceRule> Function() _sources;

  /// 最近一条可用的播放记录。没有时返回 null。
  Future<LastPlayed?> load() async {
    try {
      final recent = await _historyRepo.getRecentPlayed(limit: 5);
      for (final p in recent) {
        // 跳过「点开就退」：第 1 章且不到 3 秒，弹续播只会烦人。
        if (p.chapterIndex == 0 && p.position < 3000) continue;

        final book = await _bookRepo.getBookById(p.bookId);
        if (book == null) continue; // 没进过 books 表 → 无法还原书名
        final source = _sourceOf(p.sourceId, book.sourceId);
        if (source == null) continue; // 书源已删
        return LastPlayed(book: book, source: source, progress: p);
      }
      return null;
    } catch (e) {
      debugPrint('读取上次播放失败: $e');
      return null;
    }
  }

  /// 优先按记录里的 sourceId，其次按书自身的 sourceId。
  SourceRule? _sourceOf(String primary, String fallback) {
    final list = _sources();
    for (final id in [primary, fallback]) {
      if (id.isEmpty) continue;
      for (final s in list) {
        if (s.sourceId == id) return s;
      }
    }
    return null;
  }
}

/// 启动时把上次播放装回播放器（**不自动起播**，避免一开 App 就出声）。
///
/// 只做一次：`_restored` 守卫避免热重载/重建时重复拉章节列表。
class SessionRestorer {
  SessionRestorer(this._ref);

  final Ref _ref;
  static bool _restored = false;

  /// 返回是否成功恢复（false 表示没有上次记录或恢复失败）。
  ///
  /// [force] 供「继续收听」卡片点击时重试：启动时那次可能因网络失败，
  /// 但 `_restored` 已被置位，不重试的话卡片点了永远没反应。
  Future<bool> restoreOnce({bool force = false}) async {
    if (_restored && !force) return false;
    _restored = true;

    // 等书源就绪（异步从 assets 加载，通常几百毫秒）。
    // 不等的话会在书源为空时判定「源已删除」，白白丢掉上次播放。
    final sources = await _waitSources();
    if (sources.isEmpty) {
      if (force) _restored = false; // 允许卡片再试
      return false;
    }

    final LastPlayed? last;
    try {
      // force 时重建 provider，避免拿到启动早期的缓存 null
      if (force) _ref.invalidate(lastPlayedProvider);
      last = await _ref.read(lastPlayedProvider.future);
    } catch (_) {
      return false;
    }
    if (last == null) return false;

    try {
      return await _ref.read(playerProvider.notifier).restoreSession(
            source: last.source,
            book: last.book,
            chapterIndex: last.progress.chapterIndex,
            positionMs: last.progress.position,
          );
    } catch (e) {
      debugPrint('恢复上次播放失败: $e');
      return false;
    }
  }

  /// 等待书源加载完成（最多 5 秒）。
  Future<List<SourceRule>> _waitSources() async {
    for (var i = 0; i < 50; i++) {
      final list = _ref.read(sourcesProvider);
      if (list.isNotEmpty) return list;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _ref.read(sourcesProvider);
  }

  /// 供测试重置「只恢复一次」的标记。
  @visibleForTesting
  static void resetForTest() => _restored = false;
}

/// 会话恢复器 Provider。
final sessionRestorerProvider =
    Provider<SessionRestorer>((ref) => SessionRestorer(ref));

/// 「上次播放」Provider。
///
/// 用 `FutureProvider` 而不是在播放器里同步读：读库 + 查书是 IO，
/// 不该阻塞首帧；UI 侧 `when(loading/data)` 三态处理。
/// 注意这里用 `watch` 而不是 `read`：
/// `sourcesProvider` 是**异步**从 assets 加载的，首次构建时还是空列表。
/// 早先用 `read` 抓了空列表 → 找不到书源 → 判定「源已删除」→ 返回 null，
/// 而且 FutureProvider 会缓存这个 null，卡片永远不出现（实测踩到）。
/// 改成 watch 后，书源就绪时自动重算。
final lastPlayedProvider = FutureProvider<LastPlayed?>((ref) async {
  final sources = ref.watch(sourcesProvider);
  if (sources.isEmpty) return null; // 书源未就绪：先不判定，等 watch 重建
  final service = LastPlayedService(
    historyRepo: ref.watch(playHistoryRepositoryProvider),
    bookRepo: ref.watch(bookRepositoryProvider),
    sources: () => sources,
  );
  return service.load();
});
