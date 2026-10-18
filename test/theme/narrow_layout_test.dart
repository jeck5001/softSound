import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/app/routes.dart';
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_theme.dart';

/// 窄屏（320dp）不溢出回归测试。
///
/// 背景：改名「轻听」时把「我的」页抬头从 4 字加长到 6 字，实测在 320dp 下
/// 把右侧「永久畅听」徽章挤出屏幕 39px —— 说明这几处布局本来就是硬撑的。
/// 定位到的三处（改名前就已存在，360dp 即溢出）：
/// - home_page `_BrandHeader` 眉标 `A U D I O   U N I V E R S E`（23px）
///   → Flexible + FittedBox.scaleDown
/// - profile 等级胶囊行 `距 X 还需 N 分钟`（61px）
///   → Row 改 Wrap，换行而不是吞掉进度信息
/// - profile `_StatCard` 数值行（8.4px ×4）
///   → Spacer 改 Expanded + FittedBox，数值贴左下角、必要时微缩
///
/// 280dp（低于 Android sw320dp / iPhone SE 的最小机宽）仍有残余溢出，
/// 不在本测试覆盖范围内：home_page.dart:386 卡片 Column、profile_page.dart:200 行。
void main() {
  Future<void> boot(WidgetTester tester, double widthDp) async {
    tester.view.physicalSize = Size(widthDp * 3, widthDp * 3 * 2.2);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  for (final widthDp in const [320.0, 360.0, 412.0]) {
    testWidgets('$widthDp${'dp'} 首页与「我的」页均无 RenderFlex 溢出',
        (tester) async {
      await boot(tester, widthDp);

      // 首页
      expect(tester.takeException(), isNull,
          reason: '$widthDp dp 首页不应有布局溢出');
      expect(find.text(AppStrings.appName), findsWidgets,
          reason: '品牌头应正常渲染（缩小不等于消失）');

      // 切到「我的」页
      var dest = find.byIcon(Icons.person_outlined);
      if (dest.evaluate().isEmpty) dest = find.text(AppStrings.navProfile);
      expect(dest.evaluate(), isNotEmpty, reason: '底部导航应可点到「我的」');
      await tester.tap(dest.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(AppStrings.communityLabel), findsWidgets,
          reason: '社区抬头必须真的渲染出来，否则下面的断言是空跑');
      expect(tester.takeException(), isNull,
          reason: '$widthDp dp 「我的」页不应有布局溢出');
    });
  }
}
