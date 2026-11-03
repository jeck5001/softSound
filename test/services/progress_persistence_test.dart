import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 播放进度持久化可靠性守卫。
///
/// 背景（2026-11-04 用户反馈「播放记录没保存」）：
/// 排查发现保存链路本身没坏（相关文件近 5 个提交都没动过），
/// 真正的问题是**保存时机太少**：
///
/// 1. 只靠 `Timer.periodic(30s)` —— 用户听不到 30 秒就切走/杀进程，
///    这次收听完全没有记录；
/// 2. `pause()` 不落盘 —— 「听完暂停 → 退出」这条最常见的路径直接丢；
/// 3. `dispose()` 里虽然保存了，但**进程被杀时 dispose 不会执行**。
///
/// 这类 bug 不会报错、不会崩溃，只是"数据悄悄没了"，
/// 所以必须用静态断言守住。
void main() {
  late String src;

  setUpAll(() {
    src = File('lib/services/player_service.dart').readAsStringSync();
  });

  test('PlayerNotifier 监听 App 生命周期', () {
    expect(
      src.contains('with WidgetsBindingObserver'),
      isTrue,
      reason: '不监听生命周期就没有任何可靠的落盘时机',
    );
    expect(src.contains('addObserver(this)'), isTrue);
    expect(src.contains('removeObserver(this)'), isTrue, reason: '避免泄漏');
  });

  test('切到后台时保存进度', () {
    final start = src.indexOf('void didChangeAppLifecycleState');
    expect(start, greaterThan(0));
    final block = src.substring(start, start + 600);
    expect(block.contains('AppLifecycleState.paused'), isTrue);
    expect(
      block.contains('_saveProgress()'),
      isTrue,
      reason: 'paused 是切后台时唯一可靠的落盘时机',
    );
  });

  test('暂停时立即保存进度', () {
    final start = src.indexOf('Future<void> pause()');
    expect(start, greaterThan(0));
    final block = src.substring(start, start + 400);
    expect(
      block.contains('_saveProgress()'),
      isTrue,
      reason: '「听完暂停 → 退出」是最常见路径，等不到 30 秒定时器',
    );
  });

  test('进度保存仍有定时兜底', () {
    expect(
      src.contains('Timer.periodic'),
      isTrue,
      reason: '长时间连续播放也要周期性落盘',
    );
  });

  test('未装载音频源时不写进度（防止把续播位置冲成 0）', () {
    final start = src.indexOf('Future<void> _saveProgress()');
    final block = src.substring(start, start + 700);
    expect(
      block.contains('audioSource == null'),
      isTrue,
      reason: '刚恢复会话时 position=0，写进去会让续播永远从 00:00 开始',
    );
  });

  test('不把占位书名写进库', () {
    expect(src.contains('isPlaceholderBook'), isTrue);
    expect(src.contains('_isRealBook'), isTrue);
  });
}
