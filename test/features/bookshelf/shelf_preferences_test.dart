import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soft_sound/features/bookshelf/shelf_preferences.dart';

/// 书架视图/排序持久化测试。
///
/// 此前这两个选择只存在内存里（注释还写着「不持久化」），重启就回到网格 +
/// 数据源顺序。聆阅用 `tingshu_shelf_view` / `tingshu_shelf_sort` 存档
/// （字节码 #21662 env slot 23/24），取值 `grid|list` 与
/// `added|rating|title`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('存档字面量', () {
    test('与聆阅逐字一致（不能改名，否则读不到用户已有存档）', () {
      expect(ShelfView.grid.wire, 'grid');
      expect(ShelfView.list.wire, 'list');
      expect(ShelfSort.added.wire, 'added');
      expect(ShelfSort.title.wire, 'title');
    });

    test('存储键为聆阅同名键', () {
      expect(ShelfPreferencesController.kViewKey, 'tingshu_shelf_view');
      expect(ShelfPreferencesController.kSortKey, 'tingshu_shelf_sort');
    });
  });

  group('解析存档值', () {
    test('认识的值正确还原', () {
      expect(ShelfView.fromWire('grid'), ShelfView.grid);
      expect(ShelfView.fromWire('list'), ShelfView.list);
      expect(ShelfSort.fromWire('added'), ShelfSort.added);
      expect(ShelfSort.fromWire('title'), ShelfSort.title);
    });

    test('聆阅的 rating 我们不支持 → 回落默认而不是崩', () {
      expect(ShelfSort.fromWire('rating'), isNull);
      expect(ShelfView.fromWire('nonsense'), isNull);
      expect(ShelfView.fromWire(null), isNull);
    });
  });

  group('读写往返', () {
    test('默认是 网格 + 最近添加', () {
      const p = ShelfPreferences();
      expect(p.view, ShelfView.grid);
      expect(p.sort, ShelfSort.added);
    });

    test('setView / setSort 会写进聆阅同名键', () async {
      final c = ShelfPreferencesController(initial: const ShelfPreferences());
      await c.setView(ShelfView.list);
      await c.setSort(ShelfSort.title);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tingshu_shelf_view'), 'list');
      expect(prefs.getString('tingshu_shelf_sort'), 'title');
      expect(c.state.view, ShelfView.list);
      expect(c.state.sort, ShelfSort.title);
    });

    test('重启后能读回上次的选择（此前重启就丢）', () async {
      SharedPreferences.setMockInitialValues({
        'tingshu_shelf_view': 'list',
        'tingshu_shelf_sort': 'title',
      });

      final c = ShelfPreferencesController();
      // 构造函数里的 _restore 是异步的，等一拍
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.state.view, ShelfView.list);
      expect(c.state.sort, ShelfSort.title);
    });

    test('脏数据（类型不对）回落默认值，不抛', () async {
      SharedPreferences.setMockInitialValues({
        'tingshu_shelf_view': 123,
        'tingshu_shelf_sort': true,
      });

      final c = ShelfPreferencesController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.state.view, ShelfView.grid);
      expect(c.state.sort, ShelfSort.added);
    });

    test('读到听不懂的字符串也回落默认值', () async {
      SharedPreferences.setMockInitialValues({
        'tingshu_shelf_view': 'gallery',
        'tingshu_shelf_sort': 'rating',
      });

      final c = ShelfPreferencesController();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.state.view, ShelfView.grid);
      expect(c.state.sort, ShelfSort.added);
    });
  });
}
