import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// AudioDeviceType 等音频设备 API 在 audio_session 中标注为 experimental。
// ignore_for_file: experimental_member_use

/// 原生音效桥（音量增强）。
///
/// Dart 侧 `just_audio` 的 `setVolume()` 上限为 1.0，无法真正放大音量；
/// 真正的响度提升必须走 Android 原生 `LoudnessEnhancer`
/// （对应聆阅的「音量增强」，无需 ROOT）。
///
/// 对应原生实现见 `android/.../MainActivity.kt`。
/// 非 Android 平台或调用失败时优雅降级（返回 false），不影响播放。
class AudioEffects {
  AudioEffects({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'soft_sound/audio_effects';

  final MethodChannel _channel;

  /// 缓存「是否支持」，避免重复探测。
  bool? _supported;

  /// 当前增益（毫贝）；0 表示未启用。
  int _currentGainMb = 0;

  int get currentGainMb => _currentGainMb;

  /// 原生是否支持音量增强。
  ///
  /// 非 Android 平台直接返回 false（不发起调用）。
  Future<bool> isSupported() async {
    if (_supported != null) return _supported!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _supported = false;
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      _supported = result ?? false;
    } on PlatformException catch (e) {
      debugPrint('探测音量增强支持失败: ${e.message}');
      _supported = false;
    } on MissingPluginException {
      // 未实现原生侧（如桌面构建）→ 静默降级
      _supported = false;
    }
    return _supported!;
  }

  /// 启用音量增强并设置增益。
  ///
  /// [gainMb] 毫贝，建议 0–1500（约 +0–15 dB）。
  /// 返回是否真正生效。
  Future<bool> enable(int gainMb) async {
    if (!await isSupported()) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'enable',
        {'gainMb': gainMb},
      );
      if (ok ?? false) _currentGainMb = gainMb;
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('启用音量增强失败: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 调整增益（未启用则先启用）。
  Future<bool> setGain(int gainMb) async {
    if (!await isSupported()) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'setGain',
        {'gainMb': gainMb},
      );
      if (ok ?? false) _currentGainMb = gainMb;
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('设置增益失败: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 关闭并释放原生音效资源。
  Future<void> disable() async {
    _currentGainMb = 0;
    if (!await isSupported()) return;
    try {
      await _channel.invokeMethod<bool>('disable');
    } on PlatformException catch (e) {
      debugPrint('关闭音量增强失败: ${e.message}');
    } on MissingPluginException {
      // 忽略
    }
  }
}

/// 音频会话配置（混音 / 音频焦点）。
///
/// 对应聆阅的「与其他App同时播放」开关：
/// - 关闭（默认）：播放时独占音频焦点，其他 App 会暂停；
/// - 开启：使用 `usage: game` 语义，允许与音乐/导航等 App 同时发声。
///
/// 实现基于 `audio_session`：切换 `AndroidAudioUsage` 会改变
/// Android 的音频焦点策略，从而决定是否打断其他 App。
class AudioSessionConfigurator {
  /// 应用音频会话配置。
  ///
  /// [mixing] 为 true 时允许与其他 App 同时播放。
  static Future<void> apply({required bool mixing}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // 非 Android 平台由各系统自行处理混音策略
      return;
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: mixing
            ? AVAudioSessionCategoryOptions.mixWithOthers
            : null,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          // game 语义不请求独占焦点 → 可与他人共存
          usage: mixing ? AndroidAudioUsage.game : AndroidAudioUsage.media,
          // 绝不能用 `audibilityEnforced`。
          //
          // `AUDIO_FLAG_AUDIBILITY_ENFORCED` 是**紧急广播/报警音**专用标志：
          // 强制输出到扬声器并**忽略用户的音量与静音设置**。
          // 曾在这里加它想「确保能出声」，结果用户反馈
          // 「音量关到 0 还是出声、关不掉」（2026-11-02）。
          // 普通媒体播放必须用 `none`，让系统的音量键/静音真正生效。
          flags: AndroidAudioFlags.none,
        ),
        // 混音时不因其他 App 播放而暂停；独占时暂停
        androidWillPauseWhenDucked: !mixing,
        androidAudioFocusGainType: mixing
            ? AndroidAudioFocusGainType.gainTransientMayDuck
            : AndroidAudioFocusGainType.gain,
      ));
      debugPrint('音频会话已配置: mixing=$mixing');
    } catch (e) {
      // 配置失败不影响播放
      debugPrint('配置音频会话失败: $e');
    }
  }
}

/// 音频设备监听（蓝牙/耳机断开自动暂停）。
///
/// 对应聆阅的提示：`蓝牙/耳机已断开，已暂停播放`。
///
/// 实现基于 `audio_session` 的 `becomingNoisyEventStream`（有线耳机拔出、
/// 蓝牙断开时系统会广播）与 `devicesChangedEventStream`（设备集合变化）。
class AudioDeviceMonitor {
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioDevicesChangedEvent>? _devicesSub;

  /// 是否正在监听。
  bool get isListening => _noisySub != null || _devicesSub != null;

  /// 开始监听设备变化。
  ///
  /// [onDisconnected] 在蓝牙/耳机断开时回调（调用方应暂停播放并提示）。
  Future<void> start({required void Function() onDisconnected}) async {
    await stop();

    if (kIsWeb) return;

    try {
      final session = await AudioSession.instance;

      // 1) becoming noisy：有线耳机拔出、蓝牙主动断开时系统广播
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        debugPrint('音频设备变为 noisy（耳机拔出/蓝牙断开）');
        onDisconnected();
      });

      // 2) 设备移除：事件直接给出被移除的设备集合
      _devicesSub = session.devicesChangedEventStream.listen((event) {
        final lost = event.devicesRemoved;
        if (lost.isEmpty) return;

        if (lost.any(_isBluetooth)) {
          debugPrint('蓝牙设备已断开: ${lost.map((d) => d.name).join(', ')}');
          onDisconnected();
        }
      });
    } catch (e) {
      debugPrint('启动音频设备监听失败: $e');
    }
  }

  /// 停止监听。
  Future<void> stop() async {
    await _noisySub?.cancel();
    await _devicesSub?.cancel();
    _noisySub = null;
    _devicesSub = null;
  }

  // AudioDeviceType 被标注为 experimental；它是判断蓝牙断开唯一可靠的枚举，
  // 且已用 try 兜底平台差异，因此这里显式忽略告警。
  static bool _isBluetooth(AudioDevice d) {
    try {
      final t = d.type;
      return t == AudioDeviceType.bluetoothA2dp ||
              t == AudioDeviceType.bluetoothSco ||
              t == AudioDeviceType.bluetoothLe;
    } catch (_) {
      // 退化为按名称判断
      return d.name.toLowerCase().contains('bluetooth');
    }
  }
}
