import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

import '../data/models/book.dart';
import '../data/models/chapter.dart';
import '../data/models/source_rule.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/play_history_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../theme/app_strings.dart';
import '../theme/playback_settings.dart';
import '../theme/subtitle_overlay.dart';
import 'audio_effects.dart';
import 'lingting_audio_handler.dart';
import 'media_metadata.dart';
import 'source_parser.dart';
import 'system_settings_bridge.dart';

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

  /// 当前章节是否已播到结尾（just_audio 的 `ProcessingState.completed`）。
  ///
  /// 注意：此时 `isPlaying` **仍然是 true**（播放器没有自行 pause），
  /// 所以不能只用 `isPlaying` 决定按钮图标，否则会出现
  /// 「明明没声音了，还显示暂停键；点一下变播放键，再点又没反应」。
  final bool isCompleted;
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
    this.isCompleted = false,
    this.error,
    this.sleepTimerRemaining,
    this.sleepAfterChapter = false,
    this.sleepTimerEnding = false,
  });

  /// 界面是否该显示「暂停键」。
  ///
  /// 只有「真的在出声」才显示暂停；已播完（completed）即便 isPlaying 为 true，
  /// 也应显示播放键，让用户能重播/继续。
  bool get showPauseIcon => isPlaying && !isCompleted;

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
    bool? isCompleted,
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
      isCompleted: isCompleted ?? this.isCompleted,
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

  /// 书籍仓库（可选注入）：播放时记录「听过的书」，让重启后能续播。
  BookRepository? _bookRepo;

  /// 媒体会话处理器（可选注入；测试里为 null）。
  LingtingAudioHandler? _handler;

  /// 上次同步给媒体会话的整秒位置（节流用）。
  int _lastSyncedSecond = -1;

  /// 用户是否仍期望播放。
  ///
  /// 章节 URL 在真机上要拉几十秒，这段时间里用户可能已经按了暂停；
  /// 加载完成后如果无脑 `_player.play()`，就会「按了暂停却自己响起来」，
  /// 界面也会瞬间跳回暂停键 —— 属于同一类按钮状态错位。
  bool _playRequested = true;

  /// 注入书籍仓库（由 provider 在构造后调用）。
  void attachBookRepository(BookRepository repo) => _bookRepo = repo;

  /// 注入媒体会话处理器，并把「通知栏/锁屏的切章意图」接回来。
  void attachAudioHandler(LingtingAudioHandler handler) {
    _handler = handler;
    handler.attachPlayer(_player);
    handler.onSkipChapter = (delta) {
      if (delta > 0) {
        nextChapter();
      } else {
        previousChapter();
      }
    };
  }

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
      final lrc = await _parser.getLyric(source, chapter, quality: _quality);
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
    await _listenInterruptions();
  }

  /// 音频焦点被抢（来电/其他 App 播放）时跟随系统暂停/恢复。
  ///
  /// 不做这一步的话，系统会把音频静音但 `just_audio` 的 `playing` 仍是 true，
  /// 界面就停在一个「显示暂停键、其实没有声音」的错位上
  /// —— 这正是用户反馈的「按钮状态不太对」。
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  bool _pausedByInterruption = false;

  Future<void> _listenInterruptions() async {
    if (_interruptionSub != null) return;
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _pausedByInterruption = _player.playing;
              _logger.d('音频被打断，暂停播放');
              pause();
            case AudioInterruptionType.duck:
              // 闪避（导航播报等）：不暂停，交给系统压低音量
              _logger.d('音频被打断（duck），继续播放');
          }
        } else {
          if (_pausedByInterruption) {
            _pausedByInterruption = false;
            _logger.d('音频打断结束，恢复播放');
            play();
          }
        }
      });
    } catch (e) {
      _logger.w('监听音频打断失败', error: e);
    }
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
    // 混音：切换音频焦点策略（对应聆阅「与其他App同时播放」）。
    // 首次必须执行（`_audioMixing` 初值为 null），否则音频属性/焦点从不设置。
    if (_audioMixing != audioMixing) {
      _audioMixing = audioMixing;
      unawaited(AudioSessionConfigurator.apply(mixing: audioMixing));
    }
  }

  /// 当前混音开关状态。
  ///
  /// 用可空是为了区分「从未配置过」和「配置为不混音」——
  /// 初值 `false` 时 `if (_audioMixing != audioMixing)` 恒不成立，
  /// `AudioSessionConfigurator.apply()` 永远不执行，
  /// 音频会话就停在 audio_session 的兜底配置上（用户实测：首播没声音）。
  bool? _audioMixing;

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

      // 通知栏/锁屏进度条同步：每 ~1 秒一次，避免每帧都推平台通道。
      final second = position.inSeconds;
      if (second != _lastSyncedSecond) {
        _lastSyncedSecond = second;
        _syncMediaSession();
      }

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
      _syncMediaSession();
    });

    _processingStateSubscription = _player.processingStateStream.listen((processingState) {
      state = state.copyWith(
        isBuffering: processingState == ProcessingState.buffering,
        isLoading: processingState == ProcessingState.loading,
        isCompleted: processingState == ProcessingState.completed,
      );

      _syncMediaSession(buffering: processingState == ProcessingState.buffering);

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
  
  /// 恢复上次播放会话（**不自动起播**）。
  ///
  /// 与 [initBook] 的区别：
  /// - 不调用 `play()`，只把章节/进度装载好，等用户点播放；
  /// - 章节列表要现拉（重启后内存里没有），失败就退回「只有书 + 进度」的
  ///   半恢复状态，让 UI 至少能显示卡片、点进去再重试。
  ///
  /// 返回是否成功装载了可播放的章节。
  Future<bool> restoreSession({
    required SourceRule source,
    required Book book,
    required int chapterIndex,
    required int positionMs,
  }) async {
    _saveProgressTimer?.cancel();

    state = PlayerState(
      currentBook: book,
      currentSource: source,
      chapters: const [],
      currentChapterIndex: chapterIndex,
      isLoading: true,
    );

    List<Chapter> chapters;
    try {
      chapters = await _parser.getChapterList(source, book);
    } catch (e) {
      _logger.w('恢复会话：拉取章节失败', error: e);
      chapters = const [];
    }

    if (chapters.isEmpty) {
      // 半恢复：书和进度留着，UI 显示「继续收听」卡片，点进去重新拉。
      state = state.copyWith(isLoading: false);
      _logger.w('恢复会话：章节为空，仅保留书籍与进度');
      return false;
    }

    final safeIndex =
        chapterIndex >= 0 && chapterIndex < chapters.length ? chapterIndex : 0;
    state = PlayerState(
      currentBook: book,
      currentSource: source,
      chapters: chapters,
      currentChapterIndex: safeIndex,
      isLoading: false,
      // 关键：把进度写进 state，否则定时保存会把 0 覆盖回数据库，
      // 下次续播就从 00:00 开始了（实测踩到：position 被写成 0）。
      position: Duration(milliseconds: positionMs),
      duration: Duration(milliseconds: chapters[safeIndex].duration ?? 0),
    );
    // 进度先存着，等用户真正点播放时再 seek（见 [_loadAndPlayChapter]）。
    _pendingSeekPosition = positionMs > 0 ? positionMs : null;
    _startProgressSaveTimer();
    return true;
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

    // 没有装载音频源时（刚恢复会话还没点播放、或已 stop）不要写进度：
    // 此时 position 是 0，写进去会把上次听到的位置覆盖掉，
    // 导致「续播」永远从 00:00 开始。
    if (_player.audioSource == null) {
      _logger.d('跳过保存进度：音频源未装载');
      return;
    }

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

  /// 是否是「真书」（有名字且不是加载占位）。
  static bool isPlaceholderBook(Book book) {
    final name = book.name.trim();
    if (name.isEmpty) return true;
    return name == AppStrings.loadingBookInfo || name.startsWith('加载书籍信息');
  }

  static bool _isRealBook(Book book) => !isPlaceholderBook(book);

  /// 是否已做过一次通知权限检查（避免每次切章都碰原生侧）。
  bool _notificationPermissionChecked = false;

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

    // 首次播放申请通知权限（Android 13+）：否则媒体通知不出现，
    // 下拉菜单没有卡片，小米灵动岛也不会点亮。
    if (!_notificationPermissionChecked) {
      _notificationPermissionChecked = true;
      unawaited(SystemSettingsBridge().ensureNotificationPermission());
    }

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

      // 媒体元数据：通知栏/锁屏/小米灵动岛读的就是这里的 title/album/artist/artUri。
      // 不传 tag 的话，即使有 MediaSession 也只会显示"未知"。
      // 记录「听过的书」：只更新 books 表元数据，**不动书架状态**。
    // 不做这一步的话，没收藏过的书重启后查不到书名，续播直接失效。
    //
    // 但**占位书不能写**：从 `/book/{id}` 进入详情时，详情还没拉到之前
    // `currentBook.name` 是「加载书籍信息…」，写进去就成了脏数据，
    // 之后播放页永远显示「加载书籍信息…」（用户实测踩到）。
    final playedBook = state.currentBook;
    if (playedBook != null && _isRealBook(playedBook)) {
      // 封面兜底：从榜单/搜索进来时 book.coverUrl 可能是 null（详情还没回来），
      // 但库里可能已经存过真封面 —— 用它补上，避免播放页一直空白。
      if (playedBook.coverUrl == null || playedBook.coverUrl!.isEmpty) {
        final stored = await _bookRepo?.getBookById(playedBook.bookId);
        final storedCover = stored?.coverUrl;
        if (storedCover != null && storedCover.isNotEmpty) {
          state = state.copyWith(
            currentBook: playedBook.copyWith(coverUrl: storedCover),
          );
        }
      }
      unawaited(
        _bookRepo?.touchPlayedBook(state.currentBook!) ?? Future<void>.value(),
      );
    }

      // 单条 AudioSource 不再挂 tag：元数据与「上一章/下一章」改由
      // 媒体会话的队列承载（见 `_publishToMediaSession`）。
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          headers: headers,
        ),
      );
      
      if (_pendingSeekPosition != null && _pendingSeekPosition! > 0) {
        // 越界保护：续播位置可能来自「另一章」（换书/换源/章节变短），
        // 直接 seek 到超过时长的位置会让播放器立刻 completed 或抛错，
        // 表现就是「第一次播不出来，切下一章才好」。
        var target = Duration(milliseconds: _pendingSeekPosition!);
        final total = _player.duration;
        if (total != null && total > Duration.zero) {
          final maxSeek = total - const Duration(seconds: 5);
          if (maxSeek <= Duration.zero) {
            target = Duration.zero;
          } else if (target > maxSeek) {
            _logger.w('续播位置越界（$target > $maxSeek），改为从头播放');
            target = Duration.zero;
          }
        }
        await _player.seek(target);
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

      // 把队列与当前章发布给媒体会话：通知栏/锁屏/灵动岛据此显示
      // 「上一章 / 播放-暂停 / 下一章」以及第 N 章标题。
      _publishToMediaSession(index);

      // 加载期间用户可能已经暂停：此时不要再自动起播
      if (!_playRequested) {
        _logger.d('加载完成，但用户已暂停，保持暂停状态');
        state = state.copyWith(isLoading: false);
        return;
      }

      // 直接调 _player.play() 会绕过 play()，这里补上会话激活，
      // 否则首次播放可能只翻 playing 标记而平台层没真正出声。
      await _ensureAudioSession();
      await _player.play();
      // 平台层真起来了才算出声：playing 是本地标记，processingState 才是解码器状态。
      _logger.d(
        'Playback started: playing=${_player.playing}, '
        'state=${_player.processingState}, '
        'sessionId=${_player.androidAudioSessionId}',
      );
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

  /// 把当前章节与整本书的队列推给媒体会话。
  void _publishToMediaSession(int index) {
    final handler = _handler;
    if (handler == null) return;
    final book = state.currentBook;
    final items = <MediaItem>[
      for (final chapter in state.chapters)
        MediaMetadata.forChapter(
          book: book,
          chapter: chapter,
          // 队列里只需要 id 唯一；真实 URL 在播放时单独赋给播放器
          audioUrl: '${book?.bookId ?? ''}#${chapter.chapterId}',
        ),
    ];
    if (items.isEmpty) return;
    handler.publishChapter(
      items: items,
      index: index.clamp(0, items.length - 1),
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
      // completed 时 playing 仍为 true，但对用户来说「没在播」
      playing: _player.playing && !state.isCompleted,
      buffering: false,
    );
  }

  /// 同步进度/播放态到媒体会话（通知栏进度条与按钮状态）。
  void _syncMediaSession({bool? buffering}) {
    _handler?.updatePlaybackState(
      playing: _player.playing && !state.isCompleted,
      buffering: buffering ?? state.isBuffering,
      position: _player.position,
      duration: _player.duration ?? state.duration,
    );
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

  /// 播放/暂停切换。
  ///
  /// 恢复会话后音频源尚未装载，直接 `_player.play()` 是空操作（点了没反应）。
  /// 所以「要开始播」这条分支必须走 [play]，由它判断是否需要先装载章节。
  Future<void> togglePlay() async {
    // 已播完（列表最后一章 / 睡眠定时停在章末）：
    // just_audio 此时 playing 仍为 true，直接 pause/play 会变成
    // 「点一下变播放键，再点又没声音」。正确做法是从头重播本章。
    if (state.isCompleted) {
      await _player.seek(Duration.zero);
      state = state.copyWith(isCompleted: false, position: Duration.zero);
      await play();
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await play();
    }
  }

  /// 播放。
  ///
  /// 恢复会话后音频源还没装载（`restoreSession` 只备好章节与进度），
  /// 此时直接 `_player.play()` 是空操作 —— 需要先装载当前章节。
  /// 确保音频会话已配置并激活（音频输出的前提）。
  ///
  /// `just_audio.play()` 内部会调 `audioSession.setActive(true)`，但如果
  /// 会话从未 `configure`，它用的是 audio_session 的兜底配置；
  /// 而且 `setActive` 失败时 `play()` 会**静默不动**（只把 playing 翻回去），
  /// 表现就是「进度条在走但没声音」。
  Future<void> _ensureAudioSession() async {
    if (kIsWeb) return;
    try {
      await AudioSessionConfigurator.apply(mixing: _audioMixing ?? false);
      final session = await AudioSession.instance;
      final ok = await session.setActive(true);
      if (!ok) {
        _logger.w('音频会话激活被拒绝（可能被其他 App 占用音频焦点）');
      }
    } catch (e) {
      _logger.w('音频会话激活失败', error: e);
    }
  }

  Future<void> play() async {
    _playRequested = true;
    await _ensureAudioSession();
    if (state.isCompleted) {
      // 同上：播完后再按播放，应当从头重播，而不是原地不动
      await _player.seek(Duration.zero);
      state = state.copyWith(isCompleted: false, position: Duration.zero);
    }
    if (_player.audioSource == null &&
        state.chapters.isNotEmpty &&
        state.currentChapterIndex < state.chapters.length) {
      await _loadAndPlayChapter(state.currentChapterIndex);
      return;
    }
    await _player.play();
  }

  /// 是否已装载音频源（用于 UI 判断「点播放要不要先加载」）。
  bool get hasLoadedSource => _player.audioSource != null;

  /// 暂停
  Future<void> pause() async {
    _playRequested = false;
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
      return;
    }
    // 已经在本地列表的最后一章：可能是「上游更新了新章节」。
    // 章节列表是进入播放时拉的，长时间收听后会过期；
    // 这里先刷新一次，有新章节就继续播，没有才真正停下。
    if (await _refreshChaptersIfGrown()) {
      await playChapter(state.currentChapterIndex + 1);
    }
  }

  /// 重新拉章节列表；数量变多则替换并返回 true。
  ///
  /// 只增不减：上游删章/改序时保持旧列表，避免把用户正在听的位置搞乱。
  Future<bool> _refreshChaptersIfGrown() async {
    final book = state.currentBook;
    final source = state.currentSource;
    if (book == null || source == null) return false;
    try {
      final fresh = await _parser.getChapterList(source, book);
      if (fresh.length > state.chapters.length) {
        _logger.d('章节有更新: ${state.chapters.length} -> ${fresh.length}');
        state = state.copyWith(chapters: fresh);
        return true;
      }
    } catch (e) {
      _logger.w('刷新章节列表失败', error: e);
    }
    return false;
  }

  /// 供 UI 手动刷新目录（例如用户发现没更新时下拉）。
  Future<bool> refreshChapters() => _refreshChaptersIfGrown();

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
    _interruptionSub?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// 媒体会话处理器（由 `main()` 在 `AudioService.init` 之后注入）。
///
/// 默认 null：单元测试 / 非音频场景不需要真实前台服务。
/// 注入后播放器会把队列与状态发布给它，并接收通知栏的切章意图。
final audioHandlerProvider = Provider<LingtingAudioHandler?>((ref) => null);

/// 全局播放器 Provider
///
/// 同时把播放设置（倍速、跳过片头尾、章节顺序）同步进播放器，
/// 使设置页的改动即时生效。
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final historyRepo = ref.watch(playHistoryRepositoryProvider);
  final notifier = PlayerNotifier(historyRepo);

  // 媒体会话：注入 handler，通知栏/锁屏的「上一章/下一章」才有效
  final handler = ref.watch(audioHandlerProvider);
  if (handler != null) notifier.attachAudioHandler(handler);

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
  notifier.attachBookRepository(ref.watch(bookRepositoryProvider));
  // 字幕层与播放器共享全局 subtitleProvider（播放页/阅读页都在 watch 它）。
  notifier.attachSubtitle(ref.read(subtitleProvider.notifier));
  notifier.startDeviceMonitoring();

  sync();
  ref.listen(playbackSettingsProvider, (_, __) => sync());
  return notifier;
});
