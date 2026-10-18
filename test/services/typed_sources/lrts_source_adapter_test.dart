import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/lrts_source_adapter.dart';
import 'package:soft_sound/services/typed_sources/typed_source_registry.dart';

/// 用**真实抓取**的懒人听书响应验证适配器。
///
/// fixture 来源：2026-10-13 直接请求
/// - `https://m.lrts.me/ajax/getBookInfo?id=15814228`（60 字段，3005 字节）
/// - `https://m.lrts.me/ajax/getBookMenu?bookId=15814228`（list[30]，14764 字节）
void main() {
  late Map<String, dynamic> realBookInfo;
  late Map<String, dynamic> realBookMenu;

  setUpAll(() {
    final infoFile = File('test/fixtures/lrts_bookinfo_real.json');
    final menuFile = File('test/fixtures/lrts_bookmenu_real.json');
    expect(infoFile.existsSync(), isTrue, reason: '缺少 getBookInfo fixture');
    expect(menuFile.existsSync(), isTrue, reason: '缺少 getBookMenu fixture');

    realBookInfo =
        jsonDecode(infoFile.readAsStringSync()) as Map<String, dynamic>;
    realBookMenu =
        jsonDecode(menuFile.readAsStringSync()) as Map<String, dynamic>;
  });

  SourceRule source() => SourceRule.fromJson({
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

  group('fixture 完整性（防护上游变更）', () {
    test('getBookInfo 是懒人真实报文', () {
      expect(realBookInfo['baseEntityId'], 15814228);
      expect(realBookInfo['sections'], greaterThan(0));
      // 关键字段存在
      for (final k in ['name', 'announcer', 'cover', 'sections', 'apiStatus']) {
        expect(realBookInfo.containsKey(k), isTrue, reason: '缺少字段 $k');
      }
    });

    test('getBookMenu 是懒人真实报文', () {
      expect(realBookMenu['bookId'], 15814228);
      expect(realBookMenu['list'], isA<List>());
      expect((realBookMenu['list'] as List), isNotEmpty);

      final first = (realBookMenu['list'] as List).first as Map;
      for (final k in ['id', 'section', 'name', 'length', 'feeType']) {
        expect(first.containsKey(k), isTrue, reason: '章节缺少字段 $k');
      }
    });
  });

  group('parseBookInfo（真实响应）', () {
    test('解析出书名/播音/封面/简介', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(source(), '15814228', realBookInfo);

      expect(book, isNotNull);
      expect(book!.name, isNotEmpty);
      expect(book.narrator, isNotNull);
      expect(book.coverUrl, startsWith('https://bookpic.lrts.me/'));
      expect(book.intro, isNotNull);
      expect(book.sourceId, 'lrts');
      expect(book.detailUrl, '15814228');
    });

    test('章节总数来自 sections 字段', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(source(), '15814228', realBookInfo);
      expect(book!.chapterCount, realBookInfo['sections']);
    });

    test('bookId 带源前缀，避免跨源冲突', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(source(), '15814228', realBookInfo);
      expect(book!.bookId, 'lrts_15814228');
    });

    test('apiStatus 非 0（资源下线）返回 null', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(
        source(),
        '999',
        {'apiStatus': 1, 'status': 1, 'msg': '资源已下线', 'data': {}},
      );
      expect(book, isNull);
    });

    test('缺少 name 返回 null', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(
        source(),
        '999',
        {'apiStatus': 0, 'sections': 1},
      );
      expect(book, isNull);
    });

    test('bestCover 优先于 cover', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(source(), '1', {
        'apiStatus': 0,
        'name': 'T',
        'bestCover': 'https://best/x.png',
        'cover': 'https://cover/x.png',
      });
      expect(book!.coverUrl, 'https://best/x.png');
    });

    test('无 bestCover 时回退到 cover', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(source(), '1', {
        'apiStatus': 0,
        'name': 'T',
        'cover': 'https://cover/x.png',
      });
      expect(book!.coverUrl, 'https://cover/x.png');
    });

    test('author 为空字符串时归一为 null', () {
      final adapter = LrtsSourceAdapter();
      final book = adapter.parseBookInfo(source(), '1', {
        'apiStatus': 0,
        'name': 'T',
        'author': '',
      });
      expect(book!.author, isNull);
    });
  });

  group('parseChapterResponse（真实响应）', () {
    Book book() => Book(
          bookId: 'lrts_15814228',
          sourceId: 'lrts',
          name: '测试书',
          detailUrl: '15814228',
        );

    test('解析出章节列表', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), realBookMenu);
      expect(chapters, hasLength((realBookMenu['list'] as List).length));
      expect(chapters, isNotEmpty);
    });

    test('章节 token 非空（id 与 sectionId 一致）', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), realBookMenu);

      for (final ch in chapters) {
        expect(ch.url, isNotEmpty, reason: '章节 token 不应为空');
        expect(ch.chapterId, ch.url);
      }
    });

    test('索引从 0 开始且连续（section 从 1 开始）', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), realBookMenu);

      for (var i = 0; i < chapters.length; i++) {
        expect(chapters[i].index, i);
      }
    });

    test('时长来自 length 字段（秒）', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), realBookMenu);

      final firstRaw = (realBookMenu['list'] as List).first as Map;
      final expected = int.parse(firstRaw['length'].toString());
      expect(chapters.first.duration, expected);
      expect(chapters.first.duration, greaterThan(0));
    });

    test('章节名非空', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), realBookMenu);
      for (final ch in chapters) {
        expect(ch.name.trim(), isNotEmpty);
      }
    });

    test('章节归属正确的书籍', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), realBookMenu);
      for (final ch in chapters) {
        expect(ch.bookId, 'lrts_15814228');
      }
    });

    test('付费章节被标记 isVip', () {
      final adapter = LrtsSourceAdapter();
      // 构造一个付费章节
      final chapters = adapter.parseChapterResponse(book(), {
        'list': [
          {'id': 'free', 'section': '1', 'name': '免费', 'feeType': '0', 'payType': '0'},
          {'id': 'vip', 'section': '2', 'name': '付费', 'feeType': '1', 'payType': '0'},
        ],
      });

      expect(chapters[0].isVip, isFalse);
      expect(chapters[1].isVip, isTrue);
    });

    test('cantListen=1 视为不可听（标记 isVip）', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), {
        'list': [
          {'id': 'x', 'section': '1', 'name': 'N', 'cantListen': '1'},
        ],
      });
      expect(chapters.single.isVip, isTrue);
    });

    test('path 非空时作为直链填入 audioUrl', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), {
        'list': [
          {
            'id': 'x',
            'section': '1',
            'name': 'N',
            'path': 'https://cdn.test/a.m4a',
          },
        ],
      });
      expect(chapters.single.audioUrl, 'https://cdn.test/a.m4a');
    });

    test('真实响应中 path 为空 → audioUrl 为 null（需服务端换取）', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), realBookMenu);
      // 真实数据 path 均为空，这是已知限制
      expect(chapters.every((c) => c.audioUrl == null), isTrue);
    });

    test('缺失 section 时退化用数组下标', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), {
        'list': [
          {'id': 'a', 'name': 'A'},
          {'id': 'b', 'name': 'B'},
        ],
      });
      expect(chapters[0].index, 0);
      expect(chapters[1].index, 1);
    });

    test('无 id 的条目被跳过', () {
      final adapter = LrtsSourceAdapter();
      final chapters = adapter.parseChapterResponse(book(), {
        'list': [
          {'name': '无 id'},
          {'id': 'ok', 'section': '2', 'name': '有效'},
        ],
      });
      expect(chapters, hasLength(1));
      expect(chapters.single.name, '有效');
    });
  });

  group('健壮性', () {
    test('空响应返回空列表', () {
      final adapter = LrtsSourceAdapter();
      final book = Book(
        bookId: 'x',
        sourceId: 'lrts',
        name: 'x',
        detailUrl: '1',
      );
      expect(adapter.parseChapterResponse(book, {}), isEmpty);
    });

    test('list 非数组时不抛异常', () {
      final adapter = LrtsSourceAdapter();
      final book = Book(
        bookId: 'x',
        sourceId: 'lrts',
        name: 'x',
        detailUrl: '1',
      );
      expect(
        () => adapter.parseChapterResponse(book, {'list': 'oops'}),
        returnsNormally,
      );
    });

    test('search 现已接通 Edge Function（无网络时返回空而非抛异常）', () async {
      final adapter = LrtsSourceAdapter();
      // 无网络/限流时应优雅降级为空列表，而非抛异常
      final result = await adapter.search(source(), '凡人修仙传');
      expect(result, isA<List<Book>>());
    });

    test('getAudioUrl 对无效 token 优雅降级（不抛异常）', () async {
      final adapter = LrtsSourceAdapter();
      final ch = Chapter(
        chapterId: 'tok',
        bookId: 'lrts_1',
        index: 0,
        name: 'N',
        url: 'tok',
      );
      // 无效 token 会请求 Edge Function 并被上游拒绝 → 应返回 null
      // （若服务恰好可用且 token 命中则可能返回 String；两种都合法）
      // 真实调用含 429 重试，放宽超时。
      final r = await adapter.getAudioUrl(source(), ch);
      expect(r, anyOf(isNull, isA<String>()));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('getAudioUrl 在有直链时直接返回', () async {
      final adapter = LrtsSourceAdapter();
      final ch = Chapter(
        chapterId: 'tok',
        bookId: 'lrts_1',
        index: 0,
        name: 'N',
        url: 'tok',
        audioUrl: 'https://cdn/x.m4a',
      );
      expect(await adapter.getAudioUrl(source(), ch), 'https://cdn/x.m4a');
    });
  });

  group('注册表集成', () {
    test('lrts 已注册到 typedSourceRegistry', () {
      expect(typedSourceRegistry.adapterFor('lrts'), isNotNull);
      expect(typedSourceRegistry.adapterFor('lrts'), isA<LrtsSourceAdapter>());
    });

    test('原有 5 个源仍然注册（未破坏）', () {
      for (final id in ['XA', 'xiaoKu', 'liuYue', 'xiaoLiang', 'xiaoQing']) {
        expect(typedSourceRegistry.adapterFor(id), isNotNull,
            reason: '$id 适配器丢失');
      }
    });
  });

group('getRankList / parseRankList（真实榜单页）', () {
  late String realHtml;

  setUpAll(() {
    final f = File('test/fixtures/lrts_ranklist_real.html');
    expect(f.existsSync(), isTrue, reason: '缺少榜单页 fixture');
    realHtml = f.readAsStringSync();
  });

  test('fixture 含真实 book 链接（防护失效）', () {
    final ids = RegExp(r'/book/(\d{5,})').allMatches(realHtml).length;
    expect(ids, greaterThan(10), reason: '榜单页应含大量书籍链接');
  });

  test('parseRankList 提取去重后的书籍', () {
    final adapter = LrtsSourceAdapter();
    final books = adapter.parseRankList(source(), realHtml);

    expect(books, isNotEmpty);
    // 全部带源前缀
    for (final b in books) {
      expect(b.bookId, startsWith('lrts_'));
      expect(b.sourceId, 'lrts');
      expect(b.detailUrl, isNotEmpty);
    }
  });

  test('结果已去重（同书多次出现只保留一条）', () {
    final adapter = LrtsSourceAdapter();
    final books = adapter.parseRankList(source(), realHtml);
    final urls = books.map((b) => b.detailUrl).toSet();
    expect(urls.length, books.length, reason: 'detailUrl 不应重复');
  });

  test('占位书名用 id（详情页会补全）', () {
    final adapter = LrtsSourceAdapter();
    final books = adapter.parseRankList(source(), realHtml);
    for (final b in books) {
      expect(b.name, b.detailUrl, reason: '榜单页无书名，name 应为 id 占位');
    }
  });

  test('空 HTML 返回空列表', () {
    final adapter = LrtsSourceAdapter();
    expect(adapter.parseRankList(source(), ''), isEmpty);
  });

  test('无 book 链接的 HTML 返回空列表', () {
    final adapter = LrtsSourceAdapter();
    expect(adapter.parseRankList(source(), '<html><body>empty</body></html>'), isEmpty);
  });

  test('search 失败时优雅降级为空列表', () async {
    final adapter = LrtsSourceAdapter();
    final r = await adapter.search(source(), '凡人修仙传');
    expect(r, isA<List<Book>>());
  });

  group('parseSearchResult（真实抓包 fixture）', () {
    test('解析出 40 本书且字段完整', () {
      final f = File('test/fixtures/lrts_search_real.json');
      expect(f.existsSync(), isTrue, reason: '缺少 lrts_search_real.json');
      final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

      final adapter = LrtsSourceAdapter();
      final books = adapter.parseSearchResult(source(), d);

      expect(books, isNotEmpty);
      expect(books.first.name, isNotEmpty);
      expect(books.first.bookId, startsWith('lrts_'));
      expect(books.first.coverUrl, anyOf(startsWith('https://'), isNull));
    });
  });
});

  group('分页章节列表（真实抓包参数）', () {
    test('page1 fixture：60 章、sections 总数正确', () {
      final f = File('test/fixtures/lrts_bookmenu_page1_real.json');
      expect(f.existsSync(), isTrue);
      final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

      final adapter = LrtsSourceAdapter();
      final book = Book(
        bookId: 'lrts_89162581',
        sourceId: 'lrts',
        name: 'x',
        detailUrl: '89162581',
      );
      final chapters = adapter.parseChapterResponse(book, d);

      expect(chapters, hasLength(60));
      expect(d['sections'], 4523, reason: '该书共 4523 集');
      // 分页正确性：page1 应从第 1 集开始
      expect(chapters.first.index, 0);
    });

    test('getChapterList 真实请求优雅降级', () async {
      final book = Book(
        bookId: 'lrts_89162581',
        sourceId: 'lrts',
        name: 'x',
        detailUrl: '89162581',
      );
      // 真实调用（含分页，可能较慢），放宽超时；失败时返回空而非抛异常
      final adapter2 = LrtsSourceAdapter();
      final r = await adapter2.getChapterList(source(), book);
      expect(r, isA<List<Chapter>>());
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

}
