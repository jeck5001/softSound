import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/data/repositories/play_history_repository.dart';
import 'package:soft_sound/data/repositories/stats_repository.dart';
import 'package:soft_sound/services/last_played_service.dart';

/// 「上次播放」恢复测试。
///
/// 背景（用户反馈）：退出 App 再打开，「上次播放的那个」没了。
/// 根因：`play_history` 只写不读 —— 每次播放都存进度，但启动时没有任何代码查。
/// 这里用**真实内存 SQLite**（drift NativeDatabase.memory）跑完整读写链路。
void main() {
  group('听过的书落库', _touchPlayedBookTests);
  group('统计口径', _statsCountTests);

  late AppDatabase db;
  late PlayHistoryRepository historyRepo;
  late BookRepository bookRepo;

  SourceRule source({String id = 'lrts'}) => SourceRule.fromJson({
        'sourceId': id,
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
      });

  Book book({String id = 'lrts_1', String sourceId = 'lrts'}) => Book(
        bookId: id,
        sourceId: sourceId,
        name: '大唐明月',
        author: '佚名',
        narrator: '夙染白',
        coverUrl: 'https://cdn.example/c.jpg',
        detailUrl: '1',
      );

  LastPlayedService service({List<SourceRule>? sources}) => LastPlayedService(
        historyRepo: historyRepo,
        bookRepo: bookRepo,
        sources: () => sources ?? [source()],
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    historyRepo = PlayHistoryRepository(db);
    bookRepo = BookRepository(db);
  });

  tearDown(() async => db.close());

  group('没有记录时', () {
    test('空库 → null（不弹续播卡片）', () async {
      expect(await service().load(), isNull);
    });

    test('有进度但书不在 books 表 → null（不编造书名）', () async {
      await historyRepo.saveProgress(
        bookId: 'lrts_ghost',
        sourceId: 'lrts',
        chapterIndex: 5,
        position: 600000,
        duration: 1000000,
      );
      expect(await service().load(), isNull);
    });

    test('书源已被删除 → null', () async {
      await bookRepo.addToBookshelf(book());
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'removed_source',
        chapterIndex: 5,
        position: 600000,
        duration: 1000000,
      );
      expect(await service(sources: const []).load(), isNull);
    });
  });

  group('正常恢复', () {
    test('读回书 + 书源 + 章节 + 进度', () async {
      await bookRepo.addToBookshelf(book());
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'lrts',
        chapterIndex: 8,
        chapterName: '第09集_故人相见',
        position: 724655,
        duration: 1079000,
      );

      final last = await service().load();
      expect(last, isNotNull);
      expect(last!.book.name, '大唐明月');
      expect(last.source.sourceId, 'lrts');
      expect(last.progress.chapterIndex, 8);
      expect(last.progress.position, 724655);
      expect(last.chapterNumber, 9, reason: '对外显示是 1 基');
      expect(last.subtitle, '第 9 章 · 听到 12:04');
    });

    test('同一秒内写两条也能稳定取到后写的那条（id 次级排序）', () async {
      await bookRepo.addToBookshelf(book(id: 'lrts_1'));
      await bookRepo.addToBookshelf(book(id: 'lrts_2'));
      // 不 sleep：两条 lastPlayTime 会落在同一秒（drift dateTime 精度为秒）
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'lrts',
        chapterIndex: 3,
        position: 300000,
        duration: 1000000,
      );
      await historyRepo.saveProgress(
        bookId: 'lrts_2',
        sourceId: 'lrts',
        chapterIndex: 7,
        position: 500000,
        duration: 1000000,
      );

      final last = await service().load();
      expect(last!.book.bookId, 'lrts_2',
          reason: '同秒时应按自增 id 取后写入的记录');
    });

    test('多条记录取最近的一条', () async {
      await bookRepo.addToBookshelf(book(id: 'lrts_1'));
      await bookRepo.addToBookshelf(book(id: 'lrts_2'));
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'lrts',
        chapterIndex: 3,
        position: 300000,
        duration: 1000000,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await historyRepo.saveProgress(
        bookId: 'lrts_2',
        sourceId: 'lrts',
        chapterIndex: 7,
        position: 500000,
        duration: 1000000,
      );

      final last = await service().load();
      expect(last!.book.bookId, 'lrts_2');
      expect(last.progress.chapterIndex, 7);
    });

    test('「点开就退」（第1章 <3秒）不算有效记录', () async {
      await bookRepo.addToBookshelf(book());
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'lrts',
        chapterIndex: 0,
        position: 800,
        duration: 1000000,
      );
      expect(await service().load(), isNull);
    });

    test('第1章但已听够 3 秒 → 算有效', () async {
      await bookRepo.addToBookshelf(book());
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'lrts',
        chapterIndex: 0,
        position: 3000,
        duration: 1000000,
      );
      expect(await service().load(), isNotNull);
    });

    test('跳过不可用的最近记录，继续找上一条可用的', () async {
      await bookRepo.addToBookshelf(book(id: 'lrts_1'));
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'lrts',
        chapterIndex: 4,
        position: 400000,
        duration: 1000000,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // 最近一条指向一本不在 books 表的书
      await historyRepo.saveProgress(
        bookId: 'lrts_ghost',
        sourceId: 'lrts',
        chapterIndex: 9,
        position: 900000,
        duration: 1000000,
      );

      final last = await service().load();
      expect(last, isNotNull);
      expect(last!.book.bookId, 'lrts_1', reason: '应跳过 ghost 回落到可用记录');
    });

    test('sourceId 不一致时按书自身的 sourceId 兜底', () async {
      await bookRepo.addToBookshelf(book(sourceId: 'lrts'));
      await historyRepo.saveProgress(
        bookId: 'lrts_1',
        sourceId: 'stale_id',
        chapterIndex: 2,
        position: 200000,
        duration: 1000000,
      );
      final last = await service().load();
      expect(last, isNotNull);
      expect(last!.source.sourceId, 'lrts');
    });
  });

  group('格式化', () {
    test('mm:ss 与 h:mm:ss', () {
      expect(LastPlayed.formatClock(const Duration(seconds: 724)), '12:04');
      expect(LastPlayed.formatClock(const Duration(seconds: 5)), '00:05');
      expect(
        LastPlayed.formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });
}

/// 「听过的书」落库语义：播放只更新元数据，**不得改动书架状态**。
void _touchPlayedBookTests() {
  late AppDatabase db;
  late BookRepository repo;

  Book book({String id = 'lrts_1', String name = '大唐明月'}) => Book(
        bookId: id,
        sourceId: 'lrts',
        name: name,
        author: '佚名',
        narrator: '夙染白',
        coverUrl: 'https://cdn.example/c.jpg',
        detailUrl: '1',
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BookRepository(db);
  });

  tearDown(() async => db.close());

  test('听过的书会进 books 表，但 inBookshelf=false', () async {
    await repo.touchPlayedBook(book());
    final saved = await repo.getBookById('lrts_1');
    expect(saved, isNotNull);
    expect(saved!.name, '大唐明月');
    expect(saved.inBookshelf, isFalse, reason: '听过不等于收藏');
    expect(await repo.getBookshelfBooks(), isEmpty);
  });

  test('已在书架的书：播放只刷新元数据，不移出书架', () async {
    await repo.addToBookshelf(book(name: '旧名'));
    await repo.touchPlayedBook(book(name: '新名'));

    final saved = await repo.getBookById('lrts_1');
    expect(saved!.name, '新名', reason: '元数据应刷新');
    expect(saved.inBookshelf, isTrue, reason: '不能因为播放就把用户移出书架');
    expect(await repo.getBookshelfBooks(), hasLength(1));
  });

  test('重复播放不产生重复行', () async {
    await repo.touchPlayedBook(book());
    await repo.touchPlayedBook(book());
    final all = await repo.getBookshelfBooks();
    expect(all, isEmpty);
    // 用书架外的查询确认只有一行
    expect(await repo.getBookById('lrts_1'), isNotNull);
  });
}

/// 统计口径：`books` 表里「听过但没收藏」的书不能被算进收藏数。
void _statsCountTests() {
  late AppDatabase db;
  late BookRepository repo;

  Book book({String id = 'lrts_1'}) => Book(
        bookId: id,
        sourceId: 'lrts',
        name: '大唐明月',
        detailUrl: '1',
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BookRepository(db);
  });

  tearDown(() async => db.close());

  test('只有「听过」的书 → 收藏数为 0', () async {
    await repo.touchPlayedBook(book());
    final stats = await StatsRepository(db).snapshot();
    expect(stats.favoriteCount, 0);
    expect(stats.bookCount, 0);
  });

  test('加入书架后才计入收藏', () async {
    await repo.touchPlayedBook(book());
    await repo.addToBookshelf(book());
    final stats = await StatsRepository(db).snapshot();
    expect(stats.favoriteCount, 1);
  });
}
