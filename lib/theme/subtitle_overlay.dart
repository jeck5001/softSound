import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_strings.dart';
import 'app_widgets.dart';
import 'subtitle_parser.dart';

/// 字幕显示状态（支持时间轴）。
@immutable
class SubtitleState {
  /// 全部字幕 cue（按时间排序）。
  final List<SubtitleCue> cues;

  /// 当前时刻应显示的字幕文本；null 表示此刻无字幕。
  final String? text;

  /// 当前命中的 cue 索引；-1 表示无。
  final int activeIndex;

  /// 是否正在加载。
  final bool isLoading;

  /// 本章是否确认无字幕。
  final bool unavailable;

  const SubtitleState({
    this.cues = const [],
    this.text,
    this.activeIndex = -1,
    this.isLoading = false,
    this.unavailable = false,
  });

  /// 是否应显示字幕文本。
  bool get hasText => text != null && text!.trim().isNotEmpty;

  /// 是否已加载到可用字幕。
  bool get hasCues => cues.isNotEmpty;

  SubtitleState copyWith({
    List<SubtitleCue>? cues,
    String? text,
    int? activeIndex,
    bool? isLoading,
    bool? unavailable,
    bool clearText = false,
  }) =>
      SubtitleState(
        cues: cues ?? this.cues,
        text: clearText ? null : (text ?? this.text),
        activeIndex: activeIndex ?? this.activeIndex,
        isLoading: isLoading ?? this.isLoading,
        unavailable: unavailable ?? this.unavailable,
      );
}

/// 字幕控制器（支持 LRC 时间轴）。
///
/// 数据来源：本阶段未接入真实字幕接口（见文档 §6.7），
/// 但完整实现了「解析 → 按播放位置同步 → 展示」链路，
/// 拿到字幕文本后调用 [loadLrc] 即可直接生效。
class SubtitleController extends StateNotifier<SubtitleState> {
  SubtitleController({SubtitleParser? parser})
      : _parser = parser ?? const SubtitleParser(),
        super(const SubtitleState());

  final SubtitleParser _parser;

  /// 当前章节总时长，用于给最后一条 cue 定界。
  Duration _totalDuration = Duration.zero;

  /// 加载 LRC 字幕文本。
  ///
  /// [totalDuration] 可选，用于最后一条 cue 的结束时间。
  void loadLrc(String? lrc, {Duration? totalDuration}) {
    _totalDuration = totalDuration ?? Duration.zero;
    final cues = _parser.parse(lrc, totalDuration: totalDuration);

    if (cues.isEmpty) {
      state = const SubtitleState(unavailable: true);
      return;
    }

    state = SubtitleState(cues: cues, text: cues.first.text, activeIndex: 0);
  }

  /// 兼容旧接口：直接设置单条文本（无时间轴）。
  void setSubtitle(String? text) {
    if (text == null || text.trim().isEmpty) {
      state = const SubtitleState(unavailable: true);
      return;
    }
    state = SubtitleState(
      cues: [
        SubtitleCue(
          start: Duration.zero,
          end: _totalDuration > Duration.zero
              ? _totalDuration
              : const Duration(seconds: 5),
          text: text,
        ),
      ],
      text: text,
      activeIndex: 0,
    );
  }

  /// 按播放位置更新当前字幕。
  ///
  /// 由播放器的 position 流驱动（见播放页）。
  void syncTo(Duration position) {
    if (state.cues.isEmpty) return;

    final index = _parser.indexAt(state.cues, position);
    if (index == state.activeIndex) return; // 无变化则不通知，避免多余重建

    if (index < 0) {
      // 句间停顿：清空文本但保留 cues
      state = state.copyWith(clearText: true, activeIndex: -1);
    } else {
      state = state.copyWith(
        text: state.cues[index].text,
        activeIndex: index,
      );
    }
  }

  /// 标记开始加载。
  void startLoading() {
    state = const SubtitleState(isLoading: true);
  }

  /// 标记本集无字幕（聆阅：`本集暂无字幕`）。
  void markUnavailable() {
    state = const SubtitleState(unavailable: true);
  }

  /// 清空（切章时调用）。
  void clear() {
    _totalDuration = Duration.zero;
    state = const SubtitleState();
  }
}

/// 字幕 Provider。
final subtitleProvider =
    StateNotifierProvider<SubtitleController, SubtitleState>(
  (ref) => SubtitleController(),
);

/// 播放页字幕层 —— 对应聆阅的「本集暂无字幕 / 字幕加载中…」体验。
///
/// 无字幕时展示占位文案，有字幕时以半透明底衬托可读性。
class SubtitleOverlay extends StatelessWidget {
  final SubtitleState subtitle;

  /// 是否处于阅读模式（阅读模式下字幕更突出）。
  final bool readingMode;

  /// 点击重试回调（无字幕时可选展示）。
  final VoidCallback? onRetry;

  const SubtitleOverlay({
    super.key,
    required this.subtitle,
    this.readingMode = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (subtitle.isLoading) {
      return _box(
        context,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.mutedForeground,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.subtitleLoading,
              style: TextStyle(color: c.mutedForeground, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!subtitle.hasText) {
      // 有 cues 但此刻是句间停顿 → 保留占位高度避免布局跳动
      final isGap = subtitle.hasCues;
      return _box(
        context,
        child: Text(
          isGap
              ? ' '
              : (subtitle.unavailable
                  ? AppStrings.subtitleNoText
                  : AppStrings.subtitleUnavailable),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.mutedForeground,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      );
    }

    return _box(
      context,
      child: Text(
        subtitle.text!,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: c.foreground,
          fontSize: readingMode ? 16 : 14,
          height: 1.7,
          fontWeight: readingMode ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _box(BuildContext context, {required Widget child}) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.muted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: child),
    );
  }
}

/// 字幕占位（阅读模式用）—— 三种状态：加载中 / 无字幕 / 未获取。
///
/// 与 [SubtitleOverlay] 的区别：占满可用空间并居中排版，适合整页阅读。
class AppSubtitlePlaceholder extends StatelessWidget {
  final SubtitleState subtitle;

  const AppSubtitlePlaceholder({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    if (subtitle.isLoading) {
      return const AppLoadingState(message: AppStrings.subtitleLoading);
    }

    return AppEmptyState(
      icon: Icons.closed_caption_off_outlined,
      title: subtitle.unavailable
          ? AppStrings.subtitleNoText
          : AppStrings.subtitleUnavailable,
      description: AppStrings.offlineHint1,
    );
  }
}
