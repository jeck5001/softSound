import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';
import '../../theme/playback_settings.dart';

/// Source adapter for sites whose flows are too complex for selector-only rules.
abstract class TypedSourceAdapter {
  String get sourceId;

  Future<List<Book>> search(SourceRule source, String keyword);

  Future<Book?> getBookDetail(SourceRule source, Book book);

  Future<List<Chapter>> getChapterList(SourceRule source, Book book);

  /// 解析音频地址。
  ///
  /// [quality] 为可选的音质偏好；适配器可按需使用（如酷我切换 br 参数），
  /// 不支持音质选择的适配器忽略该参数即可。
  Future<String?> getAudioUrl(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  });

  /// 获取章节字幕（LRC 文本）。
  ///
  /// 默认无字幕（返回 null）；支持字幕的适配器覆写此方法。
  /// 来源：聆阅字节码 `fetchKuwoLyric`（#18026）——酷我字幕随播放地址
  /// 一起在 `kuwo-play` 响应的 `lyric` 字段返回（实测契约）。
  /// 获取章节字幕（LRC）。默认不支持。
  ///
  /// [quality] 与 [getAudioUrl] 同义：有的源把字幕塞在取址响应里
  /// （酷我 `kuwo-play?rid=&quality=&host=`），需要把音质一起带上；
  /// 不支持的源忽略即可（向后兼容）。
  Future<String?> getLyric(
    SourceRule source,
    Chapter chapter, {
    AudioQuality? quality,
  }) async =>
      null;
}
