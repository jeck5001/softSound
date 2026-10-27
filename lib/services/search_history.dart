import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史 + 热门搜索 —— 契约来自聆阅字节码 #22722 模块。
///
/// 存储键：**`search_history_v1`**（逐字，JSON 字符串数组）。
///
/// 热门搜索词也是字节码里的内联字面量（8 个，逐字）：
/// `斗破苍穹 / 三体 / 盗墓笔记 / 明朝那些事儿 / 白夜行 / 活着 / 鬼吹灯 / 解忧杂货店`。
///
/// > 上限按 10 条实现。字节码在该键附近只能确认一个常量 `4`，
/// > 无法确定它是不是「历史上限」，因此不照抄，取更常见的 10 并在此留档。
class SearchHistoryStore {
  SearchHistoryStore({this.prefs});

  SharedPreferences? prefs;

  /// 存储键（聆阅逐字）。
  static const String storageKey = 'search_history_v1';

  /// 最多保留条数。
  static const int maxEntries = 10;

  /// 聆阅内置热门搜索词（字节码内联字面量，逐字）。
  static const List<String> hotKeywords = [
    '斗破苍穹',
    '三体',
    '盗墓笔记',
    '明朝那些事儿',
    '白夜行',
    '活着',
    '鬼吹灯',
    '解忧杂货店',
  ];

  Future<SharedPreferences> _p() async =>
      prefs ??= await SharedPreferences.getInstance();

  /// 读取历史（最近搜索在前）。损坏数据按空处理，不抛。
  Future<List<String>> load() async {
    try {
      final p = await _p();
      final raw = p.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is String && e.trim().isNotEmpty) e.trim(),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 记录一次搜索（去重 → 置顶 → 截断）。
  ///
  /// 返回写入后的完整列表，便于调用方直接刷新 UI。
  Future<List<String>> add(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return load();
    final current = await load();
    final next = <String>[
      kw,
      for (final e in current)
        if (e != kw) e,
    ];
    if (next.length > maxEntries) next.removeRange(maxEntries, next.length);
    try {
      final p = await _p();
      await p.setString(storageKey, jsonEncode(next));
    } catch (_) {
      // 写失败不影响搜索本身
    }
    return next;
  }

  /// 清空历史。
  Future<void> clear() async {
    try {
      final p = await _p();
      await p.remove(storageKey);
    } catch (_) {}
  }
}

/// 搜索历史 Provider（内存态，读写都落 [SearchHistoryStore]）。
class SearchHistoryController extends StateNotifier<List<String>> {
  SearchHistoryController(this._store) : super(const []) {
    _restore();
  }

  final SearchHistoryStore _store;

  Future<void> _restore() async {
    final list = await _store.load();
    if (!mounted) return;
    state = list;
  }

  Future<void> record(String keyword) async {
    state = await _store.add(keyword);
  }

  Future<void> clear() async {
    await _store.clear();
    state = const [];
  }
}

/// 全局搜索历史。
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryController, List<String>>(
  (ref) => SearchHistoryController(SearchHistoryStore()),
);
