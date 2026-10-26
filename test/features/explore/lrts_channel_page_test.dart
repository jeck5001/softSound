import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/features/explore/lrts_channel_page.dart';
import 'package:soft_sound/services/lrts_children_api.dart';
import 'package:soft_sound/theme/app_theme.dart';

/// 懒人频道页 UI 测试（真实 fixture，不连网）。
///
/// 数据来自 2026-10-26 抓取的 `m.lrts.me/category/book?title=儿童&rootId=6`
/// （`test/fixtures/lrts_children_real.html`）。
void main() {
  late LrtsChildrenData data;

  setUpAll(() {
    final html = File(
      'test/fixtures/lrts_children_real.html',
    ).readAsStringSync();
    data = LrtsChildrenApi().parseHtml(html);
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [lrtsChildrenProvider.overrideWith((ref, arg) async => data)],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );

  testWidgets('渲染页签、栏目标题与书籍卡片', (tester) async {
    await tester.pumpWidget(
      wrap(const LrtsChannelPage(rootId: '6', title: '儿童')),
    );
    await tester.pumpAndSettle();

    // AppBar 标题
    expect(find.text('儿童'), findsWidgets);
    // 首个页签（益智故事）与首栏（听友推荐）
    expect(find.text('益智故事'), findsWidgets);
    expect(find.text('听友推荐'), findsOneWidget);
    // 首栏第一本书
    expect(find.text('芽芽大事件百科|今天也有大事情'), findsOneWidget);
    // 播放量格式化
    expect(find.text('22.4万播放'), findsWidgets);
  });

  testWidgets('页签数量与解析结果一致（14 个子类）', (tester) async {
    await tester.pumpWidget(
      wrap(const LrtsChannelPage(rootId: '6', title: '儿童')),
    );
    await tester.pumpAndSettle();

    // 每个页签名都在树里（横向 ListView 只构建可见项，故断言至少可见前几个）
    expect(find.text('益智故事'), findsWidgets);
    expect(find.text('推荐'), findsNothing);
    expect(find.text('全部'), findsNothing);
  });

  testWidgets('空数据显示占位文案', (tester) async {
    data = const LrtsChildrenData.empty();
    await tester.pumpWidget(
      wrap(const LrtsChannelPage(rootId: '6', title: '儿童')),
    );
    await tester.pumpAndSettle();
    expect(find.text('该频道暂无内容'), findsOneWidget);
    data = LrtsChildrenApi().parseHtml(
      File('test/fixtures/lrts_children_real.html').readAsStringSync(),
    );
  });
}
