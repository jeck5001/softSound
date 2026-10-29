import '../data/models/book.dart';

/// 搜索结果相关性排序 / 过滤。
///
/// 上游（懒人 PHP 接口等）返回的是**模糊匹配**：搜「大唐明月」会带回
/// 「惊！她能穿梭时空」这类完全无关的书，我们此前原样展示 →
/// 用户看到的就是「搜索结果很不准确」。
///
/// 这里按关键词与书名/作者的匹配强度打分：
///
/// | 情况 | 分 |
/// |---|---|
/// | 书名与关键词完全相同 | 100 |
/// | 书名以关键词开头 | 80 |
/// | 书名包含关键词 | 60 |
/// | 作者包含关键词 | 40 |
/// | 都不匹配 | 0 |
///
/// 只要**有任何一条命中**，就把 0 分的丢掉；一条都没命中时全保留
/// （拼音、同义词、繁体等无法用字符串判断，宁可多给不给错杀）。
class SearchRelevance {
  const SearchRelevance._();

  /// 标题里常见的装饰字符（书名号、竖线、各种标点）。
  ///
  /// 用 raw string + `\-` 转义连字符：放在字符类中间不转义会被当成
  /// 区间（`'` 到 `—`），把字母也一起吃掉。
  static final RegExp _punctuation = RegExp(
    r'[\s《》〈〉【】\[\]（）(){}|｜·、,，.。!！?？:：;；"“”‘’\-—_~`]',
  );

  /// 计算单本书与关键词的相关度。
  static int score(Book book, String keyword) {
    final kw = normalize(keyword);
    if (kw.isEmpty) return 0;

    final name = normalize(book.name);
    if (name.isEmpty) return 0;

    if (name == kw) return 100;
    if (name.startsWith(kw)) return 80;
    if (name.contains(kw)) return 60;
    if (normalize(book.author ?? '').contains(kw)) return 40;
    // 演播者命中（搜「夙染白」这类人名）
    if (normalize(book.narrator ?? '').contains(kw)) return 30;
    return 0;
  }

  /// 清洗作者字段。
  ///
  /// 有些书源（如「恋」源）返回的 author 本身就带前缀 —— `作者：邵雪城`，
  /// 界面外面又拼了一次「作者: 」，于是显示成 `作者: 作者：邵雪城`。
  /// 在入口处去掉，书架/历史/详情也都跟着干净。
  static String? cleanAuthor(String? raw) {
    var v = raw?.trim() ?? '';
    if (v.isEmpty) return raw;
    v = v.replaceFirst(RegExp(r'^(作者|著者)\s*[:：]\s*'), '');
    v = v.replaceFirst(RegExp(r'^(by|author)\s*[:：]\s*', caseSensitive: false), '');
    v = v.trim();
    return v.isEmpty ? raw : v;
  }

  /// 归一化：去空白、标点与书名号，全角转半角，英文小写。
  ///
  /// 上游标题常带 `|《原著》` 之类的装饰，不归一化会误判。
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      var c = rune;
      // 全角 → 半角（ASCII 可见区）
      if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0;
      if (c == 0x3000) continue; // 全角空格
      final ch = String.fromCharCode(c);
      if (_punctuation.hasMatch(ch)) continue;
      buffer.write(ch.toLowerCase());
    }
    return buffer.toString();
  }

  /// 排序 + 过滤。
  ///
  /// 稳定排序：同分时保持上游原始顺序（上游本身有播放量权重）。
  static List<Book> rank(List<Book> books, String keyword) {
    if (books.isEmpty) return books;
    final scored = <({Book book, int index, int score})>[
      for (var i = 0; i < books.length; i++)
        (book: books[i], index: i, score: score(books[i], keyword)),
    ];

    final hasHit = scored.any((e) => e.score > 0);
    final kept = hasHit ? scored.where((e) => e.score > 0).toList() : scored;

    kept.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.index.compareTo(b.index);
    });

    return [for (final e in kept) e.book];
  }
}
