import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/features/search/search_page.dart';
import 'package:soft_sound/features/source_manager/source_manager_page.dart';
import 'package:soft_sound/services/search_history.dart';

/// 空的源列表（避免测试触发内置源加载与网络）。
class _EmptySources extends SourcesNotifier {
  _EmptySources() {
    state = const <SourceRule>[];
  }
}

/// 搜索历史契约测试（聆阅 `search_history_v1`）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SearchHistoryStore', () {
    test('空存储 → 空列表', () async {
      expect(await SearchHistoryStore().load(), isEmpty);
    });

    test('新增置顶、去重、保持最近在前', () async {
      final s = SearchHistoryStore();
      await s.add('三体');
      await s.add('鬼吹灯');
      await s.add('三体'); // 重复 → 提到最前，不新增第二条
      final list = await s.load();
      expect(list, ['三体', '鬼吹灯']);
    });

    test('空白关键词被忽略', () async {
      final s = SearchHistoryStore();
      expect(await s.add('   '), isEmpty);
      expect(await s.load(), isEmpty);
    });

    test('超过上限截断（保留最近 N 条）', () async {
      final s = SearchHistoryStore();
      for (var i = 1; i <= SearchHistoryStore.maxEntries + 5; i++) {
        await s.add('k$i');
      }
      final list = await s.load();
      expect(list, hasLength(SearchHistoryStore.maxEntries));
      expect(list.first, 'k${SearchHistoryStore.maxEntries + 5}');
      expect(list.contains('k1'), isFalse);
    });

    test('落盘键与聆阅逐字一致，且是 JSON 字符串数组', () async {
      final s = SearchHistoryStore();
      await s.add('三体');
      final prefs = await SharedPreferences.getInstance();
      expect(SearchHistoryStore.storageKey, 'search_history_v1');
      expect(prefs.getString('search_history_v1'), '["三体"]');
    });

    test('损坏数据按空处理，不抛', () async {
      SharedPreferences.setMockInitialValues({
        'search_history_v1': 'not-json',
      });
      expect(await SearchHistoryStore().load(), isEmpty);

      SharedPreferences.setMockInitialValues({
        'search_history_v1': '{"a":1}',
      });
      expect(await SearchHistoryStore().load(), isEmpty);

      SharedPreferences.setMockInitialValues({
        'search_history_v1': '["ok", 123, "", "  "]',
      });
      expect(await SearchHistoryStore().load(), ['ok']);
    });

    test('clear 清空', () async {
      final s = SearchHistoryStore();
      await s.add('a');
      await s.clear();
      expect(await s.load(), isEmpty);
    });

    test('热门搜索词与字节码内联字面量一致（8 个）', () {
      expect(SearchHistoryStore.hotKeywords, [
        '斗破苍穹',
        '三体',
        '盗墓笔记',
        '明朝那些事儿',
        '白夜行',
        '活着',
        '鬼吹灯',
        '解忧杂货店',
      ]);
    });
  });

  group('SearchHistoryController', () {
    test('初始化即读盘，record 后立即可见', () async {
      final c = SearchHistoryController(SearchHistoryStore());
      await Future<void>.delayed(Duration.zero);
      expect(c.state, isEmpty);

      await c.record('三体');
      expect(c.state, ['三体']);

      await c.record('活着');
      expect(c.state.first, '活着');
    });

    test('clear 后状态为空', () async {
      final c = SearchHistoryController(SearchHistoryStore());
      await c.record('x');
      await c.clear();
      expect(c.state, isEmpty);
    });
  });

  group('搜索页空闲态渲染', () {
    Widget wrap() => ProviderScope(
          overrides: [
            sourcesProvider.overrideWith((ref) => _EmptySources()),
            searchHistoryProvider.overrideWith(
              (ref) => SearchHistoryController(SearchHistoryStore()),
            ),
          ],
          child: const MaterialApp(home: SearchPage()),
        );

    testWidgets('无历史：只显示热门搜索，没有「清空」', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('热门搜索'), findsOneWidget);
      expect(find.text('斗破苍穹'), findsOneWidget);
      expect(find.text('搜索历史'), findsNothing);
      expect(find.text('清空'), findsNothing);
    });

    testWidgets('有历史：显示历史词条与「清空」，点「清空」后消失', (tester) async {
      // 用不在热门词表里的关键词，避免与固定热门词重复（三体 两边都有）
      SharedPreferences.setMockInitialValues({
        SearchHistoryStore.storageKey: '["剑来","赘婿"]',
      });
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('搜索历史'), findsOneWidget);
      expect(find.text('剑来'), findsOneWidget);
      expect(find.text('赘婿'), findsOneWidget);

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();

      expect(find.text('搜索历史'), findsNothing);
      expect(find.text('剑来'), findsNothing);
      // 热门搜索仍在（且不受清空影响）
      expect(find.text('热门搜索'), findsOneWidget);
      expect(find.text('斗破苍穹'), findsOneWidget);
    });

    testWidgets('点热门词会填入输入框（触发搜索）', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('鬼吹灯'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, '鬼吹灯');
    });
  });
}
