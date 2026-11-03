import '../data/models/chapter.dart';

/// 章节目录分段（聆阅：**100 集一页**）。
///
/// 背景：一本有声书动辄上千集（实测《盗墓笔记》793 集、《道士不好惹》4715 集）。
/// 把全部章节塞进一个长列表，用户「找后面章节非常麻烦」——只能一直滚。
/// 聆阅在详情页和目录弹窗里都用「1-100集 / 101-200集 …」的分段 chips，
/// 本项目此前**只有详情页有分段，播放页目录没有**（用户实测反馈）。
///
/// 这里把规则抽成纯函数，两处共用，避免再次走偏。
class ChapterSegments {
  const ChapterSegments._();

  /// 每段章节数（聆阅逐字：100）。
  static const int pageSize = 100;

  /// 计算所有分段区间（左闭右开）。
  ///
  /// 例：`total = 250` → `[(0,100), (100,200), (200,250)]`
  static List<(int, int)> ranges(int total) {
    if (total <= 0) return const [];
    return [
      for (var i = 0; i < total; i += pageSize)
        (i, i + pageSize > total ? total : i + pageSize),
    ];
  }

  /// 分段标签（聆阅：`1-100集`）。索引从 1 开始展示。
  static String label((int, int) range) => '${range.$1 + 1}-${range.$2}集';

  /// 某个章节下标属于第几段。
  ///
  /// 用于打开目录时**自动跳到当前章所在段**——否则用户从第 700 章
  /// 打开目录，还得先手动翻到「601-700集」。
  static int pageOf(int chapterIndex) {
    if (chapterIndex < 0) return 0;
    return chapterIndex ~/ pageSize;
  }

  /// 取某一段的章节。
  static List<Chapter> slice(
    List<Chapter> chapters,
    int page, {
    bool ascending = true,
  }) {
    final rs = ranges(chapters.length);
    if (rs.isEmpty) return const [];
    final safe = page.clamp(0, rs.length - 1);
    final part = chapters.sublist(rs[safe].$1, rs[safe].$2);
    return ascending ? part : part.reversed.toList();
  }
}
