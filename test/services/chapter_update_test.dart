import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 章节更新的获取能力（用户问：后续有章节更新，能正常获取到吧？）。
///
/// 结论来自代码事实，不是猜测：
/// - 章节列表**完全不缓存**（没有章节表，DB 只有 books/play_history/
///   download_chapters/listening_stats），每次进详情/播放都实时拉。
/// - 懒人听书分页 `pageSize=60`，上限 `_maxMenuPages=120` → 7200 集。
///   真实 fixture（lrts_bookinfo_real.json）`sections=5795`，97 页，够用。
///
/// 但有三个缺口，本文件锁住修复：
/// 1. 播放中到最后一章时 `nextChapter()` 直接空转，不会去拉新章节；
/// 2. 详情页没有下拉刷新，用户只能退出重进；
/// 3. 刷新只增不减，避免上游改序把播放位置搞乱。
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('章节列表不缓存（每次实时拉）', () {
    test('数据库没有章节表', () {
      final dir = Directory('lib/data/database/tables');
      final files = dir.listSync().whereType<File>().map((f) =>
          f.path.split('/').last).toList();
      expect(
        files.any((f) => f.contains('chapter') && !f.contains('download')),
        isFalse,
        reason: '有章节表就意味着会读到过期目录',
      );
    });

    test('播放器恢复会话时重新拉章节', () {
      final src = read('lib/services/player_service.dart');
      final start = src.indexOf('Future<bool> restoreSession');
      final block = src.substring(start, start + 3000);
      expect(block.contains('getChapterList'), isTrue);
    });
  });

  group('播放中能拿到新章节（关键缺口 1）', () {
    test('到列表末尾会先刷新再决定', () {
      final src = read('lib/services/player_service.dart');
      final start = src.indexOf('Future<void> nextChapter() async {');
      expect(start, greaterThan(0));
      final block = src.substring(start, start + 700);
      expect(
        block.contains('_refreshChaptersIfGrown'),
        isTrue,
        reason: '不刷新的话，上游更新后用户听到"最后一章"就再也前进不了',
      );
    });

    test('刷新只增不减（不因上游改序打乱进度）', () {
      final src = read('lib/services/player_service.dart');
      final start = src.indexOf('Future<bool> _refreshChaptersIfGrown()');
      final block = src.substring(start, start + 900);
      expect(block.contains('fresh.length > state.chapters.length'), isTrue);
    });

    test('刷新失败不抛异常（网络抖动不该中断播放）', () {
      final src = read('lib/services/player_service.dart');
      final start = src.indexOf('Future<bool> _refreshChaptersIfGrown()');
      final block = src.substring(start, start + 900);
      expect(block.contains('catch'), isTrue);
      expect(block.contains('return false'), isTrue);
    });
  });

  group('用户能手动刷新（关键缺口 2）', () {
    test('详情页有下拉刷新', () {
      final src = read('lib/features/book_detail/book_detail_page.dart');
      expect(src.contains('RefreshIndicator'), isTrue);
      expect(src.contains('AlwaysScrollableScrollPhysics'), isTrue,
          reason: '内容不足一屏时也要能下拉');
    });

    test('notifier 暴露 reload', () {
      final src = read('lib/features/book_detail/book_detail_page.dart');
      expect(src.contains('Future<void> reload()'), isTrue);
    });
  });

  group('分页容量（懒人听书）', () {
    test('上限 7200 集，覆盖真实 5795 集', () {
      final src = read('lib/services/typed_sources/lrts_source_adapter.dart');
      expect(src.contains('_maxMenuPages = 120'), isTrue);
      expect(src.contains('pageSize = 60'), isTrue);
      expect(120 * 60, greaterThanOrEqualTo(5795));
    });
  });
}
