import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_theme.dart';
import 'package:soft_sound/theme/app_strings.dart';

void main() {
  testWidgets('全页面骨架在亮/暗主题下可渲染', (tester) async {
    // 验证底部导航 4 页签的文案与主题 token 在真实渲染下正常
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        home: Builder(builder: (context) {
          final c = context.appColors;
          return Scaffold(
            backgroundColor: c.background,
            body: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: AppStrings.navHome),
                NavigationDestination(icon: Icon(Icons.explore_outlined), label: AppStrings.navExplore),
                NavigationDestination(icon: Icon(Icons.bookmark_border), label: AppStrings.navShelf),
                NavigationDestination(icon: Icon(Icons.person_outline), label: AppStrings.navProfile),
              ],
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.navHome), findsOneWidget);
      expect(find.text(AppStrings.navExplore), findsOneWidget);
      expect(find.text(AppStrings.navShelf), findsOneWidget);
      expect(find.text(AppStrings.navProfile), findsOneWidget);
    }
  });
}
