import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 目录不全（数量不对）的守卫。
///
/// 用户反馈：播放页的目录数量不对、不全。
///
/// 根因：章节列表要**分页拉取**（懒人 pageSize=60，5795 集 = 97 页），
/// 旧实现在任意一页失败时 `break`，保留前面成功的页、**静默丢弃后半段**：
///
/// ```dart
/// if (response == null) break;   // ← 第 N 页 429/超时就少掉 N 百集
/// ```
///
/// Edge 有项目级并发限制（429 projectConcurrencyLimitExceeded），
/// 连拉近百页时命中概率很高。酷我适配器此前踩过同样的坑，注释写着
/// 「这正是『聆阅里 900 多集、这里只有 600 集』的成因」。
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('分页失败必须重试，不能静默截断', () {
    test('有重试辅助且默认重试多次', () {
      final src =
          read('lib/services/typed_sources/lrts_source_adapter.dart');
      expect(src.contains('_getMenuPageWithRetry'), isTrue);
      expect(src.contains('int attempts = 3'), isTrue);
    });

    test('重试之间有退避（避免继续打爆 429）', () {
      final src =
          read('lib/services/typed_sources/lrts_source_adapter.dart');
      expect(src.contains('Future<void>.delayed'), isTrue);
      expect(src.contains('400 * (1 << i)'), isTrue);
    });

    test('分页循环不再因单页失败直接 break', () {
      final src =
          read('lib/services/typed_sources/lrts_source_adapter.dart');
      final start = src.indexOf('Future<List<Chapter>> getChapterList');
      final block = src.substring(start, start + 2600);
      // 只检查**代码**，注释里会引用这串旧写法作为说明
      final code = block
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains('if (response == null) break'),
        isFalse,
        reason: '这正是丢掉后半段的写法',
      );
      expect(block.contains('_getMenuPageWithRetry'), isTrue);
    });

    test('取不全时记录日志，便于定位', () {
      final src =
          read('lib/services/typed_sources/lrts_source_adapter.dart');
      expect(src.contains('目录不完整'), isTrue);
    });
  });

  group('UI 不能假装「就这么多集」', () {
    test('目录用 Book.chapterCount 与本地列表比对', () {
      final src = read('lib/features/player/player_page.dart');
      expect(src.contains('expectedCount'), isTrue);
      expect(
        src.contains('currentBook?.chapterCount'),
        isTrue,
        reason: 'chapterCount 是上游声明的总集数',
      );
    });

    test('缺集时显示告警并提供重试', () {
      final src = read('lib/features/player/player_page.dart');
      expect(src.contains('目录可能不全'), isTrue);
      expect(src.contains('已加载 \$total 集，共 \$expected 集'), isTrue);
      expect(src.contains('重试'), isTrue);
    });

    test('播放器暴露 refreshChapters 供手动拉取', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('Future<bool> refreshChapters()'), isTrue);
    });
  });

  group('真实规模（回归数值）', () {
    test('5795 集需要 97 页，任何一页丢失都缺 60 集', () {
      const total = 5795;
      const pageSize = 60;
      final pages = (total + pageSize - 1) ~/ pageSize;
      expect(pages, 97);
      // 丢一页就少 60 集 —— 用户能明显看出"不全"
      expect(pageSize, 60);
    });

    test('翻页上限覆盖真实最大书', () {
      final src =
          read('lib/services/typed_sources/lrts_source_adapter.dart');
      expect(src.contains('_maxMenuPages = 120'), isTrue);
      expect(120 * 60, greaterThan(5795));
    });
  });
}
