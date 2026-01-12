import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

import '../data/models/book.dart';
import '../data/models/chapter.dart';
import '../data/models/source_rule.dart';
import 'source_parser.dart';

/// 全局播放状态
class PlayerState {
  final Book? currentBook;
  final SourceRule? currentSource;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool isPlaying;
  final bool isLoading;
  final bool isBuffering;
  final String? error;

  const PlayerState({
    this.currentBook,
    this.currentSource,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.isPlaying = false,
    this.isLoading = false,
    this.isBuffering = false,
    this.error,
  });

  Chapter? get currentChapter =>
      chapters.isNotEmpty && currentChapterIndex < chapters.length
          ? chapters[currentChapterIndex]
          : null;

  String get positionText => _formatDuration(position);
  String get durationText => _formatDuration(duration);
  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  PlayerState copyWith({
    Book? currentBook,
    SourceRule? currentSource,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? isPlaying,
    bool? isLoading,
    bool? isBuffering,
    String? error,
  }) {
    return PlayerState(
      currentBook: currentBook ?? this.currentBook,
      currentSource: currentSource ?? this.currentSource,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      isBuffering: isBuffering ?? this.isBuffering,
      error: error,
    );
  }
}

/// 播放器状态管理
class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _player;
  final SourceParser _parser;
  final Logger _logger = Logger();
  
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _processingStateSubscription;

  PlayerNotifier()
      : _player = AudioPlayer(),
        _parser = SourceParser(),
        super(const PlayerState()) {
    _initListeners();
  }

  void _initListeners() {
    _positionSubscription = _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    _playerStateSubscription = _player.playingStream.listen((isPlaying) {
      state = state.copyWith(isPlaying: isPlaying);
    });

    _processingStateSubscription = _player.processingStateStream.listen((processingState) {
      state = state.copyWith(
        isBuffering: processingState == ProcessingState.buffering,
        isLoading: processingState == ProcessingState.loading,
      );

      if (processingState == ProcessingState.completed) {
        _onChapterComplete();
      }
    });
  }

  /// 初始化播放（加载书籍和章节）
  Future<void> initBook({
    required SourceRule source,
    required Book book,
    required List<Chapter> chapters,
    int startChapterIndex = 0,
  }) async {
    state = PlayerState(
      currentBook: book,
      currentSource: source,
      chapters: chapters,
      currentChapterIndex: startChapterIndex,
      isLoading: true,
    );

    if (chapters.isNotEmpty) {
      await _loadAndPlayChapter(startChapterIndex);
    }
  }

  /// 播放指定章节
  Future<void> playChapter(int index) async {
    if (index < 0 || index >= state.chapters.length) return;
    
    state = state.copyWith(
      currentChapterIndex: index,
      isLoading: true,
      error: null,
    );
    
    await _loadAndPlayChapter(index);
  }

  /// 加载并播放章节
  Future<void> _loadAndPlayChapter(int index) async {
    if (state.currentSource == null || index >= state.chapters.length) return;

    final chapter = state.chapters[index];
    _logger.d('Loading chapter: ${chapter.name}, URL: ${chapter.url}');
    
    String? audioUrl = chapter.audioUrl;

    if (audioUrl == null || audioUrl.isEmpty) {
      _logger.d('Fetching audio URL from parser...');
      audioUrl = await _parser.getAudioUrl(state.currentSource!, chapter);
      _logger.d('Got audio URL: $audioUrl');
    }

    if (audioUrl == null || audioUrl.isEmpty) {
      _logger.e('Audio URL is null or empty');
      state = state.copyWith(
        isLoading: false,
        error: '无法获取音频地址',
      );
      return;
    }

    try {
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ...?state.currentSource!.header,
        ...?state.currentSource!.audio.header,
      };

      _logger.d('Playing audio: $audioUrl');
      _logger.d('With headers: $headers');

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          headers: headers,
        ),
      );

      await _player.play();
      _logger.d('Playback started successfully');
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      _logger.e('Failed to play audio: $audioUrl', error: e);
      state = state.copyWith(
        isLoading: false,
        error: '播放失败: $e',
      );
    }
  }

  /// 章节播放完成
  void _onChapterComplete() {
    if (state.currentChapterIndex < state.chapters.length - 1) {
      playChapter(state.currentChapterIndex + 1);
    }
  }

  /// 播放/暂停切换
  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// 播放
  Future<void> play() async {
    await _player.play();
  }

  /// 暂停
  Future<void> pause() async {
    await _player.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _player.stop();
    state = const PlayerState();
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  /// 按进度跳转（0.0 - 1.0）
  Future<void> seekToProgress(double progress) async {
    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * progress).toInt(),
    );
    await _player.seek(position);
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  /// 上一章
  Future<void> previousChapter() async {
    if (state.currentChapterIndex > 0) {
      await playChapter(state.currentChapterIndex - 1);
    }
  }

  /// 下一章
  Future<void> nextChapter() async {
    if (state.currentChapterIndex < state.chapters.length - 1) {
      await playChapter(state.currentChapterIndex + 1);
    }
  }

  /// 快进
  Future<void> fastForward({Duration duration = const Duration(seconds: 15)}) async {
    final targetPosition = state.position + duration;
    await _player.seek(
      targetPosition > state.duration ? state.duration : targetPosition,
    );
  }

  /// 快退
  Future<void> rewind({Duration duration = const Duration(seconds: 15)}) async {
    final targetPosition = state.position - duration;
    await _player.seek(
      targetPosition < Duration.zero ? Duration.zero : targetPosition,
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// 全局播放器 Provider
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});
