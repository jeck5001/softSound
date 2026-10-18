import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// 音质枚举 —— 对应聆阅的「选择音质」。
enum AudioQuality {
  low('low', '流畅'),
  standard('standard', '标准'),
  high('high', '高清'),
  lossless('lossless', '无损');

  final String storageKey;
  final String label;

  const AudioQuality(this.storageKey, this.label);

  static AudioQuality fromStorageKey(String? key) {
    if (key == null) return AudioQuality.standard;
    for (final q in AudioQuality.values) {
      if (q.storageKey == key) return q;
    }
    return AudioQuality.standard;
  }
}

/// 播放设置状态 —— 对齐聆阅的 `shu_*` 存储键。
///
/// 覆盖聆阅设置页「🔊 播放与音频」分组下的可持久化选项。
@immutable
class PlaybackSettingsState {
  /// 播放倍速（聆阅范围 0.25 步进）。
  final double speed;

  /// 音质偏好。
  final AudioQuality quality;

  /// 是否启用音量增强（Android LoudnessEnhancer）。
  final bool volumeBoostEnabled;

  /// 音量增强增益（毫贝，聆阅默认档位）。
  final int volumeBoostGain;

  /// 是否与其他 App 同时发声（音频混音）。
  final bool audioMixing;

  /// 是否跳过片头。
  final bool skipIntro;

  /// 片头跳过秒数。
  final int introSeconds;

  /// 是否跳过片尾。
  final bool skipOutro;

  /// 片尾跳过秒数。
  final int outroSeconds;

  /// 章节正序播放（false 为倒序）。
  final bool chapterOrderAscending;

  const PlaybackSettingsState({
    this.speed = 1.0,
    this.quality = AudioQuality.standard,
    this.volumeBoostEnabled = false,
    this.volumeBoostGain = 600,
    this.audioMixing = false,
    this.skipIntro = false,
    this.introSeconds = 30,
    this.outroSeconds = 30,
    this.skipOutro = false,
    this.chapterOrderAscending = true,
  });

  PlaybackSettingsState copyWith({
    double? speed,
    AudioQuality? quality,
    bool? volumeBoostEnabled,
    int? volumeBoostGain,
    bool? audioMixing,
    bool? skipIntro,
    int? introSeconds,
    bool? skipOutro,
    int? outroSeconds,
    bool? chapterOrderAscending,
  }) =>
      PlaybackSettingsState(
        speed: speed ?? this.speed,
        quality: quality ?? this.quality,
        volumeBoostEnabled: volumeBoostEnabled ?? this.volumeBoostEnabled,
        volumeBoostGain: volumeBoostGain ?? this.volumeBoostGain,
        audioMixing: audioMixing ?? this.audioMixing,
        skipIntro: skipIntro ?? this.skipIntro,
        introSeconds: introSeconds ?? this.introSeconds,
        skipOutro: skipOutro ?? this.skipOutro,
        outroSeconds: outroSeconds ?? this.outroSeconds,
        chapterOrderAscending:
            chapterOrderAscending ?? this.chapterOrderAscending,
      );

  /// 倍速显示文案，如 `1.25x`。
  String get speedLabel => '${speed}x';
}

/// 播放设置控制器。
///
/// 存储键前缀与聆阅一致（`shu_`），便于后续与聆阅数据对齐。
class PlaybackSettingsController extends StateNotifier<PlaybackSettingsState> {
  PlaybackSettingsController() : super(const PlaybackSettingsState()) {
    _restore();
  }

  /// 可选倍速档位（对齐聆阅的 0.25 步进）。
  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  static const String _kSpeed = 'shu_playback_speed';
  static const String _kQuality = 'shu_audio_quality';
  static const String _kVolumeBoost = 'shu_volume_boost_enabled';
  static const String _kVolumeGain = 'shu_volume_boost_gain';
  static const String _kAudioMixing = 'shu_audio_mixing';
  static const String _kSkipIntro = 'shu_skip_intro';
  static const String _kIntroSeconds = 'shu_skip_intro_seconds';
  static const String _kSkipOutro = 'shu_skip_outro';
  static const String _kOutroSeconds = 'shu_skip_outro_seconds';
  static const String _kChapterOrder = 'shu_chapter_order_play';

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = PlaybackSettingsState(
        speed: p.getDouble(_kSpeed) ?? 1.0,
        quality: AudioQuality.fromStorageKey(p.getString(_kQuality)),
        volumeBoostEnabled: p.getBool(_kVolumeBoost) ?? false,
        volumeBoostGain: p.getInt(_kVolumeGain) ?? 600,
        audioMixing: p.getBool(_kAudioMixing) ?? false,
        skipIntro: p.getBool(_kSkipIntro) ?? false,
        introSeconds: p.getInt(_kIntroSeconds) ?? 30,
        skipOutro: p.getBool(_kSkipOutro) ?? false,
        outroSeconds: p.getInt(_kOutroSeconds) ?? 30,
        chapterOrderAscending: p.getBool(_kChapterOrder) ?? true,
      );
    } catch (e) {
      debugPrint('恢复播放设置失败: $e');
    }
  }

  Future<void> setSpeed(double v) async {
    state = state.copyWith(speed: v);
    await _put((p) => p.setDouble(_kSpeed, v));
  }

  Future<void> setQuality(AudioQuality v) async {
    state = state.copyWith(quality: v);
    await _put((p) => p.setString(_kQuality, v.storageKey));
  }

  Future<void> setVolumeBoostEnabled(bool v) async {
    state = state.copyWith(volumeBoostEnabled: v);
    await _put((p) => p.setBool(_kVolumeBoost, v));
  }

  Future<void> setVolumeBoostGain(int v) async {
    state = state.copyWith(volumeBoostGain: v);
    await _put((p) => p.setInt(_kVolumeGain, v));
  }

  Future<void> setAudioMixing(bool v) async {
    state = state.copyWith(audioMixing: v);
    await _put((p) => p.setBool(_kAudioMixing, v));
  }

  Future<void> setSkipIntro(bool v) async {
    state = state.copyWith(skipIntro: v);
    await _put((p) => p.setBool(_kSkipIntro, v));
  }

  Future<void> setIntroSeconds(int v) async {
    state = state.copyWith(introSeconds: v);
    await _put((p) => p.setInt(_kIntroSeconds, v));
  }

  Future<void> setSkipOutro(bool v) async {
    state = state.copyWith(skipOutro: v);
    await _put((p) => p.setBool(_kSkipOutro, v));
  }

  Future<void> setOutroSeconds(int v) async {
    state = state.copyWith(outroSeconds: v);
    await _put((p) => p.setInt(_kOutroSeconds, v));
  }

  Future<void> setChapterOrderAscending(bool v) async {
    state = state.copyWith(chapterOrderAscending: v);
    await _put((p) => p.setBool(_kChapterOrder, v));
  }

  Future<void> _put(Future<void> Function(SharedPreferences) fn) async {
    try {
      await fn(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('保存播放设置失败: $e');
    }
  }

  /// 计算「跳过片头」的目标位置；未启用或时长不足时返回 null。
  Duration? introSkipTarget(Duration duration) {
    if (!state.skipIntro || duration.inSeconds <= state.introSeconds) {
      return null;
    }
    return Duration(seconds: state.introSeconds);
  }

  /// 判断当前位置是否已进入「片尾」，用于自动切下一章。
  bool isInOutro(Duration position, Duration duration) {
    if (!state.skipOutro || duration.inSeconds <= state.outroSeconds) {
      return false;
    }
    return position.inSeconds >= duration.inSeconds - state.outroSeconds;
  }

  /// 增益档位显示文案，如 `+600 mB`。
  String gainLabel() => '+${state.volumeBoostGain} mB';

  /// 片头/片尾设置摘要，用于设置页副标题。
  String get introOutroSummary {
    if (!state.skipIntro && !state.skipOutro) return AppStrings.skipIntroNote;
    final parts = <String>[];
    if (state.skipIntro) parts.add('${AppStrings.skipIntro} ${state.introSeconds}s');
    if (state.skipOutro) parts.add('${AppStrings.skipOutro} ${state.outroSeconds}s');
    return parts.join(' · ');
  }
}

/// 播放设置 Provider。
final playbackSettingsProvider =
    StateNotifierProvider<PlaybackSettingsController, PlaybackSettingsState>(
  (ref) => PlaybackSettingsController(),
);
