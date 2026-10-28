import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/data/repositories/play_history_repository.dart';
import 'package:soft_sound/features/home/home_page.dart';
import 'package:soft_sound/features/source_manager/source_manager_page.dart';
import 'package:soft_sound/services/lrts_home_api.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 首页「继续收听」卡片（聆阅 `ResumeListenHint`）渲染与交互测试。
///
/// 用真实内存 SQLite 播种播放历史 + 书籍，验证：
/// 1. 有记录 → 显示书名与「第 N 章 · 听到 mm:ss」；
/// 2. 无记录 → 不显示；
/// 3. 已有播放会话 → 不重复打扰。
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
          // 首页推荐流走网络，这里置空避免真实请求
          lrtsHomeProvider.overrideWith((ref) async => const LrtsHomeData.empty()),
          sourcesProvider.overrideWith((ref) => _EmptySources()),
        ],
        child: const MaterialApp(home: HomePage()),
      );

  testWidgets('有播放记录 → 首页显示「继续收听」卡片', (tester) async {
    await bookRepo.addToBookshelf(Book(
      bookId: 'lrts_1',
      sourceId: 'lrts',
      name: '大唐明月',
      narrator: '夙染白',
      coverUrl: 'https://cdn.example/c.jpg',
      detailUrl: '1',
    ));
    await historyRepo.saveProgress(
      bookId: 'lrts_1',
      sourceId: 'lrts',
      chapterIndex: 8,
      chapterName: '第09集_故人相见',
      position: 724655,
      duration: 1079000,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.continuePlay), findsOneWidget);
    expect(find.text('大唐明月'), findsOneWidget);
    expect(find.text('第 9 ${AppStrings.chapterListenedTo}12:04'), findsOneWidget);
    expect(find.text(AppStrings.resumeAction), findsOneWidget);
  });

  testWidgets('无播放记录 → 不显示卡片', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.continuePlay), findsNothing);
    expect(find.text(AppStrings.resumeAction), findsNothing);
  });

  testWidgets('只有「点开就退」的记录 → 不显示卡片', (tester) async {
    await bookRepo.addToBookshelf(Book(
      bookId: 'lrts_1',
      sourceId: 'lrts',
      name: '大唐明月',
      detailUrl: '1',
    ));
    await historyRepo.saveProgress(
      bookId: 'lrts_1',
      sourceId: 'lrts',
      chapterIndex: 0,
      position: 500,
      duration: 1000000,
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.continuePlay), findsNothing);
  });
}

/// 只有一个懒人源（`lrts`）—— 续播匹配需要书源存在，否则会判定「源已删除」。
class _EmptySources extends SourcesNotifier {
  _EmptySources() {
    state = [
      SourceRule.fromJson({
        'sourceId': 'lrts',
        'sourceName': '懒人听书',
        'sourceUrl': 'https://m.lrts.me',
        'sourceType': 'typed-audio',
        'search': {
          'url': 'typed://lrts/search',
          'bookList': 'typed',
          'bookName': 'typed',
          'bookUrl': 'typed',
        },
        'detail': {'chapterList': 'typed'},
        'chapter': {'chapterName': 'typed', 'chapterUrl': 'typed'},
        'audio': {'audioUrl': 'typed'},
      }),
    ];
  }
}
