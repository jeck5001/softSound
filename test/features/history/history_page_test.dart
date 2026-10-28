import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/data/repositories/play_history_repository.dart';
import 'package:soft_sound/features/history/history_page.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 听书记录页测试。
///
/// 背景：这页此前是**写死的空状态**，无论库里有多少条都显示「暂无听书记录」，
/// 而「我的」页却显示「听书记录 3 条」。现在改成真读 `play_history` + `books`。
void main() {
  late AppDatabase db;
  late BookRepository bookRepo;
  late PlayHistoryRepository historyRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bookRepo = BookRepository(db);
    historyRepo = PlayHistoryRepository(db);
  });

  tearDown(() async => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(bookRepo),
          playHistoryRepositoryProvider.overrideWithValue(historyRepo),
        ],
        child: const MaterialApp(home: HistoryPage()),
      );

  Book book({String id = 'lrts_1', String name = '大唐明月'}) => Book(
        bookId: id,
        sourceId: 'lrts',
        name: name,
        coverUrl: 'https://cdn.example/c.jpg',
        detailUrl: '1',
      );

  testWidgets('无记录 → 空状态', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.listenHistory), findsOneWidget);
    expect(find.text(AppStrings.historyEmpty), findsOneWidget);
    expect(find.text(AppStrings.clear), findsNothing);
  });

  testWidgets('有记录 → 显示书名、章节、时间与条数', (tester) async {
    await bookRepo.addToBookshelf(book());
    await historyRepo.saveProgress(
      bookId: 'lrts_1',
      sourceId: 'lrts',
      chapterIndex: 8,
      chapterName: '第09集_故人相见',
      position: 724000,
      duration: 1079000,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('大唐明月'), findsOneWidget);
    expect(find.text('第09集_故人相见'), findsOneWidget);
    expect(find.text('12:04 / 17:59'), findsOneWidget);
    expect(find.text(AppStrings.historyCountText(1)), findsOneWidget);
    expect(find.text(AppStrings.clear), findsOneWidget);
    expect(find.text(AppStrings.historyEmpty), findsNothing);
  });

  testWidgets('章节名为空 → 退回「第 N 章」', (tester) async {
    await bookRepo.addToBookshelf(book());
    await historyRepo.saveProgress(
      bookId: 'lrts_1',
      sourceId: 'lrts',
      chapterIndex: 4,
      position: 60000,
      duration: 600000,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('第 5 章'), findsOneWidget);
  });

  testWidgets('书不在 books 表 → 跳过该条（不显示空白行）', (tester) async {
    await historyRepo.saveProgress(
      bookId: 'ghost',
      sourceId: 'lrts',
      chapterIndex: 3,
      position: 100000,
      duration: 600000,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.historyEmpty), findsOneWidget);
  });

  testWidgets('左滑删除该条并刷新', (tester) async {
    await bookRepo.addToBookshelf(book());
    await historyRepo.saveProgress(
      bookId: 'lrts_1',
      sourceId: 'lrts',
      chapterIndex: 2,
      position: 120000,
      duration: 600000,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('大唐明月'), findsOneWidget);

    await tester.drag(find.text('大唐明月'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.historyEmpty), findsOneWidget);
    expect(await historyRepo.getProgress('lrts_1'), isNull);
  });
}
