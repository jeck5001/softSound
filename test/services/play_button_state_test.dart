import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:soft_sound/services/player_service.dart';

/// 播放按钮图标状态测试。
///
/// 用户反馈：按钮状态有时候不对（明明没声音，却显示暂停键；点一下变播放键，
/// 再点又没声音）。根因是 just_audio 在**章节播完**后 `playing` 仍为 true，
/// 我们却只用 `isPlaying` 决定图标。
void main() {
  PlayerState state({
    bool isPlaying = false,
    bool isCompleted = false,
    bool isLoading = false,
  }) =>
      PlayerState(
        isPlaying: isPlaying,
        isCompleted: isCompleted,
        isLoading: isLoading,
      );

  group('showPauseIcon', () {
    test('真的在播 → 显示暂停键', () {
      expect(state(isPlaying: true).showPauseIcon, isTrue);
    });

    test('暂停中 → 显示播放键', () {
      expect(state(isPlaying: false).showPauseIcon, isFalse);
    });

    test('播完但仍 playing=true → 必须显示播放键（关键修复）', () {
      final s = state(isPlaying: true, isCompleted: true);
      expect(s.isPlaying, isTrue, reason: 'just_audio 播完后不会自己 pause');
      expect(s.showPauseIcon, isFalse, reason: '没声音了就该显示播放键');
    });

    test('加载中不影响图标语义', () {
      expect(
        state(isPlaying: true, isLoading: true).showPauseIcon,
        isTrue,
      );
    });
  });

  group('copyWith 传递 isCompleted', () {
    test('可置位', () {
      final s = state().copyWith(isCompleted: true);
      expect(s.isCompleted, isTrue);
      expect(s.showPauseIcon, isFalse);
    });

    test('不传时保持原值', () {
      final s = state(isCompleted: true).copyWith(position: Duration.zero);
      expect(s.isCompleted, isTrue);
    });
  });

  group('接线守卫（静态扫描）', () {
    String read(String p) => File(p).readAsStringSync();

    test('播放页与迷你条都用 showPauseIcon', () {
      expect(read('lib/features/player/player_page.dart')
          .contains('playerState.showPauseIcon'), isTrue);
      expect(read('lib/app/routes.dart').contains('state.showPauseIcon'), isTrue,
          reason: '两处图标必须同源，否则会出现「页面显示播放、通知栏显示暂停」');
    });

    test('togglePlay / play 都会处理「已播完」重播', () {
      final src = read('lib/services/player_service.dart');
      final toggle = src.substring(
        src.indexOf('Future<void> togglePlay'),
        src.indexOf('Future<void> play()'),
      );
      expect(toggle.contains('state.isCompleted'), isTrue);
      expect(toggle.contains('_player.seek(Duration.zero)'), isTrue);

      final playBlock = src.substring(
        src.indexOf('Future<void> play()'),
        src.indexOf('bool get hasLoadedSource'),
      );
      expect(playBlock.contains('state.isCompleted'), isTrue,
          reason: '通知栏按播放也要能从头重播');
    });

    test('音频焦点打断会跟随暂停/恢复', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('interruptionEventStream'), isTrue,
          reason: '不监听打断，来电后界面会停在「显示暂停键但没声音」');
      expect(src.contains('_pausedByInterruption'), isTrue);
    });

    test('加载期间按暂停，加载完不会自己响（_playRequested 守卫）', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('_playRequested'), isTrue);
      final start = src.indexOf('Future<void> _loadAndPlayChapter');
      final end = src.indexOf('void _publishToMediaSession');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start), reason: '方法顺序变了，测试片段要跟着改');
      final loadBlock = src.substring(start, end);
      expect(loadBlock.contains('if (!_playRequested)'), isTrue,
          reason: '不判断就会「按了暂停却自己开始播」');
    });

    test('媒体会话按「真实在播」发布播放态', () {
      final src = read('lib/services/player_service.dart');
      expect(
        src.contains('_player.playing && !state.isCompleted'),
        isTrue,
        reason: '否则播完后通知栏仍显示暂停键',
      );
    });
  });
}
