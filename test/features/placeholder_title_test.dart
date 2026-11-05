import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/services/player_service.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 详情页标题不能停在占位串上。
///
/// 用户截图（2026-11-04）：酷我版《夜无疆》进详情后目录已完整（1237 集），
/// 但**标题显示「加载书籍信息…」**。
///
/// 机制：从书架/搜索/历史进详情时，路由只带 `bookId`，
/// 详情页于是造一个 `name = AppStrings.loadingBookInfo` 的占位 Book
/// 等 `getBookDetail` 补全；而酷我详情接口经常失败 → 占位串永久留在界面上。
///
/// 之前的占位判定只认"纯数字 id"（榜单那条路径），
/// 完全没覆盖路由这条路径 —— 这就是它静默存在的原因。
void main() {
  Book named(String name) => Book(
        bookId: 'xiaoKu_66695527',
        sourceId: 'xiaoKu',
        name: name,
        detailUrl: '66695527',
      );

  group('占位判定要覆盖两种来源', () {
    test('路由进来的「加载书籍信息…」算占位', () {
      expect(
        PlayerNotifier.isPlaceholderBook(named(AppStrings.loadingBookInfo)),
        isTrue,
        reason: '这是本次截图里的形态；旧判定只看纯数字，漏掉了它',
      );
    });

    test('纯数字 id 不被 isPlaceholderBook 覆盖，详情页必须补上这一判', () {
      // 实测：榜单/分类页用 id 当临时书名，isPlaceholderBook 认不出来
      //（它只管空串与「加载书籍信息…」）。
      expect(
        PlayerNotifier.isPlaceholderBook(named('39725926')),
        isFalse,
        reason: '确认共享判定的边界，避免误以为它覆盖了 id 占位',
      );
      // 所以详情页的占位判定必须是**两者取并集**。
      final src = File(
        'lib/features/book_detail/book_detail_page.dart',
      ).readAsStringSync();
      expect(
        src.contains('int.tryParse(book.name.trim()) != null'),
        isTrue,
        reason: '少了这半条，榜单进来的书卡占位时就不会被兜底',
      );
    });

    test('真实书名不算占位', () {
      expect(
        PlayerNotifier.isPlaceholderBook(named('夜无疆|头陀渊演播')),
        isFalse,
      );
    });
  });

  group('详情页兜底', () {
    test('详情失败且是占位时，从本地库找回真名（不显示占位串）', () {
      final src = File(
        'lib/features/book_detail/book_detail_page.dart',
      ).readAsStringSync();
      expect(
        src.contains('getBookById'),
        isTrue,
        reason: '库里存过这本书，就该用库里的名字，而不是占位串',
      );
      expect(
        src.contains('PlayerNotifier.isPlaceholderBook(book)') ||
            src.contains('isPlaceholderBook(book)'),
        isTrue,
        reason: '判定必须走统一函数，不能只认纯数字',
      );
    });

    test('书架跳转必须走统一路由构造器（带书名与封面）', () {
      final src = File(
        'lib/features/bookshelf/bookshelf_page.dart',
      ).readAsStringSync();
      // 实现细节（query 怎么拼）由 test/app/book_routes_test.dart 断言；
      // 这里只守"入口不许裸拼路径"这条不变量。
      expect(
        src.contains('bookDetailRouteForBook(book)') ||
            src.contains('bookDetailRoute('),
        isTrue,
        reason: '只 push bookId 会让详情页退回占位态',
      );
      expect(
        src.contains("'/book/"),
        isFalse,
        reason: '不许再手拼裸路径',
      );
    });

    test('播放器也守住同样的占位过滤', () {
      final src = File('lib/services/player_service.dart').readAsStringSync();
      expect(src.contains('isPlaceholderBook'), isTrue);
    });
  });
}
