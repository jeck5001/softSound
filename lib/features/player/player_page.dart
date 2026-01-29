import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/player_service.dart';

/// 播放器页面
class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(playerState.currentBook?.name ?? '正在播放'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () => _showChapterList(context, ref),
          ),
        ],
      ),
      body: playerState.currentBook == null
          ? _buildEmptyState(context)
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: _buildCover(context, playerState),
                  ),
                  _buildInfo(playerState),
                  _buildProgressBar(context, playerState, playerNotifier),
                  _buildControls(context, playerState, playerNotifier),
                  _buildSpeedControl(context, playerState, playerNotifier),
                  _buildSleepTimer(context, playerState, playerNotifier),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放内容',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '去搜索并选择一本书开始收听',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, PlayerState playerState) {
    final coverUrl = playerState.currentBook?.coverUrl;

    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: coverUrl != null && coverUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildDefaultCover(context),
                  errorWidget: (context, url, error) =>
                      _buildDefaultCover(context),
                )
              : _buildDefaultCover(context),
        ),
      ),
    );
  }

  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.headphones,
        size: 80,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildInfo(PlayerState playerState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text(
            playerState.currentBook?.name ?? '',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            playerState.currentChapter?.name ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (playerState.error != null) ...[
            const SizedBox(height: 8),
            Text(
              playerState.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          if (playerState.isLoading || playerState.isBuffering)
            const LinearProgressIndicator()
          else
            Slider(
              value: playerState.progress.clamp(0.0, 1.0),
              onChanged: (value) {
                playerNotifier.seekToProgress(value);
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  playerState.positionText,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  playerState.durationText,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            iconSize: 36,
            icon: const Icon(Icons.skip_previous),
            onPressed: playerState.currentChapterIndex > 0
                ? () => playerNotifier.previousChapter()
                : null,
          ),
          const SizedBox(width: 16),
          IconButton(
            iconSize: 36,
            icon: const Icon(Icons.replay_10),
            onPressed: () => playerNotifier.rewind(
              duration: const Duration(seconds: 10),
            ),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: playerState.isLoading
                ? null
                : () => playerNotifier.togglePlay(),
            child: playerState.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
          ),
          const SizedBox(width: 16),
          IconButton(
            iconSize: 36,
            icon: const Icon(Icons.forward_30),
            onPressed: () => playerNotifier.fastForward(
              duration: const Duration(seconds: 30),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            iconSize: 36,
            icon: const Icon(Icons.skip_next),
            onPressed:
                playerState.currentChapterIndex < playerState.chapters.length - 1
                    ? () => playerNotifier.nextChapter()
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('播放速度: '),
          for (final speed in [0.75, 1.0, 1.25, 1.5, 2.0])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text('${speed}x'),
                selected: playerState.speed == speed,
                onSelected: (selected) {
                  if (selected) playerNotifier.setSpeed(speed);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSleepTimer(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bedtime_outlined,
            size: 20,
            color: playerState.hasSleepTimer
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          if (playerState.hasSleepTimer)
            GestureDetector(
              onTap: () => _showSleepTimerDialog(context, playerState, playerNotifier),
              child: Row(
                children: [
                  Text(
                    '睡眠定时: ${playerState.sleepTimerText}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => playerNotifier.cancelSleepTimer(),
                    child: Icon(
                      Icons.close,
                      size: 18,
              color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => _showSleepTimerDialog(context, playerState, playerNotifier),
              child: Text(
                '睡眠定时',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
        ],
      ),
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
                  '睡眠定时',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('15分钟'),
                onTap: () {
                  playerNotifier.setSleepTimer(const Duration(minutes: 15));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('30分钟'),
                onTap: () {
                  playerNotifier.setSleepTimer(const Duration(minutes: 30));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('45分钟'),
                onTap: () {
                  playerNotifier.setSleepTimer(const Duration(minutes: 45));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('60分钟'),
                onTap: () {
                  playerNotifier.setSleepTimer(const Duration(minutes: 60));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text('播完本章'),
                onTap: () {
                  playerNotifier.setSleepTimer(Duration.zero);
                  Navigator.pop(context);
                },
              ),
              if (playerState.hasSleepTimer)
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('取消定时'),
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
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '章节列表 (${playerState.chapters.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: playerState.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = playerState.chapters[index];
                        final isCurrent =
                            index == playerState.currentChapterIndex;
                        return ListTile(
                          leading: isCurrent
                              ? Icon(
                                  Icons.play_arrow,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                          title: Text(
                            chapter.name,
                            style: TextStyle(
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontWeight:
                                  isCurrent ? FontWeight.bold : null,
                            ),
                          ),
                          selected: isCurrent,
                          onTap: () {
                            playerNotifier.playChapter(index);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
