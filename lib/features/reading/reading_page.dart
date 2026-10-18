import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/subtitle_overlay.dart';

import '../../services/player_service.dart';

/// 阅读模式 —— 对应聆阅的「阅读」。
///
/// 行为对齐聆阅：
/// - 进入时**暂停播放**（聆阅提示：`阅读模式下播放已暂停，点击「朗读」可继续播放`）
/// - 以大字排版展示当前章节字幕，当前句高亮
/// - 底部「朗读」按钮恢复播放并高亮跟随
class ReadingPage extends ConsumerStatefulWidget {
  const ReadingPage({super.key});

  @override
  ConsumerState<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends ConsumerState<ReadingPage> {
  final ScrollController _scroll = ScrollController();

  /// 是否已因进入阅读模式而暂停。
  bool _pausedByReading = false;

  @override
  void initState() {
    super.initState();
    // 首帧后暂停播放（此时 provider 已可用）
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterReadingMode());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _enterReadingMode() {
    final player = ref.read(playerProvider);
    if (player.isPlaying) {
      ref.read(playerProvider.notifier).pause();
      _pausedByReading = true;
    }
    setState(() {});
  }

  /// 恢复朗读（聆阅：「点击「朗读」可继续播放」）。
  void _resumeReading() {
    ref.read(playerProvider.notifier).play();
    _pausedByReading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final subtitle = ref.watch(subtitleProvider);
    final player = ref.watch(playerProvider);

    // 当前句变化时滚动到可见位置
    ref.listen<int>(
      subtitleProvider.select((s) => s.activeIndex),
      (_, index) {
        if (index >= 0) _scrollToActive(index);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(player.currentBook?.name ?? AppStrings.readingMode),
        actions: [
          IconButton(
            icon: const Icon(Icons.headphones),
            tooltip: AppStrings.back,
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部暂停提示（仅因阅读模式暂停时显示）
          if (_pausedByReading && !player.isPlaying)
            Container(
              width: double.infinity,
              color: c.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.pause_circle_outline,
                      size: 18, color: c.accentForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.readingModePaused,
                      style: TextStyle(
                        color: c.accentForeground,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 正文区
          Expanded(
            child: subtitle.cues.isEmpty
                ? AppSubtitlePlaceholder(subtitle: subtitle)
                : _buildCues(context, subtitle),
          ),

          // 底部朗读按钮
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(
                    player.isPlaying ? Icons.pause : Icons.volume_up,
                  ),
                  label: Text(
                    player.isPlaying ? AppStrings.pause : AppStrings.readAloud,
                  ),
                  onPressed: player.isPlaying
                      ? () => ref.read(playerProvider.notifier).pause()
                      : _resumeReading,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 大字排版字幕列表，当前句高亮。
  Widget _buildCues(BuildContext context, SubtitleState subtitle) {
    final c = context.appColors;
    final cues = subtitle.cues;

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: cues.length,
      itemBuilder: (context, i) {
        final cue = cues[i];
        final isActive = i == subtitle.activeIndex;

        return GestureDetector(
          onTap: () {
            // 点击某句 → 跳转到该位置（需已在播放）
            ref.read(playerProvider.notifier).seekTo(cue.start);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              cue.text,
              style: TextStyle(
                fontSize: isActive ? 19 : 16,
                height: 1.8,
                color: isActive ? c.foreground : c.mutedForeground,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToActive(int index) {
    if (!_scroll.hasClients) return;
    // 每句高度约 60px（含 padding 与行高），居中滚动
    final target = (index * 60.0) - 120.0;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}
