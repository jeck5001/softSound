/// 一条带时间轴的字幕。
class SubtitleCue {
  /// 起始时间。
  final Duration start;

  /// 结束时间（由下一条推导，最后一条用时长或默认值）。
  final Duration end;

  /// 文本内容。
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  /// 该 cue 是否覆盖给定播放位置。
  bool covers(Duration position) => position >= start && position < end;

  @override
  String toString() => 'SubtitleCue(${start.inMilliseconds}ms, '
      '${end.inMilliseconds}ms, "$text")';

  @override
  bool operator ==(Object other) =>
      other is SubtitleCue &&
      other.start == start &&
      other.end == end &&
      other.text == text;

  @override
  int get hashCode => Object.hash(start, end, text);
}

/// LRC / 字幕文本解析器。
///
/// 支持：
/// - 标准 LRC 时间标签 `[mm:ss.xx]` / `[mm:ss.xxx]` / `[mm:ss]`
/// - 一行多标签（`[00:01.00][00:05.00]同一句`）
/// - 元信息标签 `[ti:]` `[ar:]` `[al:]` `[by:]` `[offset:]`（含偏移校正）
/// - 纯文本（无时间标签）→ 均分为单条 cue，退化展示
///
/// 不支持（如实返回空或忽略）：
/// - 增强型 LRC 的字级标签 `<mm:ss.xx>`
/// - 二进制/富文本字幕格式
class SubtitleParser {
  const SubtitleParser();

  /// 时间标签：`[mm:ss]`、`[mm:ss.xx]`、`[mm:ss.xxx]`，允许 1–3 位分钟。
  static final RegExp _timeTag =
      RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

  /// 需要忽略的元信息标签。
  static final RegExp _metaTag =
      RegExp(r'^\[(ti|ar|al|by|re|ve|length):', caseSensitive: false);

  /// 解析字幕文本为按时间排序的 cue 列表。
  ///
  /// [totalDuration] 用于给最后一条 cue 设定结束时间；未提供时用 5 秒兜底。
  List<SubtitleCue> parse(String? raw, {Duration? totalDuration}) {
    if (raw == null || raw.trim().isEmpty) return const [];

    // 1) 提取 offset（毫秒），用于整体时间校正
    var offsetMs = 0;
    final offsetMatch =
        RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false)
            .firstMatch(raw);
    if (offsetMatch != null) {
      offsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
    }

    // 2) 逐行解析
    final entries = <({Duration start, String text})>[];

    for (final line in raw.split(RegExp(r'\r\n|\r|\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_metaTag.hasMatch(trimmed)) continue;

      final matches = _timeTag.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      // 文本 = 去掉所有时间标签后的剩余部分
      final text = trimmed.replaceAll(_timeTag, '').trim();
      if (text.isEmpty) continue;

      for (final m in matches) {
        final minutes = int.tryParse(m.group(1)!) ?? 0;
        final seconds = int.tryParse(m.group(2)!) ?? 0;
        final fracRaw = m.group(3);

        // 小数位：1 位=十分之一秒，2 位=百分之一，3 位=毫秒
        var millis = 0;
        if (fracRaw != null) {
          final padded = fracRaw.padRight(3, '0').substring(0, 3);
          millis = int.tryParse(padded) ?? 0;
        }

        var startMs =
            minutes * 60 * 1000 + seconds * 1000 + millis + offsetMs;
        if (startMs < 0) startMs = 0;

        entries.add((start: Duration(milliseconds: startMs), text: text));
      }
    }

    // 3) 无时间标签 → 退化为单条
    if (entries.isEmpty) {
      final plain = raw.trim();
      if (plain.isEmpty) return const [];
      return [
        SubtitleCue(
          start: Duration.zero,
          end: totalDuration ?? const Duration(seconds: 5),
          text: plain,
        ),
      ];
    }

    // 4) 排序 + 推导 end
    entries.sort((a, b) => a.start.compareTo(b.start));

    final cues = <SubtitleCue>[];
    for (var i = 0; i < entries.length; i++) {
      final current = entries[i];
      final Duration end;
      if (i + 1 < entries.length) {
        end = entries[i + 1].start;
      } else {
        // 最后一条：用总时长；若无则往后 5 秒
        final fallback = current.start + const Duration(seconds: 5);
        if (totalDuration != null && totalDuration > current.start) {
          end = totalDuration;
        } else {
          end = fallback;
        }
      }
      cues.add(SubtitleCue(start: current.start, end: end, text: current.text));
    }

    return cues;
  }

  /// 在 [cues] 中查找覆盖 [position] 的字幕文本。
  ///
  /// 返回 null 表示该时刻无字幕（正常情况，如句间停顿）。
  String? textAt(List<SubtitleCue> cues, Duration position) {
    if (cues.isEmpty) return null;
    // cue 已按 start 排序，可二分；这里用线性扫描保持实现简单且可读。
    for (final cue in cues) {
      if (cue.covers(position)) return cue.text;
      // 已越过当前位置且未命中 → 后续更不可能命中
      if (cue.start > position) break;
    }
    return null;
  }

  /// 查找覆盖 [position] 的 cue 索引；无则返回 -1。
  int indexAt(List<SubtitleCue> cues, Duration position) {
    for (var i = 0; i < cues.length; i++) {
      if (cues[i].covers(position)) return i;
      if (cues[i].start > position) break;
    }
    return -1;
  }
}
