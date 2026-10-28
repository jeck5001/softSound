import 'package:audio_service/audio_service.dart';

import '../data/models/book.dart';
import '../data/models/chapter.dart';
import '../theme/app_strings.dart';

/// 通知栏 / 锁屏 / 小米灵动岛的媒体元数据。
///
/// 把「书 + 章」映射成 [`MediaItem`] 的规则集中在这里，便于单测与复用：
///
/// | 字段 | 取值 | 说明 |
/// |---|---|---|
/// | `title` | 章节名 | 通知主标题（灵动岛显示这行） |
/// | `album` | 书名 | 通知 subText |
/// | `artist` | 「播音 演播」→ 作者 → 应用名 | 通知正文 |
/// | `artUri` | 封面（仅 http/https） | 系统据此取图，缺失则用默认图标 |
/// | `duration` | 章节时长（秒） | 让进度条一开始就有总长 |
///
/// 为什么要单独抽出来：`just_audio_background` **必须**通过 `AudioSource.uri`
/// 的 `tag:` 传 `MediaItem`，否则即使有 MediaSession，通知栏也只会显示
/// "未知" —— 而小米 HyperOS 的灵动岛/焦点通知读的就是这些字段。
class MediaMetadata {
  const MediaMetadata._();

  /// 由书籍与章节构造媒体元数据。
  static MediaItem forChapter({
    required Book? book,
    required Chapter chapter,
    required String audioUrl,
  }) {
    return MediaItem(
      id: audioUrl,
      title: chapter.name,
      album: _albumLabel(book),
      artist: artistLabel(book),
      artUri: coverUri(book?.coverUrl),
      duration: chapter.duration != null
          ? Duration(seconds: chapter.duration!)
          : null,
    );
  }

  /// 通知副标题（专辑位）：书名，缺失回落应用名。
  static String _albumLabel(Book? book) {
    final name = book?.name.trim() ?? '';
    return name.isEmpty ? AppStrings.appName : name;
  }

  /// 通知正文：演播优先，其次作者，最后应用名。
  static String artistLabel(Book? book) {
    if (book == null) return AppStrings.appName;
    final narrator = book.narrator?.trim() ?? '';
    if (narrator.isNotEmpty) return '$narrator 演播';
    final author = book.author?.trim() ?? '';
    if (author.isNotEmpty) return author;
    return AppStrings.appName;
  }

  /// 封面地址：只接受 http(s)（file:// 或空串会让系统取图失败）。
  static Uri? coverUri(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }
}
