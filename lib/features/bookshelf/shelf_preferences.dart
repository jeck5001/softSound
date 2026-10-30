import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 书架视图模式 —— 对齐聆阅的「网格 / 列表」（键 `tingshu_shelf_view`）。
enum ShelfView {
  grid('grid'),
  list('list');

  const ShelfView(this.wire);

  /// 存档用的字面量（聆阅逐字：`'grid'` / `'list'`）。
  final String wire;

  static ShelfView? fromWire(String? v) {
    for (final e in ShelfView.values) {
      if (e.wire == v) return e;
    }
    return null;
  }
}

/// 书架排序方式 —— 对齐聆阅的 `tingshu_shelf_sort`。
///
/// 聆阅有三个取值（字节码 #21669 内联对象逐字）：
/// `added`「最近添加」/ `rating`「评分排序」/ `title`「书名排序」。
///
/// 本项目**不实现 `rating`**：真实书籍详情接口（`/lrts-info` 抓包
/// `test/fixtures/lrts_bookinfo_real.json`）里没有评分字段，评分只出现在
/// 首页/分类的推荐流里，落库后拿不到。搬一个永远排不出顺序的选项只会让
/// 用户困惑，所以这里显式留档并只提供另外两项。
enum ShelfSort {
  /// 最近添加（仓库按加入/更新时间倒序返回）
  added('added'),

  /// 书名排序
  title('title');

  const ShelfSort(this.wire);

  /// 存档用的字面量（聆阅逐字）。
  final String wire;

  static ShelfSort? fromWire(String? v) {
    // 聆阅的第三个取值 rating 落到这里会被忽略 → 回落到默认「最近添加」，
    // 不会因为读到不认识的存档值而崩。
    for (final e in ShelfSort.values) {
      if (e.wire == v) return e;
    }
    return null;
  }
}

/// 书架偏好（视图 + 排序），持久化到聆阅同名键。
class ShelfPreferences {
  final ShelfView view;
  final ShelfSort sort;

  const ShelfPreferences({
    this.view = ShelfView.grid,
    this.sort = ShelfSort.added,
  });

  ShelfPreferences copyWith({ShelfView? view, ShelfSort? sort}) =>
      ShelfPreferences(view: view ?? this.view, sort: sort ?? this.sort);
}

/// 书架偏好控制器。
class ShelfPreferencesController extends StateNotifier<ShelfPreferences> {
  /// [initial] 仅供测试注入：给了就不再读盘。
  ShelfPreferencesController({ShelfPreferences? initial})
      : super(initial ?? const ShelfPreferences()) {
    if (initial == null) _restore();
  }

  /// 存储键（聆阅逐字，字节码 #21662 env slot 23/24）。
  static const String kViewKey = 'tingshu_shelf_view';
  static const String kSortKey = 'tingshu_shelf_sort';

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = ShelfPreferences(
        view: ShelfView.fromWire(_readString(p, kViewKey)) ?? ShelfView.grid,
        sort: ShelfSort.fromWire(_readString(p, kSortKey)) ?? ShelfSort.added,
      );
    } catch (_) {
      // 读盘失败保持默认值即可
    }
  }

  /// 用 `get` + 类型判断，脏数据（非 String）时回落默认值而不是抛。
  static String? _readString(SharedPreferences p, String key) {
    final v = p.get(key);
    return v is String ? v : null;
  }

  Future<void> setView(ShelfView v) async {
    state = state.copyWith(view: v);
    await _put((p) => p.setString(kViewKey, v.wire));
  }

  Future<void> setSort(ShelfSort s) async {
    state = state.copyWith(sort: s);
    await _put((p) => p.setString(kSortKey, s.wire));
  }

  Future<void> _put(Future<void> Function(SharedPreferences) fn) async {
    try {
      await fn(await SharedPreferences.getInstance());
    } catch (_) {
      // 存档失败不影响本次会话内的选择
    }
  }
}

/// 书架偏好 Provider。
final shelfPreferencesProvider =
    StateNotifierProvider<ShelfPreferencesController, ShelfPreferences>(
  (ref) => ShelfPreferencesController(),
);
