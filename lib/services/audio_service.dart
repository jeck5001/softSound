import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

import '../data/models/book.dart';
import '../data/models/chapter.dart';
import '../data/models/play_state.dart';
import '../data/models/source_rule.dart';
import 'source_parser.dart';

/// 音频播放服务
/// 管理音频播放器状态，提供播放控制功能
class AudioPlayerService {
  final AudioPlayer _player;
  final SourceParser _parser;
  final Logger _logger = Logger();

  Book? _currentBook;
  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  SourceRule? _currentSource;

  AudioPlayerService({
    AudioPlayer? player,
    SourceParser? parser,
  })  : _player = player ?? AudioPlayer(),
        _parser = parser ?? SourceParser();

  /// 当前播放的书籍
  Book? get currentBook => _currentBook;

  /// 章节列表
  List<Chapter> get chapters => _chapters;

  /// 当前章节索引
  int get currentChapterIndex => _currentChapterIndex;

  /// 当前章节
  Chapter? get currentChapter =>
      _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;

  /// 播放器实例
  AudioPlayer get player => _player;

  /// 播放状态流
  Stream<PlayState> get playStateStream {
    return _player.positionStream.map((position) {
      return PlayState(
        bookId: _currentBook?.bookId,
        chapterId: currentChapter?.chapterId,
        chapterIndex: _currentChapterIndex,
        position: position.inMilliseconds,
        duration: _player.duration?.inMilliseconds ?? 0,
        speed: _player.speed,
        isPlaying: _player.playing,
      );
    });
  }

  /// 初始化播放（加载书籍和章节列表）
  Future<void> initBook(SourceRule source, Book book, List<Chapter> chapters) async {
    _currentSource = source;
    _currentBook = book;
    _chapters = chapters;
    _currentChapterIndex = 0;

    if (chapters.isNotEmpty) {
      await _loadChapter(0);
    }
  }

  /// 播放指定章节
  Future<void> playChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;

    _currentChapterIndex = index;
    await _loadChapter(index);
    await _player.play();
  }

  /// 加载章节音频
  Future<void> _loadChapter(int index) async {
    if (_currentSource == null || index < 0 || index >= _chapters.length) return;

    final chapter = _chapters[index];
    String? audioUrl = chapter.audioUrl;

    if (audioUrl == null || audioUrl.isEmpty) {
      audioUrl = await _parser.getAudioUrl(_currentSource!, chapter);
      if (audioUrl != null) {
        _chapters[index] = chapter.copyWith(audioUrl: audioUrl);
      }
    }

    if (audioUrl == null) {
      _logger.e('Failed to get audio url for chapter: ${chapter.name}');
      return;
    }

    try {
      final headers = <String, String>{
        ..._currentSource!.header ?? {},
        ..._currentSource!.audio.header ?? {},
      };

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          headers: headers,
        ),
      );

      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          _onChapterComplete();
        }
      });
    } catch (e) {
      _logger.e('Failed to load audio', error: e);
    }
  }

  /// 章节播放完成处理
  void _onChapterComplete() {
    if (_currentChapterIndex < _chapters.length - 1) {
      playChapter(_currentChapterIndex + 1);
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
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  /// 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  /// 上一章
  Future<void> previousChapter() async {
    if (_currentChapterIndex > 0) {
      await playChapter(_currentChapterIndex - 1);
    }
  }

  /// 下一章
  Future<void> nextChapter() async {
    if (_currentChapterIndex < _chapters.length - 1) {
      await playChapter(_currentChapterIndex + 1);
    }
  }

  /// 快进（默认15秒）
  Future<void> fastForward({Duration duration = const Duration(seconds: 15)}) async {
    final currentPosition = _player.position;
    final targetPosition = currentPosition + duration;
    final maxPosition = _player.duration ?? Duration.zero;
    await _player.seek(targetPosition > maxPosition ? maxPosition : targetPosition);
  }

  /// 快退（默认15秒）
  Future<void> rewind({Duration duration = const Duration(seconds: 15)}) async {
    final currentPosition = _player.position;
    final targetPosition = currentPosition - duration;
    await _player.seek(targetPosition < Duration.zero ? Duration.zero : targetPosition);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// AudioPlayerService Provider
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});
