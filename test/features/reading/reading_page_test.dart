import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_theme.dart';
import 'package:soft_sound/theme/subtitle_overlay.dart';

/// 验证阅读模式复用的字幕展示组件与同步逻辑。
///
/// 说明：ReadingPage 直接依赖 playerProvider（会构造 AudioPlayer），
/// 因此这里聚焦其复用的展示组件与状态机 —— 与页面共用同一份数据源。
void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );

  const lrc = '''
[00:00.00]第一句话
[00:05.00]第二句话
[00:10.00]第三句话
''';

  group('AppSubtitlePlaceholder（阅读模式占位）', () {
    testWidgets('加载中显示进度与文案', (tester) async {
      await tester.pumpWidget(wrap(const AppSubtitlePlaceholder(
        subtitle: SubtitleState(isLoading: true),
      )));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('字幕加载中'), findsOneWidget);
    });

    testWidgets('确认无字幕时提示「本集暂无字幕」', (tester) async {
      await tester.pumpWidget(wrap(const AppSubtitlePlaceholder(
        subtitle: SubtitleState(unavailable: true),
      )));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.subtitleNoText), findsOneWidget);
    });

    testWidgets('未获取字幕时给出说明', (tester) async {
      await tester.pumpWidget(wrap(const AppSubtitlePlaceholder(
        subtitle: SubtitleState(),
      )));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.subtitleUnavailable), findsOneWidget);
    });
  });

  group('阅读模式字幕同步', () {
    testWidgets('加载后展示全部句子并高亮当前句', (tester) async {
      late WidgetRef captured;

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(builder: (context, ref, _) {
          captured = ref;
          final sub = ref.watch(subtitleProvider);
          return Scaffold(
            body: Column(
              children: [
                for (var i = 0; i < sub.cues.length; i++)
                  Text(
                    sub.cues[i].text,
                    style: TextStyle(
                      fontWeight: i == sub.activeIndex
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
              ],
            ),
          );
        }),
      )));

      captured.read(subtitleProvider.notifier).loadLrc(lrc);
      await tester.pumpAndSettle();

      // 阅读模式展示全部句子（非仅当前句）
      expect(find.text('第一句话'), findsOneWidget);
      expect(find.text('第二句话'), findsOneWidget);
      expect(find.text('第三句话'), findsOneWidget);
      expect(captured.read(subtitleProvider).activeIndex, 0);
    });

    testWidgets('位置推进后高亮索引随之变化', (tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(builder: (context, ref, _) {
          captured = ref;
          return const Scaffold(body: SizedBox());
        }),
      )));

      final n = captured.read(subtitleProvider.notifier);
      n.loadLrc(lrc);
      await tester.pumpAndSettle();
      expect(captured.read(subtitleProvider).activeIndex, 0);

      n.syncTo(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(captured.read(subtitleProvider).activeIndex, 1);

      n.syncTo(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(captured.read(subtitleProvider).activeIndex, 2);
    });

    testWidgets('点击句子所需的 cue.start 正确（用于 seekTo）', (tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(builder: (context, ref, _) {
          captured = ref;
          return const Scaffold(body: SizedBox());
        }),
      )));

      captured.read(subtitleProvider.notifier).loadLrc(lrc);
      await tester.pumpAndSettle();

      final cues = captured.read(subtitleProvider).cues;
      expect(cues[0].start, Duration.zero);
      expect(cues[1].start, const Duration(seconds: 5));
      expect(cues[2].start, const Duration(seconds: 10));
    });

    testWidgets('无字幕时 cues 为空（触发占位分支）', (tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(builder: (context, ref, _) {
          captured = ref;
          return const Scaffold(body: SizedBox());
        }),
      )));

      captured.read(subtitleProvider.notifier).markUnavailable();
      await tester.pumpAndSettle();

      final sub = captured.read(subtitleProvider);
      expect(sub.cues, isEmpty);
      expect(sub.unavailable, isTrue);
    });
  });

  group('阅读模式文案', () {
    test('关键文案取自聆阅', () {
      expect(AppStrings.readingMode, '阅读');
      expect(AppStrings.readAloud, '朗读');
      expect(AppStrings.readingModePaused, contains('朗读'));
      expect(AppStrings.readingModePaused, contains('暂停'));
    });
  });
}
