/// 章节顺序工具 —— 移植自聆阅字节码 #17864 / #17865。
///
/// 背景：上游（酷我/懒人/Edge 代理）有时**倒序**返回章节（最新章节在前）。
/// 如果原样渲染，用户看到的是「从最后一集开始」，播放也会反向推进。
///
/// 聆阅的做法不是「无条件排序」，而是**抽样判定 + 整体翻转**：
/// 1. 每 1/60 抽一条（`window = max(1, floor(len / 60))`），
///    用一串正则从标题里抠出集号；
/// 2. 相邻抽样点比较集号，统计升/降次数；
/// 3. 抽样点少于 3 个 → 不动；
/// 4. 总变化数为 0 → 不动；
/// 5. **降序占比 ≥ 0.7** → 整表翻转，否则不动。
///
/// 为什么不是「按集号排序」：很多书的章节名不含集号（或含的是卷号/日期），
/// 强行排序会打乱上游已给出的正确顺序；抽样判定只在「明显倒序」时动手。
library;

/// 从章节标题里抠出「集号 / 章号」。
///
/// 正则级联顺序与字节码 #17864 逐条一致：
///
/// 1. `第\s*(\d+)\s*[集章节回]` —— 最明确的「第 N 集/章/节/回」
/// 2. `(\d+)\s*[集章节回]` —— 「123 集」（无「第」）
/// 3. `^(\d+)[\s._、\-]` —— 开头的「123、xxx」
/// 4. `[\s._、\-\(\[\{（【](\d+)[\s._、\-\)\]\}）】]` —— 被分隔符夹住的数字
/// 5. `[\s._、\-](\d+)$` —— 结尾的「xxx 123」
/// 6. `[^\d](\d+)[\s._、\-]` —— 前面非数字、后面分隔符的数字
/// 7. 兜底：取标题里**最后一组**数字
///
/// 都取不到时返回 `null`（调用方据此跳过该抽样点）。
int? extractChapterNumber(String? title) {
  if (title == null) return null;
  final t = title.trim();
  if (t.isEmpty) return null;

  const patterns = <String>[
    r'第\s*(\d+)\s*[集章节回]',
    r'(\d+)\s*[集章节回]',
    r'^(\d+)[\s._、\-]',
    r'[\s._、\-\(\[\{（【](\d+)[\s._、\-\)\]\}）】]',
    r'[\s._、\-](\d+)$',
    r'[^\d](\d+)[\s._、\-]',
  ];
  for (final p in patterns) {
    final m = RegExp(p).firstMatch(t);
    if (m == null) continue;
    final n = int.tryParse(m.group(1) ?? '');
    if (n != null) return n;
  }
  // 兜底：最后一组数字
  final all = RegExp(r'\d+').allMatches(t).toList();
  if (all.isEmpty) return null;
  return int.tryParse(all.last.group(0)!);
}

/// 判定链：若「明显倒序」则返回翻转后的新列表，否则原样返回。
///
/// [titleOf] 取每个条目的标题；返回 `true` 表示**本次发生了翻转**
/// （便于调用方决定是否需要重建 index）。
bool looksReversed<T>(List<T> items, String? Function(T) titleOf) {
  if (items.length <= 1) return false;
  final window = (items.length / 60).floor();
  final step = window < 1 ? 1 : window;

  // 抽样：{num} 序列（丢 null 与解析失败的项）
  final nums = <int>[];
  for (var i = 0; i < items.length; i += step) {
    final n = extractChapterNumber(titleOf(items[i]));
    if (n == null) continue;
    nums.add(n);
  }
  if (nums.length < 3) return false;

  var asc = 0;
  var desc = 0;
  for (var i = 0; i + 1 < nums.length; i++) {
    if (nums[i + 1] > nums[i]) {
      asc++;
    } else if (nums[i + 1] < nums[i]) {
      desc++;
    }
  }
  final total = asc + desc;
  if (total == 0) return false;
  return desc / total >= 0.7;
}

/// 返回「保证升序」的列表副本（必要时翻转）。
///
/// 与 [looksReversed] 的区别：这里直接给出结果，不额外暴露判定位。
List<T> ensureAscending<T>(List<T> items, String? Function(T) titleOf) {
  if (!looksReversed(items, titleOf)) return items;
  return items.reversed.toList();
}
