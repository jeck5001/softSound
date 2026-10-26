import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_strings.dart';

/// 音质枚举 —— 对应聆阅的「选择音质」。
///
/// 取值与文案逐字来自聆阅字节码 #225xx（下载/播放页的音质选项数组）：
///
/// | 存储值 | 标签 | 说明 |
/// |---|---|---|
/// | `128` | 标准 | 128kbps · 流畅省流量 |
/// | `320` | 高品 | 320kbps · 高清音质 |
/// | `flac` | 无损 | FLAC · 原音无损 |
///
/// 旧实现用的 `low/standard/high/lossless` 与聆阅落盘值不兼容，
/// 这里改为聆阅原值，并保留旧值作为读取时的别名（向后兼容既有用户数据）。
enum AudioQuality {
  standard('128', '标准', '128kbps · 流畅省流量'),
  high('320', '高品', '320kbps · 高清音质'),
  lossless('flac', '无损', 'FLAC · 原音无损');

  final String storageKey;
  final String label;
  final String description;

  const AudioQuality(this.storageKey, this.label, this.description);

  /// 旧版本落盘值 → 新枚举（`low→standard`、`high→high`、`lossless→lossless`）。
  static const Map<String, AudioQuality> _legacyAliases = {
    'low': AudioQuality.standard,
    'standard': AudioQuality.standard,
    'high': AudioQuality.high,
    'lossless': AudioQuality.lossless,
  };

  static AudioQuality fromStorageKey(String? key) {
    if (key == null) return AudioQuality.standard;
    for (final q in AudioQuality.values) {
      if (q.storageKey == key) return q;
    }
    return _legacyAliases[key] ?? AudioQuality.standard;
  }
}

/// 播放设置状态 —— 对齐聆阅的 `tingshu_*` 存储键。
///
/// 覆盖聆阅设置页「🔊 播放与音频」分组下的可持久化选项。
///
/// 键名与取值形态均以 2026-10-26 字节码 #16799（21 个键的批量读取）
/// 与 #16823/#16829/#17021/#17023（各键 setter）为准：
///
/// | 键 | 形态 | 说明 |
/// |---|---|---|
/// | `tingshu_playback_speed` | 字符串数字 | `String(speed)` |
/// | `tingshu_audio_quality` | 字符串 | `standard` / `high` / `flac` 等 |
/// | `tingshu_skip_intro` | **数字秒** | `0..180`，**0 表示关闭** |
/// | `tingshu_skip_outro` | **数字秒** | 同上 |
/// | `tingshu_chapter_order` | 字符串 | `asc` / `desc` |
/// | `tingshu_boost_level` | 字符串 | 增益档位 |
/// | `tingshu_volume_boost_enabled` / `_gain` | 布尔 / 数字 | |
/// | `tingshu_audio_mixing` | 布尔 | |
/// | `tingshu_animations_enabled` | 布尔 | |
///
/// 注意：**不存在 `shu_` 前缀的键**（旧文档的写法是错的，已在代码中纠正）。
/// 跳片头/片尾在聆阅里是「秒数」而非「开关 + 秒数」两个键，
/// 因此这里对外仍暴露 [PlaybackSettingsState.skipIntro] 布尔便利属性，
/// 但落盘统一写秒数（0 = 关），便于与聆阅数据互通。
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
/// 存储键与聆阅逐字一致（`tingshu_*`），便于与聆阅数据互通。
class PlaybackSettingsController extends StateNotifier<PlaybackSettingsState> {
  PlaybackSettingsController() : super(const PlaybackSettingsState()) {
    _restore();
  }

  /// 可选倍速档位（对齐聆阅的 0.25 步进）。
  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  /// 存储键（聆阅字节码逐字，2026-10-26 复核）。
  static const String kSpeedKey = 'tingshu_playback_speed';
  static const String kQualityKey = 'tingshu_audio_quality';
  static const String kVolumeBoostKey = 'tingshu_volume_boost_enabled';
  static const String kVolumeGainKey = 'tingshu_volume_boost_gain';
  static const String kAudioMixingKey = 'tingshu_audio_mixing';
  static const String kSkipIntroKey = 'tingshu_skip_intro';
  static const String kSkipOutroKey = 'tingshu_skip_outro';
  static const String kChapterOrderKey = 'tingshu_chapter_order';
  static const String kAnimationsKey = 'tingshu_animations_enabled';

  /// 跳片头/片尾秒数的合法范围（字节码 `Math.min(180, Math.max(0, x))`）。
  static const int skipSecondsMax = 180;

  /// 章节顺序的存储值（字节码 `'asc'` / `'desc'`）。
  static const String orderAsc = 'asc';
  static const String orderDesc = 'desc';

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      // 聆阅把倍速存成字符串数字（`String(speed)`），这里兼容数字与字符串两种。
      final rawSpeed = p.get(kSpeedKey);
      final speed = rawSpeed is num
          ? rawSpeed.toDouble()
          : double.tryParse('${rawSpeed ?? ''}') ?? 1.0;
      // 跳片头/片尾：聆阅存的是**秒数**，0 表示关闭。
      final intro = _clampSkipSeconds(_readInt(p, kSkipIntroKey));
      final outro = _clampSkipSeconds(_readInt(p, kSkipOutroKey));
      final order = p.getString(kChapterOrderKey) ?? '';

      state = PlaybackSettingsState(
        speed: speed <= 0 ? 1.0 : speed,
        quality: AudioQuality.fromStorageKey(p.getString(kQualityKey)),
        volumeBoostEnabled: p.getBool(kVolumeBoostKey) ?? false,
        volumeBoostGain: p.getInt(kVolumeGainKey) ?? 600,
        audioMixing: p.getBool(kAudioMixingKey) ?? false,
        skipIntro: intro > 0,
        introSeconds: intro > 0 ? intro : 30,
        skipOutro: outro > 0,
        outroSeconds: outro > 0 ? outro : 30,
        chapterOrderAscending: order != orderDesc,
      );
    } catch (e) {
      debugPrint('恢复播放设置失败: $e');
    }
  }

  /// 读取整数键（兼容曾被写成字符串的历史数据）。
  static int _readInt(SharedPreferences p, String key) {
    final v = p.get(key);
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is bool) return v ? 1 : 0;
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  /// 秒数钳制到 `0..180`（字节码 `Math.min(180, Math.max(0, x))`）。
  static int _clampSkipSeconds(int v) {
    if (v < 0) return 0;
    if (v > skipSecondsMax) return skipSecondsMax;
    return v;
  }

  Future<void> setSpeed(double v) async {
    state = state.copyWith(speed: v);
    // 聆阅存字符串（`String(speed)`），照搬以便互通。
    await _put((p) => p.setString(kSpeedKey, '$v'));
  }

  Future<void> setQuality(AudioQuality v) async {
    state = state.copyWith(quality: v);
    await _put((p) => p.setString(kQualityKey, v.storageKey));
  }

  Future<void> setVolumeBoostEnabled(bool v) async {
    state = state.copyWith(volumeBoostEnabled: v);
    await _put((p) => p.setBool(kVolumeBoostKey, v));
  }

  Future<void> setVolumeBoostGain(int v) async {
    state = state.copyWith(volumeBoostGain: v);
    await _put((p) => p.setInt(kVolumeGainKey, v));
  }

  Future<void> setAudioMixing(bool v) async {
    state = state.copyWith(audioMixing: v);
    await _put((p) => p.setBool(kAudioMixingKey, v));
  }

  Future<void> setSkipIntro(bool v) async {
    state = state.copyWith(skipIntro: v);
    // 关闭时写 0（聆阅语义：秒数为 0 即关闭）。
    await _put((p) => p.setInt(kSkipIntroKey, v ? state.introSeconds : 0));
  }

  Future<void> setIntroSeconds(int v) async {
    final secs = _clampSkipSeconds(v);
    state = state.copyWith(introSeconds: secs);
    await _put(
        (p) => p.setInt(kSkipIntroKey, state.skipIntro ? secs : 0));
  }

  Future<void> setSkipOutro(bool v) async {
    state = state.copyWith(skipOutro: v);
    await _put((p) => p.setInt(kSkipOutroKey, v ? state.outroSeconds : 0));
  }

  Future<void> setOutroSeconds(int v) async {
    final secs = _clampSkipSeconds(v);
    state = state.copyWith(outroSeconds: secs);
    await _put(
        (p) => p.setInt(kSkipOutroKey, state.skipOutro ? secs : 0));
  }

  Future<void> setChapterOrderAscending(bool v) async {
    state = state.copyWith(chapterOrderAscending: v);
    await _put((p) => p.setString(kChapterOrderKey, v ? orderAsc : orderDesc));
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
