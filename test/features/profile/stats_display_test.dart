import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/data/repositories/stats_repository.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/listener_stats.dart';
import 'package:soft_sound/theme/app_theme.dart';

/// 端到端验证「我的」页展示真实统计（非硬编码 0）。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// 用真实统计渲染一个最小统计面板（与 profile 页同一数据源）。
  Widget harness(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) {
            final async = ref.watch(listenerStatsProvider);
            final stats = async.valueOrNull ?? const ListenerStats();
            return Scaffold(
              body: Column(
                children: [
                  Text('时长:${stats.formattedListening}'),
                  Text('书架:${stats.bookCount}'),
                  Text('等级:${stats.currentLevel.title}'),
                  Text('进度:${stats.levelProgress.toStringAsFixed(2)}'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('空数据时显示 0 与 1 级', (tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    expect(find.text('时长:0 秒'), findsOneWidget);
    expect(find.text('书架:0'), findsOneWidget);
    expect(find.textContaining('初级听众'), findsOneWidget);
  });

  testWidgets('有真实数据时展示实际时长与书架数', (tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // 造数据：90 分钟收听 + 2 本书
    final stats = StatsRepository(db);
    await stats.addListeningSeconds(90 * 60);
    final books = BookRepository(db);
    await books.addToBookshelf(Book(
      bookId: 'b1',
      sourceId: 'XA',
      name: '书1',
      detailUrl: 'u1',
    ));
    await books.addToBookshelf(Book(
      bookId: 'b2',
      sourceId: 'XA',
      name: '书2',
      detailUrl: 'u2',
    ));

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    expect(find.text('时长:1 小时 30 分钟'), findsOneWidget);
    expect(find.text('书架:2'), findsOneWidget);
    // 90 分钟 → 2 级
    expect(find.textContaining('初学书友'), findsOneWidget);
  });

  testWidgets('时长变化后界面刷新（invalidate 生效）', (tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
    expect(find.text('时长:0 秒'), findsOneWidget);

    // 新增时长并刷新
    await StatsRepository(db).addListeningSeconds(3661); // 1h1m1s
    container.invalidate(listenerStatsProvider);
    await tester.pumpAndSettle();

    expect(find.text('时长:1 小时 1 分钟'), findsOneWidget);
  });

  testWidgets('等级进度随数据变化', (tester) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // 1 级(0) → 2 级(60)，听 30 分钟 → 0.50
    await StatsRepository(db).addListeningSeconds(30 * 60);
    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();

    expect(find.text('进度:0.50'), findsOneWidget);
  });
}
