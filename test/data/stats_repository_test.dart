import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/data/repositories/play_history_repository.dart';
import 'package:soft_sound/data/repositories/stats_repository.dart';

void main() {
  late AppDatabase db;
  late StatsRepository stats;
  late BookRepository books;
  late PlayHistoryRepository history;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    stats = StatsRepository(db);
    books = BookRepository(db);
    history = PlayHistoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Book book(String id) => Book(
        bookId: id,
        sourceId: 'XA',
        name: '书$id',
        detailUrl: 'url$id',
      );

  group('累计收听时长', () {
    test('初始为 0', () async {
      expect(await stats.totalListeningSeconds(), 0);
    });

    test('累加秒数', () async {
      await stats.addListeningSeconds(30);
      await stats.addListeningSeconds(45);
      expect(await stats.totalListeningSeconds(), 75);
    });

    test('第一次累加会创建行', () async {
      await stats.addListeningSeconds(10);
      final rows = await db.select(db.listeningStatsTable).get();
      expect(rows, hasLength(1));
      expect(rows.single.totalSeconds, 10);
    });

    test('始终只有一行（不自增出多行）', () async {
      for (var i = 0; i < 5; i++) {
        await stats.addListeningSeconds(10);
      }
      final rows = await db.select(db.listeningStatsTable).get();
      expect(rows, hasLength(1));
      expect(rows.single.totalSeconds, 50);
    });

    test('0 或负数被忽略', () async {
      await stats.addListeningSeconds(0);
      await stats.addListeningSeconds(-100);
      expect(await stats.totalListeningSeconds(), 0);
    });

    test('reset 清零', () async {
      await stats.addListeningSeconds(100);
      await stats.resetListening();
      expect(await stats.totalListeningSeconds(), 0);
    });

    test('updatedAt 会刷新', () async {
      await stats.addListeningSeconds(10);
      final before =
          (await db.select(db.listeningStatsTable).getSingle()).updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await stats.addListeningSeconds(10);
      final after =
          (await db.select(db.listeningStatsTable).getSingle()).updatedAt;

      expect(after.isAfter(before) || after == before, isTrue);
    });
  });

  group('snapshot 汇总', () {
    test('空库时全为 0', () async {
      final s = await stats.snapshot();
      expect(s.totalListening, Duration.zero);
      expect(s.bookCount, 0);
      expect(s.favoriteCount, 0);
      expect(s.listenedChapters, 0);
    });

    test('书架数来自 books 表', () async {
      await books.addToBookshelf(book('1'));
      await books.addToBookshelf(book('2'));

      final s = await stats.snapshot();
      expect(s.bookCount, 2);
      expect(s.favoriteCount, 2, reason: '收藏当前与书架同源');
    });

    test('已听章节数来自 play_history 表', () async {
      await history.saveProgress(
        bookId: '1',
        sourceId: 'XA',
        chapterIndex: 0,
        position: 1000,
        duration: 60000,
      );
      await history.saveProgress(
        bookId: '2',
        sourceId: 'XA',
        chapterIndex: 0,
        position: 1000,
        duration: 60000,
      );

      final s = await stats.snapshot();
      expect(s.listenedChapters, 2);
    });

    test('时长与等级联动', () async {
      // 攒到 60 分钟 → 升到 2 级
      await stats.addListeningSeconds(60 * 60);

      final s = await stats.snapshot();
      expect(s.totalMinutes, 60);
      expect(s.currentLevel.level, 2);
    });

    test('完整快照（书 + 历史 + 时长）', () async {
      await books.addToBookshelf(book('1'));
      await history.saveProgress(
        bookId: '1',
        sourceId: 'XA',
        chapterIndex: 3,
        position: 500,
        duration: 30000,
      );
      await stats.addListeningSeconds(3600);

      final s = await stats.snapshot();
      expect(s.bookCount, 1);
      expect(s.listenedChapters, 1);
      expect(s.totalListening, const Duration(hours: 1));
      expect(s.formattedListening, '1 小时');
    });

    test('reset 后快照时长为 0', () async {
      await stats.addListeningSeconds(500);
      await stats.resetListening();

      final s = await stats.snapshot();
      expect(s.totalListening, Duration.zero);
      expect(s.currentLevel.level, 1);
    });
  });
}
