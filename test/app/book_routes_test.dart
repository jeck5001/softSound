import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/app/book_routes.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 详情路由必须携带已知书名/封面。
///
/// 用户反馈（2026-11-05）：**从搜索点进来一直显示「加载书籍信息…」**，
/// 随便选一章播放，播放页也显示同一个占位串。截图里目录明明有 925 集，
/// 标题却是空的。
///
/// 根因是入口路径不统一：全项目 5 处跳详情，只有书架传了书名（上次修的），
/// 搜索/历史/首页/分类都只传 `bookId` → 详情页造占位 Book 等
/// `getBookDetail` 补全，而详情接口常失败 → 占位串永久留在标题，
/// 并顺着 state 传染到播放页。
///
/// 所以做成**唯一入口构造器**，并在这里锁死行为。
void main() {
  group('bookDetailRoute', () {
    test('带上真实书名与封面', () {
      final r = bookDetailRoute(
        'xiaoKu_39725926',
        name: '夜无疆|头陀渊演播|东方玄幻',
        cover: 'https://img.example/a.jpg',
      );
      expect(r, contains('/book/xiaoKu_39725926'));
      expect(r, contains('name='));
      expect(r, anyOf(contains('夜无疆'), contains('%E5%A4%9C')));
      expect(r, contains('cover='));
    });

    test('书名与封面都要被 URL 编码（含 | 和中文）', () {
      final r = bookDetailRoute('lrts_1', name: 'A|B&C', cover: 'https://x/a?b=1');
      expect(r, isNot(contains('A|B&C')));
      expect(r, contains('A%7CB%26C'));
    });

    test('占位书名不传（否则把占位串当权威写进状态）', () {
      final r = bookDetailRoute('lrts_1', name: AppStrings.loadingBookInfo);
      expect(r, isNot(contains('name=')));
    });

    test('纯数字 id 不传（榜单页只有 id 时的临时书名）', () {
      final r = bookDetailRoute('lrts_1', name: '39725926');
      expect(r, isNot(contains('name=')));
    });

    test('空书名/空封面时退化成裸路径', () {
      expect(
        bookDetailRoute('lrts_1', name: '  ', cover: ''),
        '/book/lrts_1',
      );
    });
  });

  group('bookDetailRouteForBook', () {
    Book b(String name, {String? cover}) => Book(
          bookId: 'xiaoKu_66695527',
          sourceId: 'xiaoKu',
          name: name,
          detailUrl: '66695527',
          coverUrl: cover,
        );

    test('从 Book 取 name 与 coverUrl', () {
      final r = bookDetailRouteForBook(
        b('夜无疆多人剧', cover: 'https://img/a.jpg'),
      );
      expect(r, contains('name='));
      expect(r, contains('cover='));
    });

    test('搜索结果的占位态 Book 不会被当成已知书名', () {
      final r = bookDetailRouteForBook(b(AppStrings.loadingBookInfo));
      expect(r, isNot(contains('name=')));
    });
  });

  group('防回归：所有入口都必须走构造器', () {
    const entries = {
      '搜索': 'lib/features/search/search_page.dart',
      '书架': 'lib/features/bookshelf/bookshelf_page.dart',
      '历史': 'lib/features/history/history_page.dart',
      '首页': 'lib/features/home/home_page.dart',
      '分类书列表': 'lib/features/explore/category_books_page.dart',
    };

    for (final e in entries.entries) {
      test('${e.key} 不再裸拼 /book/ 路径', () {
        final src = _read(e.value);
        expect(
          src.contains("'/book/"),
          isFalse,
          reason: '${e.key} 仍手拼路径 → 会丢书名，详情接口失败时标题卡在占位串',
        );
        expect(src.contains('bookDetailRoute'), isTrue);
      });
    }
  });

  group('端到端链路（不依赖模拟器）', () {
      test('搜索结果 → 路由 → 详情页重建的 Book 必须保留真名与封面', () {
        // 用户在搜索页看到的样子：书名与封面都在搜索结果里
        final fromSearch = Book(
          bookId: 'xiaoKu_39725926',
          sourceId: 'xiaoKu',
          name: '夜无疆|头陀渊演播|东方玄幻|轻松搞笑',
          detailUrl: '39725926',
          coverUrl: 'https://img.example/cover.jpg',
        );
  
        // 1) 搜索页跳详情
        final route = bookDetailRouteForBook(fromSearch);
  
        // 2) 路由解析（routes.dart 就是这么读的）
        final uri = Uri.parse(route);
        final initialName = uri.queryParameters['name'];
        final initialCover = uri.queryParameters['cover'];
  
        // 3) 详情页据此重建占位 Book（book_detail_page._loadBookFromSearch）
        final rebuilt = Book(
          bookId: uri.pathSegments.last,
          sourceId: 'xiaoKu',
          name: (initialName?.isNotEmpty ?? false)
              ? initialName!
              : AppStrings.loadingBookInfo,
          coverUrl: (initialCover?.isNotEmpty ?? false) ? initialCover : null,
          detailUrl: '39725926',
        );
  
        expect(rebuilt.name, fromSearch.name,
            reason: '标题必须立即可见，不能等 getBookDetail');
        expect(rebuilt.coverUrl, fromSearch.coverUrl,
            reason: '封面同理，否则显示耳机占位图');
        expect(rebuilt.name, isNot(AppStrings.loadingBookInfo));
      });
  
      test('详情接口原样返回占位 Book 时，不许覆盖掉好名字', () {
        final src = File(
          'lib/features/book_detail/book_detail_page.dart',
        ).readAsStringSync();
        expect(
          src.contains('_nameQuality(detailBook.name) < _nameQuality(book.name)'),
          isTrue,
          reason: '酷我 getBookDetail 是 `=> book`，返回的可能就是占位名 Book；'
              '不设这道比较，路由带进来的真名会被换回占位串',
        );
      });
    });
}

String _read(String path) => File(path).readAsStringSync();
