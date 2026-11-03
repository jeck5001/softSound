import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/player_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_strings.dart';
import '../../data/models/chapter.dart';
import '../../services/chapter_segments.dart';
import '../../theme/app_widgets.dart';
import '../../theme/brand_widgets.dart';
import '../../theme/playback_settings.dart';
import '../../theme/subtitle_overlay.dart';

/// 播放器页面 —— 聆阅「NOW PLAYING」版式 1:1 复刻（2026-10-16 真机截图）。
///
/// 结构：紫色渐变底 / 顶栏（收起 + 金标 + 阅读睡眠目录）/
/// 描边大封面 + 波形胶囊 / 标题 + 集数黑金 chip / 金色进度条 ±15 /
/// 功能 chip 行 / 硬阴影控制排（紫上一章 · 金大播放 · 青下一章）。
class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final subtitle = ref.watch(subtitleProvider);
    final settings = ref.watch(playbackSettingsProvider);

    // 字幕随播放位置同步（仅在位置变化时推进，避免多余重建）。
    ref.listen<Duration>(
      playerProvider.select((s) => s.position),
      (_, position) => ref.read(subtitleProvider.notifier).syncTo(position),
    );

    return Scaffold(
      body: playerState.currentBook == null
          ? SafeArea(child: _buildEmptyState(context))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [
                          const Color(0xFF7C3AED).withValues(alpha: 0.30),
                          const Color(0xFF0A0A0A),
                        ]
                      : [
                          const Color(0xFFE4DAFA),
                          const Color(0xFFF5F4FF),
                        ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, ref, playerState),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Column(
                          children: [
                            LyCover(
                              url: playerState.currentBook?.coverUrl ?? '',
                              width: 224,
                              height: 224,
                              radius: 26,
                            ),
                            const SizedBox(height: 10),
                            const _WavePill(),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    playerState.currentBook?.name ?? '',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: context.appColors.foreground,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                LyDarkChip(
                                  '${playerState.currentChapterIndex + 1} / ${playerState.chapters.length}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                playerState.currentChapter?.name ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.appColors.mutedForeground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (playerState.error != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  playerState.error!,
                                  style: const TextStyle(
                                      color: Color(0xFFDC2626), fontSize: 12),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _buildProgressBar(
                                context, playerState, playerNotifier),
                            const SizedBox(height: 6),
                            _buildChipRow(context, ref, settings),
                            const SizedBox(height: 10),
                            SubtitleOverlay(subtitle: subtitle),
                          ],
                        ),
                      ),
                    ),
                    _buildControls(context, playerState, playerNotifier),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
    );
  }

  /// 顶栏：收起 + NOW PLAYING + 阅读/睡眠/目录。
  Widget _buildTopBar(
      BuildContext context, WidgetRef ref, PlayerState playerState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          LyIconButton(
            icon: Icons.expand_more_rounded,
            size: 44,
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NOW PLAYING',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  playerState.currentBook?.name ?? AppStrings.playing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          LyIconButton(
            icon: Icons.menu_book_rounded,
            size: 44,
            onTap: () => context.push('/reading'),
          ),
          const SizedBox(width: 8),
          LyIconButton(
            icon: Icons.bedtime_outlined,
            size: 44,
            bg: playerState.hasSleepTimer
                ? const Color(0xFF7C3AED)
                : const Color(0xFFEDE9FE),
            fg: playerState.hasSleepTimer
                ? Colors.white
                : const Color(0xFF1C1917),
            onTap: () => _showSleepTimerDialog(context, playerState,
                ref.read(playerProvider.notifier)),
          ),
          const SizedBox(width: 8),
          LyIconButton(
            icon: Icons.list_alt_rounded,
            size: 44,
            onTap: () => _showChapterList(context, ref),
          ),
        ],
      ),
    );
  }

  /// 金色进度条 + ±15。
  Widget _buildProgressBar(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
  ) {
    final c = context.appColors;
    return Column(
      children: [
        Row(
          children: [
            LyIconButton(
              icon: Icons.replay_10_rounded,
              size: 42,
              onTap: () => playerNotifier
                  .rewind(duration: const Duration(seconds: 15)),
            ),
            Expanded(
              child: playerState.isLoading || playerState.isBuffering
                  ? const LinearProgressIndicator(minHeight: 5)
                  : SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        activeTrackColor: const Color(0xFFEAB308),
                        inactiveTrackColor: const Color(0xFF292524),
                        thumbColor: const Color(0xFFEAB308),
                        overlayColor: const Color(0x33EAB308),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: playerState.progress.clamp(0.0, 1.0),
                        onChanged: (v) => playerNotifier.seekToProgress(v),
                      ),
                    ),
            ),
            LyIconButton(
              icon: Icons.forward_10_rounded,
              size: 42,
              onTap: () => playerNotifier
                  .fastForward(duration: const Duration(seconds: 15)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 52),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(playerState.positionText,
                  style: TextStyle(
                      color: c.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text(playerState.durationText,
                  style: TextStyle(
                      color: c.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  /// 功能 chip 行（聆阅：片头尾/倍速/音质/目录）。
  Widget _buildChipRow(
    BuildContext context,
    WidgetRef ref,
    PlaybackSettingsState settings,
  ) {
    final skipOn = settings.skipIntro || settings.skipOutro;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        GestureDetector(
          onTap: () async {
            final ctl = ref.read(playbackSettingsProvider.notifier);
            if (skipOn) {
              await ctl.setSkipIntro(false);
              await ctl.setSkipOutro(false);
            } else {
              await ctl.setSkipIntro(true);
              await ctl.setSkipOutro(true);
            }
          },
          child: LyMetaChip(
            '片头尾',
            color:
                skipOn ? const Color(0xFF7C3AED) : const Color(0xFF78716C),
            icon: Icons.skip_next_rounded,
          ),
        ),
        PopupMenuButton<double>(
          tooltip: AppStrings.playSpeedPrefix,
          onSelected: (v) =>
              ref.read(playbackSettingsProvider.notifier).setSpeed(v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0.75, child: Text('0.75x')),
            PopupMenuItem(value: 1.0, child: Text('1.0x')),
            PopupMenuItem(value: 1.25, child: Text('1.25x')),
            PopupMenuItem(value: 1.5, child: Text('1.5x')),
            PopupMenuItem(value: 2.0, child: Text('2.0x')),
            PopupMenuItem(value: 3.0, child: Text('3.0x')),
          ],
          child: LyMetaChip(
            '${settings.speed}x',
            color: const Color(0xFF1C1917),
          ),
        ),
        PopupMenuButton<AudioQuality>(
          tooltip: '音质',
          onSelected: (v) =>
              ref.read(playbackSettingsProvider.notifier).setQuality(v),
          itemBuilder: (_) => [
            for (final q in AudioQuality.values)
              PopupMenuItem(value: q, child: Text(q.label)),
          ],
          child: LyMetaChip(
            settings.quality.label,
            color: const Color(0xFF1C1917),
          ),
        ),
        GestureDetector(
          onTap: () => _showChapterList(context, ref),
          child: const LyMetaChip(
            '目录',
            color: Color(0xFF78716C),
            icon: Icons.sort_rounded,
          ),
        ),
      ],
    );
  }

  /// 控制排：紫上一章 / 金色大播放 / 青下一章（硬阴影）。
  Widget _buildControls(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: playerState.currentChapterIndex > 0
                ? () => playerNotifier.previousChapter()
                : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFF7C3AED), width: 2.5),
                boxShadow: lyHardShadow,
              ),
              child: const Icon(Icons.skip_previous_rounded,
                  size: 30, color: Color(0xFF7C3AED)),
            ),
          ),
          GestureDetector(
            onTap: playerState.isLoading
                ? null
                : () => playerNotifier.togglePlay(),
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF1C1917), width: 3),
                boxShadow: lyHardShadow,
              ),
              child: playerState.isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.black),
                      ),
                    )
                  : Icon(
                      // 用 showPauseIcon 而不是 isPlaying：
                      // 章节播完时 just_audio 的 playing 仍为 true，
                      // 只看 isPlaying 会一直显示暂停键、点了也没反应。
                      playerState.showPauseIcon
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 44,
                      color: const Color(0xFF1C1917),
                    ),
            ),
          ),
          GestureDetector(
            onTap: playerState.currentChapterIndex <
                    playerState.chapters.length - 1
                ? () => playerNotifier.nextChapter()
                : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFF0D9488), width: 2.5),
                boxShadow: lyHardShadow,
              ),
              child: const Icon(Icons.skip_next_rounded,
                  size: 30, color: Color(0xFF0D9488)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.music_off,
      title: AppStrings.noPlayContent,
      description: AppStrings.offlineHint1,
    );
  }

  void _showSleepTimerDialog(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  AppStrings.sleepTimer,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (final min in [15, 30, 45, 60])
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: Text('$min分钟'),
                  onTap: () {
                    playerNotifier.setSleepTimer(Duration(minutes: min));
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text(AppStrings.sleepTimerChapterEnd),
                onTap: () {
                  playerNotifier.setSleepTimer(Duration.zero);
                  Navigator.pop(context);
                },
              ),
              if (playerState.hasSleepTimer)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text(AppStrings.cancelTimer),
                  onTap: () {
                    playerNotifier.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showChapterList(BuildContext context, WidgetRef ref) {
    final playerState = ref.read(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ChapterSheet(
        chapters: playerState.chapters,
        currentIndex: playerState.currentChapterIndex,
        // 上游声明的总集数：与本地列表比对，能立刻暴露"目录不全"
        expectedCount: playerState.currentBook?.chapterCount,
        onRefresh: () async {
          final grew = await playerNotifier.refreshChapters();
          ref.invalidate(playerProvider);
          return grew;
        },
        onPick: (index) {
          playerNotifier.playChapter(index);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// 章节目录弹窗（带分段）。
///
/// 单独做成 StatefulWidget 而不是用 StatefulBuilder：
/// 后者配合 `await showDialog` 时，外层 builder 重跑会重置局部变量，
/// 表现为「点分段/点跳转没反应」（实测踩到）。
class _ChapterSheet extends StatefulWidget {
  const _ChapterSheet({
    required this.chapters,
    required this.currentIndex,
    required this.onPick,
    this.expectedCount,
    this.onRefresh,
  });

  final List<Chapter> chapters;
  final int currentIndex;
  final void Function(int index) onPick;

  /// 上游声明的总集数（`Book.chapterCount`）。
  ///
  /// 本地列表比它少 ⇒ 目录不全（分页中途失败 / 被上限截断），
  /// 必须显式告诉用户，而不是让用户以为"这本书就这么多集"。
  final int? expectedCount;

  /// 重新拉取章节；返回是否变多。
  final Future<bool> Function()? onRefresh;

  @override
  State<_ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends State<_ChapterSheet> {
  late int _page;
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 打开目录时直接落在**当前章所在段**：793 集写到第 700 章，
    // 从「1-100集」开始找太痛苦。
    _page = ChapterSegments.pageOf(widget.currentIndex);
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _jumpToChapter() async {
    final total = widget.chapters.length;
    final controller = TextEditingController();
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('跳到指定集'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1 - $total',
            helperText: '输入集数后跳到该集所在分段',
          ),
          onSubmitted: (v) => Navigator.pop(
            ctx,
            (int.tryParse(v.trim()) ?? 0).clamp(1, total) - 1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              (int.tryParse(controller.text.trim()) ?? 0).clamp(1, total) - 1,
            ),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    // 不 dispose controller：dialog 退场动画期间 TextField 还挂在树上，
    // 提前 dispose 会触发 `_dependents.isEmpty` 断言（实测崩溃）。
    if (!mounted || target == null) return;
    setState(() {
      _page = ChapterSegments.pageOf(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final total = widget.chapters.length;
    final ranges = ChapterSegments.ranges(total);
    final safePage = ranges.isEmpty ? 0 : _page.clamp(0, ranges.length - 1);
    // 本地列表 vs 上游声明总数：少了就是目录不全
    final expected = widget.expectedCount ?? 0;
    final missing = expected > total ? expected - total : 0;
    final visible = ChapterSegments.slice(widget.chapters, safePage);
    final rangeStart = ranges.isEmpty ? 0 : ranges[safePage].$1;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppStrings.bookCatalog} ($total)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.foreground,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 目录不全时的显式告警（不能假装"就这么多集"）
            if (missing > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 20, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '目录可能不全：已加载 $total 集，共 $expected 集',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.onRefresh != null)
                      TextButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final grew = await widget.onRefresh!.call();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                grew ? '已重新拉取章节' : '仍未能获取更多章节，请稍后再试',
                              ),
                            ),
                          );
                          if (grew) {
                            setState(() => _page = 0);
                          }
                        },
                        child: const Text('重试'),
                      ),
                  ],
                ),
              ),
            // 分段 chips（1-100集 / 101-200集 …），与详情页同一套规则
            if (ranges.length > 1)
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ranges.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, r) {
                    final selected = r == safePage;
                    return GestureDetector(
                      onTap: () => setState(() => _page = r),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF7C3AED) : c.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFDDD6FE),
                          ),
                        ),
                        child: Text(
                          ChapterSegments.label(ranges[r]),
                          style: TextStyle(
                            color: selected ? Colors.white : c.foreground,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // 集数多时（4715 集 = 48 段），滑 chips 也费劲 → 直接输入集数
            if (ranges.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                child: TextButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('跳到指定集'),
                  onPressed: _jumpToChapter,
                ),
              ),
            const SizedBox(height: 2),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  // 列表里是「本段第 i 条」，真实章节下标要加段起点
                  final index = rangeStart + i;
                  final chapter = visible[i];
                  final isCurrent = index == widget.currentIndex;
                  return ListTile(
                    dense: true,
                    leading: isCurrent
                        ? Icon(Icons.play_arrow, color: c.primary)
                        : SizedBox(
                            width: 32,
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ),
                    title: Text(
                      chapter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? c.primary : c.foreground,
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    selected: isCurrent,
                    onTap: () => widget.onPick(index),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 封面下的波形胶囊（聆阅静态装饰）。
class _WavePill extends StatelessWidget {
  const _WavePill();

  @override
  Widget build(BuildContext context) {
    const bars = [
      (8.0, Color(0xFF8B5CF6)),
      (16.0, Color(0xFFEAB308)),
      (11.0, Color(0xFF1C1917)),
      (18.0, Color(0xFF8B5CF6)),
      (9.0, Color(0xFFEAB308)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE)),
        boxShadow: lyHardShadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (h, col) in bars)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Container(
                width: 4.5,
                height: h,
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
