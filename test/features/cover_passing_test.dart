import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 封面丢失的接线守卫。
///
/// 用户反馈：从排行榜点进去、随便点一本书、进播放页，**没有封面图**。
///
/// 根因有三层：
/// 1. 榜单跳转只带了 `?name=`，没带 `cover` —— 详情接口回来之前封面是空的；
/// 2. `touchPlayedBook` 无条件 `Value(book.coverUrl)`，从榜单进来时
///    coverUrl 是 null，会把库里**已有的封面擦成 null**（永久丢失）；
/// 3. 播放页只读 `currentBook.coverUrl`，没有从库里兜底。
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('列表 → 详情要透传封面', () {
    test('榜单跳转带上 cover 参数', () {
      final src = read('lib/features/ranking/ranking_page.dart');
      expect(src.contains('&cover='), isTrue,
          reason: '只带 name 的话，详情接口回来前播放页没有封面');
    });

    test('路由解析 cover 并传给详情页', () {
      final src = read('lib/app/routes.dart');
      expect(src.contains("queryParameters['cover']"), isTrue);
      expect(src.contains('initialCover'), isTrue);
    });

    test('详情页用 initialCover 作为初始封面', () {
      final src = read('lib/features/book_detail/book_detail_page.dart');
      expect(src.contains('this.initialCover'), isTrue);
      expect(src.contains('coverUrl: (widget.initialCover'), isTrue);
    });
  });

  group('不能把已有封面擦成 null（关键回归）', () {
    test('touchPlayedBook 对空值不写（Value.absent）', () {
      final src = read('lib/data/repositories/book_repository.dart');
      expect(src.contains('_keepIfEmpty'), isTrue,
          reason: '无条件写 Value(book.coverUrl) 会用 null 覆盖库里已有封面');
      expect(src.contains('Value.absent()'), isTrue);

      // 只截 touchPlayedBook 的「更新」分支（插入分支允许写 null）
      final start = src.indexOf('Future<void> touchPlayedBook');
      final upd = src.indexOf('await (_db.update(_db.booksTable)', start);
      final block = src.substring(upd);
      expect(
        block.contains('coverUrl: Value(book.coverUrl)'),
        isFalse,
        reason: '这正是把封面擦成 null 的写法',
      );
      expect(block.contains('coverUrl: _keepIfEmpty(book.coverUrl)'), isTrue);
    });

    test('intro / latestChapter 同样不覆盖成空', () {
      final src = read('lib/data/repositories/book_repository.dart');
      expect(src.contains('intro: _keepIfEmpty(book.intro)'), isTrue);
      expect(src.contains('latestChapter: _keepIfEmpty(book.latestChapter)'),
          isTrue);
    });
  });

  group('播放页封面兜底', () {
    test('currentBook 没封面时从库里补', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('getBookById(playedBook.bookId)'), isTrue,
          reason: '续播/榜单进入时内存里的书可能没有封面，库里才有');
      expect(src.contains('copyWith(coverUrl: storedCover)'), isTrue);
    });
  });

  group('LyCover 降级', () {
    test('非 http 的 url 显示占位而不是崩', () {
      final src = read('lib/theme/brand_widgets.dart');
      expect(src.contains("url.startsWith('http')"), isTrue);
      expect(src.contains('errorWidget'), isTrue);
    });
  });
}
