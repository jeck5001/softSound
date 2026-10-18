import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/app_theme.dart';
import 'package:soft_sound/theme/subtitle_overlay.dart';

/// 端到端验证：字幕层随播放位置变化而更新。
///
/// 模拟播放器 position 流推进，断言字幕区显示对应文本。
void main() {
  const lrc = '''
[00:00.00]开场白
[00:03.00]正文第一段
[00:06.00]正文第二段
''';

  Widget harness(Widget Function(WidgetRef) onBuild) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: onBuild(ref),
          ),
        ),
      ),
    );
  }

  testWidgets('初始状态无字幕文本', (tester) async {
    await tester.pumpWidget(harness((ref) {
      final subtitle = ref.watch(subtitleProvider);
      return SubtitleOverlay(subtitle: subtitle);
    }));

    expect(find.text('开场白'), findsNothing);
  });

  testWidgets('加载 LRC 后显示首句', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(harness((ref) {
      capturedRef = ref;
      final subtitle = ref.watch(subtitleProvider);
      return SubtitleOverlay(subtitle: subtitle);
    }));

    // 通过 ref 加载字幕
    capturedRef.read(subtitleProvider.notifier).loadLrc(lrc);
    await tester.pumpAndSettle();

    expect(find.text('开场白'), findsOneWidget);
  });

  testWidgets('位置推进到第二句时文本随之更新', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(harness((ref) {
      capturedRef = ref;
      final subtitle = ref.watch(subtitleProvider);
      return SubtitleOverlay(subtitle: subtitle);
    }));

    final notifier = capturedRef.read(subtitleProvider.notifier);
    notifier.loadLrc(lrc);
    await tester.pumpAndSettle();
    expect(find.text('开场白'), findsOneWidget);

    // 推进到 4 秒 → 第二句
    notifier.syncTo(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('正文第一段'), findsOneWidget);
    expect(find.text('开场白'), findsNothing);

    // 推进到 7 秒 → 第三句
    notifier.syncTo(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('正文第二段'), findsOneWidget);
    expect(find.text('正文第一段'), findsNothing);
  });

  testWidgets('无字幕时显示「本集暂无字幕」', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(harness((ref) {
      capturedRef = ref;
      final subtitle = ref.watch(subtitleProvider);
      return SubtitleOverlay(subtitle: subtitle);
    }));

    capturedRef.read(subtitleProvider.notifier).markUnavailable();
    await tester.pumpAndSettle();

    expect(find.textContaining('暂无字幕'), findsOneWidget);
  });

  testWidgets('加载中显示进度与文案', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(harness((ref) {
      capturedRef = ref;
      final subtitle = ref.watch(subtitleProvider);
      return SubtitleOverlay(subtitle: subtitle);
    }));

    capturedRef.read(subtitleProvider.notifier).startLoading();
    // 转圈是无限动画，pumpAndSettle 会超时 → 只做一次 pump
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('字幕加载中'), findsOneWidget);
  });

  testWidgets('句间停顿保留占位不塌陷布局', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(harness((ref) {
      capturedRef = ref;
      final subtitle = ref.watch(subtitleProvider);
      return SubtitleOverlay(subtitle: subtitle);
    }));

    final notifier = capturedRef.read(subtitleProvider.notifier);
    notifier.loadLrc(lrc);
    await tester.pumpAndSettle();

    // 超出末尾区间 → 保留 cues 但文本清空
    notifier.syncTo(const Duration(seconds: 60));
    await tester.pumpAndSettle();

    // 不应显示「暂无字幕」（因为确实有字幕数据，只是此刻在停顿）
    expect(find.textContaining('暂无字幕'), findsNothing);
    expect(find.text('正文第二段'), findsNothing);
  });
}
