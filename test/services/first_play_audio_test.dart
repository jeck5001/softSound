import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 首播没声音的接线守卫。
///
/// 用户反馈：**第一次播放没有声音，但进度条在走**。
///
/// 关键认知：`just_audio` 的 `positionStream` 是**本地按时间插值**算的
/// （`createPositionStream(steps: 800, ...)`），所以进度条会走
/// **完全不能证明平台层在出声**。真正决定出声的是：
/// 1. `AudioSession` 是否被 `configure`（决定 AudioAttributes / 音频焦点）；
/// 2. `setActive(true)` 是否成功（失败时 `play()` 静默不动，只把 playing 翻回去）。
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('音频会话必须真的被配置', () {
    test('混音开关用可空类型区分「从未配置」与「配置为 false」', () {
      final src = read('lib/services/player_service.dart');
      expect(
        src.contains('bool? _audioMixing'),
        isTrue,
        reason: '初值为 false 时 `if (_audioMixing != audioMixing)` 恒不成立，'
            'AudioSessionConfigurator.apply() 永远不执行',
      );
    });

    test('play() 前显式配置 + 激活音频会话', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('_ensureAudioSession'), isTrue);
      expect(src.contains('session.setActive(true)'), isTrue,
          reason: 'setActive 失败时 play() 会静默不动，必须显式调用并记录结果');
    });

    test('直接调 _player.play() 的路径也要激活（绕过 play()）', () {
      final src = read('lib/services/player_service.dart');
      final loadStart = src.indexOf('Future<void> _loadAndPlayChapter');
      final loadEnd = src.indexOf('void _publishToMediaSession');
      final block = src.substring(loadStart, loadEnd);
      expect(block.contains('_ensureAudioSession()'), isTrue,
          reason: '章节加载路径直接调 _player.play()，不补就是首播没声音');
    });

    test('激活失败会记日志（便于定位「进度条在走但没声音」）', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('音频会话激活被拒绝'), isTrue);
    });
  });

  group('可观测性', () {
    test('播放后打印平台层真实状态', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('androidAudioSessionId'), isTrue,
          reason: 'playing 是本地标记；processingState + sessionId 才反映平台层');
      expect(src.contains('Playback started: playing='), isTrue);
    });
  });

  group('配置器本身', () {
    test('非 Android 平台不配置（避免 iOS/桌面误设 Android 属性）', () {
      final src = read('lib/services/audio_effects.dart');
      expect(src.contains('defaultTargetPlatform != TargetPlatform.android'),
          isTrue);
    });

    test('独占模式要求可听（audibilityEnforced）', () {
      final src = read('lib/services/audio_effects.dart');
      expect(src.contains('audibilityEnforced'), isTrue,
          reason: '不要求可听时，系统可能把音频路由到无声输出');
    });
  });
}
