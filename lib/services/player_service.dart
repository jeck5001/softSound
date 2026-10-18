import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

import '../data/models/book.dart';
import '../data/models/chapter.dart';
import '../data/models/source_rule.dart';
import '../data/repositories/play_history_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../theme/app_strings.dart';
import '../theme/playback_settings.dart';
import '../theme/subtitle_overlay.dart';
import 'audio_effects.dart';
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
  final Duration? sleepTimerRemaining;
  final bool sleepAfterChapter;

  /// 睡眠定时是否进入最后 30 秒（聆阅：`⏱ 还有 30 秒，即将停止播放`）。
  final bool sleepTimerEnding;

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
    this.sleepTimerRemaining,
    this.sleepAfterChapter = false,
    this.sleepTimerEnding = false,
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

  String get sleepTimerText {
    if (sleepAfterChapter) return '播完本章';
    if (sleepTimerRemaining == null) return '';
    return _formatDuration(sleepTimerRemaining!);
  }

  bool get hasSleepTimer => sleepTimerRemaining != null || sleepAfterChapter;

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
    Duration? sleepTimerRemaining,
    bool? sleepAfterChapter,
    bool clearSleepTimer = false,
    bool? sleepTimerEnding,
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
      sleepTimerRemaining: clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      sleepAfterChapter: clearSleepTimer ? false : (sleepAfterChapter ?? this.sleepAfterChapter),
      sleepTimerEnding: clearSleepTimer
          ? false
          : (sleepTimerEnding ?? this.sleepTimerEnding),
    );
  }
}

/// 播放器状态管理
class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _player;
  final SourceParser _parser;
  final PlayHistoryRepository _historyRepo;
  final Logger _logger = Logger();

  /// 原生音效桥（音量增强）。
  final AudioEffects _audioEffects = AudioEffects();

  /// 音频设备监听（蓝牙/耳机断开自动暂停）。
  final AudioDeviceMonitor _deviceMonitor = AudioDeviceMonitor();
  
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _processingStateSubscription;
  Timer? _saveProgressTimer;
  Timer? _sleepTimer;
  int? _pendingSeekPosition;

  /// 跳过片头秒数（0 表示不跳过）。由播放设置同步进来。
  int skipIntroSeconds = 0;

  /// 是否跳过片尾。启用后在片尾区间内自动切下一章。
  bool skipOutro = false;

  /// 片尾区间秒数。
  int skipOutroSeconds = 0;

  /// 章节倒序播放标记（false 为正序）。
  bool chapterOrderAscending = true;

  /// 片尾跳过去重标记（每章重置）。
  bool _outroTriggered = false;

  /// 睡眠定时进入「即将停止」提示的阈值（聆阅为 30 秒）。
  static const Duration _sleepWarningThreshold = Duration(seconds: 30);

  PlayerNotifier(this._historyRepo)
      : _player = AudioPlayer(),
        _parser = SourceParser(),
        super(const PlayerState()) {
    _initListeners();
  }

  /// 累计收听统计仓库（可选注入，便于测试）。
  StatsRepository? _statsRepo;

  /// 注入统计仓库（由 provider 在构造后调用）。
  void attachStats(StatsRepository repo) => _statsRepo = repo;

  /// 字幕控制器（由 provider 注入 subtitleProvider 的全局实例；null 不启用）。
  SubtitleController? _subtitle;

  /// 字幕请求序号（切章竞态保护：旧章节的迟到结果不得覆盖新章节）。
  int _lyricSeq = 0;

  /// 注入字幕控制器。
  void attachSubtitle(SubtitleController controller) => _subtitle = controller;

  /// 异步拉取当前章节字幕（LRC）并载入字幕层。
  ///
  /// 契约来源：聆阅字节码 #18026 `fetchKuwoLyric` —— 酷我字幕随
  /// `kuwo-play` 响应的 `lyric` 字段返回；无字幕源返回 null，
  /// 字幕层显示「本集暂无字幕」占位。尽力而为，失败不影响播放。
  Future<void> _loadLyricForChapter(int index) async {
    final sub = _subtitle;
    final source = state.currentSource;
    if (sub == null || source == null) return;
    if (index < 0 || index >= state.chapters.length) return;

    final seq = ++_lyricSeq;
    final chapter = state.chapters[index];
    try {
      final lrc = await _parser.getLyric(source, chapter);
      // 期间切了章：丢弃迟到结果
      if (seq != _lyricSeq || state.currentChapterIndex != index) return;
      final total = _player.duration ??
          (chapter.duration != null
              ? Duration(seconds: chapter.duration!)
              : null);
      sub.loadLrc(lrc, totalDuration: total);
    } catch (e) {
      _logger.d('字幕获取失败（尽力而为）', error: e);
    }
  }

  /// 开始监听音频设备断开（蓝牙/耳机）。
  ///
  /// 断开时暂停播放并提示，对应聆阅的
  /// `蓝牙/耳机已断开，已暂停播放`。
  Future<void> startDeviceMonitoring() async {
    await _deviceMonitor.start(onDisconnected: () {
      if (!state.isPlaying) return;
      _logger.d('音频设备断开，自动暂停');
      pause();
      state = state.copyWith(error: AppStrings.bluetoothDisconnected);
    });
  }

  /// 上一秒的播放位置，用于计算实际收听增量。
  Duration _lastCountedPosition = Duration.zero;

  /// 累计未上报的收听秒数。
  Duration _pendingListening = Duration.zero;

  /// 判定一次位置变化是否应计入收听时长。
  ///
  /// 规则：只有**正常前进**（增量在 (0, 5s]）才计入；
  /// 回退、暂停不动、以及 seek 跳转均不计入，
  /// 避免用户拖动进度条虚增等级。
  ///
  /// 抽为静态纯函数以便单测（无需启动音频引擎）。
  static bool shouldCountListening(Duration previous, Duration current) {
    final delta = current - previous;
    return delta > Duration.zero && delta <= const Duration(seconds: 5);
  }

  /// 记录一次收听增量。
  void _accumulateListening(Duration position) {
    final previous = _lastCountedPosition;
    _lastCountedPosition = position;

    if (!shouldCountListening(previous, position)) {
      return;
    }
    final delta = position - previous;
    _pendingListening += delta;

    // 攒够 15 秒再落库，减少写库频率
    if (_pendingListening.inSeconds >= 15) {
      final secs = _pendingListening.inSeconds;
      _pendingListening -= Duration(seconds: secs);
      _statsRepo?.addListeningSeconds(secs);
    }
  }

  /// 应用播放设置（由 UI 层在设置变化时调用）。
  void applyPlaybackSettings({
    required double speed,
    required int skipIntroSeconds,
    required bool skipOutro,
    required int skipOutroSeconds,
    required bool chapterOrderAscending,
    bool volumeBoostEnabled = false,
    int volumeBoostGain = 600,
    bool audioMixing = false,
    AudioQuality? quality,
  }) {
    this.skipIntroSeconds = skipIntroSeconds;
    this.skipOutro = skipOutro;
    this.skipOutroSeconds = skipOutroSeconds;
    this.chapterOrderAscending = chapterOrderAscending;
    if (state.speed != speed) {
      setSpeed(speed);
    }
    // 音量增强：走原生 LoudnessEnhancer（just_audio 的 setVolume 无法放大）
    _applyVolumeBoost(volumeBoostEnabled, volumeBoostGain);
    _quality = quality;
    // 混音：切换音频焦点策略（对应聆阅「与其他App同时播放」）
    if (_audioMixing != audioMixing) {
      _audioMixing = audioMixing;
      AudioSessionConfigurator.apply(mixing: audioMixing);
    }
  }

  /// 当前混音开关状态。
  bool _audioMixing = false;

  /// 当前音质偏好（透传给适配器）。
  AudioQuality? _quality;

  /// 应用音量增强设置。
  ///
  /// 关闭时释放原生音效资源（聆阅：退出播放时释放）。
  Future<void> _applyVolumeBoost(bool enabled, int gainMb) async {
    if (!enabled) {
      await _audioEffects.disable();
      return;
    }
    final ok = await _audioEffects.enable(gainMb);
    if (!ok) {
      _logger.d('音量增强不可用（平台不支持或原生调用失败）');
    }
  }

  void _initListeners() {
    _positionSubscription = _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
      _accumulateListening(position);

      // 跳过片尾：进入片尾区间即切下一章（只触发一次，靠 _outroTriggered 去重）。
      if (skipOutro && !_outroTriggered) {
        final total = state.duration;
        if (total.inSeconds > skipOutroSeconds &&
            position.inSeconds >= total.inSeconds - skipOutroSeconds) {
          _outroTriggered = true;
          _logger.d('到达片尾，自动切换下一章');
          _onChapterComplete();
        }
      }
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
    int? startPosition,
  }) async {
    _saveProgressTimer?.cancel();
    
    state = PlayerState(
      currentBook: book,
      currentSource: source,
      chapters: chapters,
      currentChapterIndex: startChapterIndex,
      isLoading: true,
    );
    
    _pendingSeekPosition = startPosition;

    if (chapters.isNotEmpty) {
      await _loadAndPlayChapter(startChapterIndex);
    }
    
    _startProgressSaveTimer();
  }
  
  void _startProgressSaveTimer() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveProgress(),
    );
  }
  
  Future<void> _saveProgress() async {
    if (state.currentBook == null) return;
    
    await _historyRepo.saveProgress(
      bookId: state.currentBook!.bookId,
      sourceId: state.currentBook!.sourceId,
      chapterIndex: state.currentChapterIndex,
      chapterName: state.currentChapter?.name,
      position: state.position.inMilliseconds,
      duration: state.duration.inMilliseconds,
    );
    _logger.d('保存播放进度: 章节${state.currentChapterIndex}, 位置${state.position.inSeconds}秒');
  }

  /// 播放指定章节
  Future<void> playChapter(int index) async {
    if (index < 0 || index >= state.chapters.length) return;
    
    await _saveProgress();
    
    state = state.copyWith(
      currentChapterIndex: index,
      isLoading: true,
      error: null,
    );
    
    _pendingSeekPosition = null;
    await _loadAndPlayChapter(index);
  }

  /// 加载并播放章节
  Future<void> _loadAndPlayChapter(int index) async {
    if (state.currentSource == null || index >= state.chapters.length) return;

    final chapter = state.chapters[index];
    _logger.d('Loading chapter: ${chapter.name}, URL: ${chapter.url}');

    // 每章重置片尾跳过去重标记与收听增量基准。
    _outroTriggered = false;
    _lastCountedPosition = Duration.zero;

    String? audioUrl = chapter.audioUrl;

    if (audioUrl == null || audioUrl.isEmpty) {
      _logger.d('Fetching audio URL from parser...');
      audioUrl = await _parser.getAudioUrl(
        state.currentSource!,
        chapter,
        quality: _quality,
      );
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
      
      if (_pendingSeekPosition != null && _pendingSeekPosition! > 0) {
        await _player.seek(Duration(milliseconds: _pendingSeekPosition!));
        _pendingSeekPosition = null;
      } else if (skipIntroSeconds > 0) {
        // 跳过片头：仅在新章节开始（无续播位置）时生效。
        final target = Duration(seconds: skipIntroSeconds);
        final total = _player.duration;
        // 只有当片头点明显小于总时长时才跳，避免短音频被整段跳过。
        if (total == null || total.inSeconds > skipIntroSeconds) {
          _logger.d('跳过片头 $skipIntroSeconds 秒');
          await _player.seek(target);
        }
      }

      await _player.play();
      _logger.d('Playback started successfully');
      state = state.copyWith(isLoading: false, error: null);

      // 字幕：先清占位，再异步拉取（尽力而为，不阻塞播放）。
      _subtitle?.clear();
      _loadLyricForChapter(index);
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
    if (state.sleepAfterChapter) {
      _logger.d('播完本章停止');
      cancelSleepTimer();
      pause();
      return;
    }
    // 章节顺序：正序播完进下一章，倒序播完回上一章（对应聆阅的「正序/倒序」）。
    final nextIndex =
        chapterOrderAscending ? state.currentChapterIndex + 1 : state.currentChapterIndex - 1;
    if (nextIndex >= 0 && nextIndex < state.chapters.length) {
      playChapter(nextIndex);
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
    await _saveProgress();
    await _player.stop();
    _saveProgressTimer?.cancel();
    _sleepTimer?.cancel();
    state = const PlayerState();
  }

  /// 设置睡眠定时器
  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    
    if (duration == Duration.zero) {
      state = state.copyWith(sleepAfterChapter: true, clearSleepTimer: false, sleepTimerRemaining: null);
      _logger.d('设置睡眠定时: 播完本章');
      return;
    }
    
    state = state.copyWith(
      sleepTimerRemaining: duration,
      sleepTimerEnding: duration <= _sleepWarningThreshold,
      sleepAfterChapter: false,
    );
    
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.sleepTimerRemaining == null) {
        timer.cancel();
        return;
      }
      
      final remaining = state.sleepTimerRemaining! - const Duration(seconds: 1);
      
      if (remaining <= Duration.zero) {
        _logger.d('睡眠定时到期，暂停播放');
        timer.cancel();
        state = state.copyWith(clearSleepTimer: true);
        pause();
      } else {
        state = state.copyWith(
          sleepTimerRemaining: remaining,
          // 进入最后 30 秒时置位，供 UI 提示（聆阅同款体验）
          sleepTimerEnding: remaining <= _sleepWarningThreshold,
        );
      }
    });
    
    _logger.d('设置睡眠定时: ${duration.inMinutes}分钟');
  }

  /// 取消睡眠定时器
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = state.copyWith(clearSleepTimer: true);
    _logger.d('取消睡眠定时');
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
    _audioEffects.disable();
    _deviceMonitor.stop();
    _saveProgress();
    _saveProgressTimer?.cancel();
    _sleepTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// 全局播放器 Provider
///
/// 同时把播放设置（倍速、跳过片头尾、章节顺序）同步进播放器，
/// 使设置页的改动即时生效。
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final historyRepo = ref.watch(playHistoryRepositoryProvider);
  final notifier = PlayerNotifier(historyRepo);

  void sync() {
    final s = ref.read(playbackSettingsProvider);
    notifier.applyPlaybackSettings(
      speed: s.speed,
      skipIntroSeconds: s.skipIntro ? s.introSeconds : 0,
      skipOutro: s.skipOutro,
      skipOutroSeconds: s.outroSeconds,
      chapterOrderAscending: s.chapterOrderAscending,
      volumeBoostEnabled: s.volumeBoostEnabled,
      volumeBoostGain: s.volumeBoostGain,
      audioMixing: s.audioMixing,
      quality: s.quality,
    );
  }

  notifier.attachStats(ref.watch(statsRepositoryProvider));
  // 字幕层与播放器共享全局 subtitleProvider（播放页/阅读页都在 watch 它）。
  notifier.attachSubtitle(ref.read(subtitleProvider.notifier));
  notifier.startDeviceMonitoring();

  sync();
  ref.listen(playbackSettingsProvider, (_, __) => sync());
  return notifier;
});
