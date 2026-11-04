import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/data/repositories/catalog_repository.dart';
import 'package:soft_sound/services/chapter_catalog_service.dart';
import 'package:soft_sound/services/source_parser.dart';

/// 目录缓存合并测试。
///
/// 背景（2026-11-04 用户反馈「目录还是加载不全」）：
/// 上一轮修的是「失败页不要中断翻页」，但只要书源代理还在 429/500，
/// 一次会话就**永远差几页** —— 因为每次进详情页都从第 1 页重来，
/// 上次成功的页并没有被记住。
///
/// 本次改成「按上游绝对序号 section 落盘 + 跨会话合并」：
/// 这次失败的页，下次（或历史）拉到了就补上，最终收敛到完整目录。
void main() {
  late AppDatabase db;
  late CatalogRepository repo;

  final source = SourceRule.fromJson({
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
  });

  const bookId = 'lrts_52798788';
  final book = Book(
    bookId: bookId,
    sourceId: 'lrts',
    name: '测试书',
    detailUrl: '52798788',
    chapterCount: 10,
  );

  Chapter ch(int section) => Chapter(
        chapterId: '${bookId}000$section',
        bookId: bookId,
        index: section - 1,
        name: '第$section集',
        url: '${bookId}000$section',
        sectionIndex: section,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CatalogRepository(db);
  });

  tearDown(() async => db.close());

  group('目录缓存', () {
    test('写入后按 section 升序读回，并重编为连续 index', () async {
      // 故意乱序写入
      await repo.upsert(bookId, 'lrts', [ch(3), ch(1), ch(2)]);
      final loaded = await repo.load(bookId);
      expect(loaded.map((c) => c.sectionIndex), [1, 2, 3]);
      expect(loaded.map((c) => c.index), [0, 1, 2]);
    });

    test('同 section 重复写入是更新而不是新增', () async {
      await repo.upsert(bookId, 'lrts', [ch(1)]);
      await repo.upsert(bookId, 'lrts', [ch(1)]);
      expect(await repo.count(bookId), 1);
    });

    test('缺页只是空洞，补齐后不错位', () async {
      // 第一次只拿到 1,2,5（3,4 拉失败）
      await repo.upsert(bookId, 'lrts', [ch(1), ch(2), ch(5)]);
      expect((await repo.load(bookId)).map((c) => c.sectionIndex), [1, 2, 5]);

      // 第二次补齐 3,4
      await repo.upsert(bookId, 'lrts', [ch(3), ch(4)]);
      final full = await repo.load(bookId);
      expect(full.length, 5);
      expect(full.map((c) => c.sectionIndex), [1, 2, 3, 4, 5]);
      expect(full.map((c) => c.index), [0, 1, 2, 3, 4]);
    });

    test('clear 只清指定书', () async {
      await repo.upsert(bookId, 'lrts', [ch(1)]);
      await repo.upsert('lrts_other', 'lrts', [ch(1)]);
      await repo.clear(bookId);
      expect(await repo.count(bookId), 0);
      expect(await repo.count('lrts_other'), 1);
    });
  });

  group('跨会话累积（真实故障场景）', () {
    test('本次网络失败时返回历史缓存，不返回空', () async {
      await repo.upsert(bookId, 'lrts', [ch(1), ch(2), ch(3)]);

      final svc = ChapterCatalogService(
        parser: _FakeSourceParser(const []), // 本次什么都没拉到
        catalog: repo,
      );
      final out = await svc.loadChapters(source, book, expectedTotal: 10);
      expect(out.length, 3, reason: '网络全挂也要给用户已有的一切');
      expect(svc.lastWasPartial, isTrue);
    });

    test('本次拿到缺的页 → 合并成完整目录', () async {
      await repo.upsert(bookId, 'lrts', [ch(1), ch(2), ch(3)]);

      final svc = ChapterCatalogService(
        parser: _FakeSourceParser([ch(4), ch(5)]),
        catalog: repo,
      );
      final out = await svc.loadChapters(source, book, expectedTotal: 5);
      expect(out.length, 5);
      expect(out.map((c) => c.name).toList(),
          ['第1集', '第2集', '第3集', '第4集', '第5集']);
      expect(svc.lastWasPartial, isFalse);
    });

    test('多次部分成功会逐步收敛到完整', () async {
      // 模拟 5 次各拉到 2 页，看是否逐步收敛到完整
      ChapterCatalogService? last;
      for (var i = 0; i < 5; i++) {
        final a = i * 2 + 1;
        final svc = ChapterCatalogService(
          parser: _FakeSourceParser([ch(a), ch(a + 1)]),
          catalog: repo,
        );
        last = svc;
        final out = await svc.loadChapters(source, book, expectedTotal: 10);
        expect(out.length, (i + 1) * 2, reason: '第 ${i + 1} 次应累积到 ${(i + 1) * 2} 章');
      }
      expect(last!.lastWasPartial, isFalse, reason: '累积满 10 章后不再算不全');
    });

    test('同 section 以本次（更新的数据）为准', () async {
      await repo.upsert(bookId, 'lrts', [ch(1)]);
      final renamed = ch(1).copyWith(name: '第1集（已改名）');
      final svc = ChapterCatalogService(
        parser: _FakeSourceParser([renamed]),
        catalog: repo,
      );
      final out = await svc.loadChapters(source, book, expectedTotal: 1);
      expect(out.single.name, '第1集（已改名）');
    });
  });
}

/// 只控制 [getChapterList] 返回值的假 parser。
class _FakeSourceParser extends SourceParser {
  _FakeSourceParser(this.pages);
  List<Chapter> pages;

  @override
  Future<List<Chapter>> getChapterList(
    SourceRule source,
    Book book,
  ) async {
    return pages;
  }
}
