import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_theme.dart';
import 'package:soft_sound/theme/app_widgets.dart';
import 'package:soft_sound/theme/subtitle_overlay.dart';

void main() {
  /// 把被测组件放进带设计系统的 MaterialApp，模拟真实渲染环境。
  Widget wrap(Widget child, {AppAccent accent = AppAccent.classicPurple,
      Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.dark(accent: accent)
          : AppTheme.light(accent: accent),
      home: Scaffold(body: child),
    );
  }

  group('AppEmptyState', () {
    testWidgets('渲染图标/标题/说明', (tester) async {
      await tester.pumpWidget(wrap(const AppEmptyState(
        icon: Icons.library_books_outlined,
        title: AppStrings.shelfEmpty,
        description: AppStrings.shelfEmptyHint,
      )));

      expect(find.text(AppStrings.shelfEmpty), findsOneWidget);
      expect(find.text(AppStrings.shelfEmptyHint), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
    });

    testWidgets('有 actionLabel 时渲染按钮并可点击', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(AppEmptyState(
        icon: Icons.search,
        title: AppStrings.shelfEmpty,
        actionLabel: AppStrings.shelfExplore,
        onAction: () => tapped = true,
      )));

      expect(find.text(AppStrings.shelfExplore), findsOneWidget);
      await tester.tap(find.text(AppStrings.shelfExplore));
      expect(tapped, isTrue);
    });

    testWidgets('无描述时不渲染多余文本', (tester) async {
      await tester.pumpWidget(wrap(const AppEmptyState(
        icon: Icons.info,
        title: 'only-title',
      )));
      expect(find.text('only-title'), findsOneWidget);
    });
  });

  group('AppErrorState', () {
    testWidgets('渲染消息与重试按钮', (tester) async {
      var retried = false;
      await tester.pumpWidget(wrap(AppErrorState(
        message: AppStrings.loadFailedNetwork,
        onRetry: () => retried = true,
      )));

      expect(find.text(AppStrings.loadFailedNetwork), findsOneWidget);
      expect(find.text(AppStrings.reload), findsOneWidget);

      await tester.tap(find.text(AppStrings.reload));
      expect(retried, isTrue);
    });

    testWidgets('无 onRetry 时不渲染按钮', (tester) async {
      await tester.pumpWidget(wrap(const AppErrorState(
        message: AppStrings.networkError,
      )));
      expect(find.text(AppStrings.networkError), findsOneWidget);
      expect(find.text(AppStrings.reload), findsNothing);
    });
  });

  group('AppLoadingState', () {
    testWidgets('显示转圈与文案', (tester) async {
      await tester.pumpWidget(wrap(const AppLoadingState(
        message: AppStrings.searching,
      )));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(AppStrings.searching), findsOneWidget);
    });
  });

  group('AppSectionHeader', () {
    testWidgets('渲染标题', (tester) async {
      await tester.pumpWidget(wrap(const AppSectionHeader(
        title: AppStrings.navRanking,
      )));
      expect(find.text(AppStrings.navRanking), findsOneWidget);
    });

    testWidgets('有 actionLabel 时可点击', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(AppSectionHeader(
        title: AppStrings.categoryHot,
        actionLabel: AppStrings.viewDetail,
        onAction: () => tapped = true,
      )));

      expect(find.text(AppStrings.viewDetail), findsOneWidget);
      await tester.tap(find.text(AppStrings.viewDetail));
      expect(tapped, isTrue);
    });
  });

  group('SubtitleOverlay', () {
    testWidgets('无字幕时显示「本集暂无字幕」', (tester) async {
      await tester.pumpWidget(wrap(const SubtitleOverlay(
        subtitle: SubtitleState(unavailable: true),
      )));
      expect(find.text(AppStrings.subtitleNoText), findsOneWidget);
    });

    testWidgets('加载中显示「字幕加载中…」', (tester) async {
      await tester.pumpWidget(wrap(const SubtitleOverlay(
        subtitle: SubtitleState(isLoading: true),
      )));
      expect(find.text(AppStrings.subtitleLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('有字幕时显示字幕文本', (tester) async {
      await tester.pumpWidget(wrap(const SubtitleOverlay(
        subtitle: SubtitleState(text: '第一句字幕'),
      )));
      expect(find.text('第一句字幕'), findsOneWidget);
    });
  });

  group('主题在真实渲染下生效', () {
    testWidgets('亮/暗模式下 scaffold 背景色跟随 token', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(),
        brightness: Brightness.dark,
      ));

      final theme = Theme.of(tester.element(find.byType(SizedBox)));
      expect(theme.brightness, Brightness.dark);
      expect(theme.extension<AppColors>(), isNotNull);
      expect(
        theme.extension<AppColors>()!.primary,
        AppAccent.classicPurple.dark,
      );
    });

    testWidgets('切换主题色会改变 primary', (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(), accent: AppAccent.green));
      final theme = Theme.of(tester.element(find.byType(SizedBox)));
      expect(theme.extension<AppColors>()!.primary, AppAccent.green.light);
    });

    testWidgets('context.appColors 在组件树内可用', (tester) async {
      late AppColors captured;
      await tester.pumpWidget(wrap(Builder(builder: (context) {
        captured = context.appColors;
        return const SizedBox();
      })));
      expect(captured.primary, AppAccent.classicPurple.light);
    });
  });
}
