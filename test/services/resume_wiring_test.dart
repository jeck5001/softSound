import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「上次播放」恢复链路的**静态接线守卫**。
///
/// 背景（用户反馈）：退出 App 再打开，上次播放的没了。实际是四处独立缺失：
/// 1. 进度只写不读（启动时没有任何恢复代码）；
/// 2. 听过但没收藏的书不在 `books` 表 → 查不到书名；
/// 3. 书源异步加载，恢复时列表还是空的 → 被判成「源已删除」；
/// 4. 恢复后未装载音源，定时保存把 position 写成 0 → 续播从 00:00 开始。
///
/// 这些都不是能靠单测覆盖的 UI 时序问题，用静态扫描把接线钉住。
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('启动恢复', () {
    test('应用外壳在启动时调用恢复器', () {
      final src = read('lib/app/routes.dart');
      expect(src.contains('sessionRestorerProvider'), isTrue);
      expect(src.contains('restoreOnce()'), isTrue,
          reason: '没有这一步，重启后播放器永远是空的');
    });

    test('恢复逻辑等待书源加载完成', () {
      final src = read('lib/services/last_played_service.dart');
      expect(src.contains('_waitSources'), isTrue,
          reason: '书源是异步加载的，不等就会在空列表上判定「源已删除」');
      expect(src.contains('ref.watch(sourcesProvider)'), isTrue,
          reason: '必须 watch：书源就绪后要重算，read 会缓存住 null');
    });

    test('恢复后不自动起播（避免一开 App 就出声）', () {
      final src = read('lib/services/player_service.dart');
      final restoreBlock = src.substring(
        src.indexOf('Future<bool> restoreSession'),
        src.indexOf('void _startProgressSaveTimer'),
      );
      expect(restoreBlock.contains('_player.play()'), isFalse,
          reason: '恢复会话只装载，不自动播放');
    });
  });

  group('进度不被清空', () {
    test('没有装载音源时不写进度', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('音频源未装载'), isTrue,
          reason: '恢复会话后 position 是 0，写进去会把上次听到的位置冲掉');
    });

    test('恢复会话把进度写进 state', () {
      final src = read('lib/services/player_service.dart');
      final block = src.substring(
        src.indexOf('Future<bool> restoreSession'),
        src.indexOf('void _startProgressSaveTimer'),
      );
      expect(block.contains('position: Duration(milliseconds: positionMs)'),
          isTrue);
    });

    test('togglePlay 走 play()，让「无音源」时先装载章节', () {
      final src = read('lib/services/player_service.dart');
      final block = src.substring(
        src.indexOf('Future<void> togglePlay'),
        src.indexOf('/// 播放。'),
      );
      expect(block.contains('await play()'), isTrue,
          reason: '直接 _player.play() 在没有音源时是空操作，点了没反应');
    });
  });

  group('听过的书要落库', () {
    test('播放章节时记录书籍元数据', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('touchPlayedBook'), isTrue);
    });

    test('记录书籍不改书架状态', () {
      final src = read('lib/data/repositories/book_repository.dart');
      final block = src.substring(
        src.indexOf('Future<void> touchPlayedBook'),
        src.indexOf('Future<void> removeFromBookshelf'),
      );
      expect(block.contains('inBookshelf: const Value(false)'), isTrue,
          reason: '听过不等于收藏');
      expect(block.contains('Name: Value'), isFalse); // 防止误改字段名
      expect(block.contains('name: Value(book.name)'), isTrue,
          reason: '已有记录只刷新元数据');
    });
  });

  group('历史排序稳定性', () {
    test('按时间 + 自增 id 双键排序', () {
      final src = read('lib/data/repositories/play_history_repository.dart');
      expect(src.contains('OrderingTerm.desc(t.lastPlayTime)'), isTrue);
      expect(src.contains('OrderingTerm.desc(t.id)'), isTrue,
          reason: 'drift dateTime 精度是秒，同秒写入需要 id 兜底');
    });
  });
}
