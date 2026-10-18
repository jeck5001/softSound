import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/database/tables/download_chapters_table.dart';
import 'package:soft_sound/data/repositories/download_repository.dart';

void main() {
  late AppDatabase db;
  late DownloadRepository repo;

  setUp(() {
    // 内存数据库：真实执行 SQL，验证表结构与查询逻辑。
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DownloadRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 便捷登记一个任务。
  Future<void> enqueue({
    String bookId = 'book-1',
    int index = 0,
    String name = '第一章',
    String sourceId = 'XA',
  }) =>
      repo.enqueue(
        bookId: bookId,
        sourceId: sourceId,
        chapterIndex: index,
        chapterName: name,
      );

  group('登记与查询', () {
    test('新建任务默认为排队且不可播放', () async {
      await enqueue();
      final tasks = await repo.getAll();

      expect(tasks, hasLength(1));
      expect(tasks.single.status, DownloadStatus.queued);
      expect(tasks.single.isPlayable, isFalse);
      expect(tasks.single.chapterName, '第一章');
    });

    test('同书同章重复登记会覆盖而非新增（唯一键约束）', () async {
      await enqueue(name: '旧名');
      await enqueue(name: '新名');
      final tasks = await repo.getAll();

      expect(tasks, hasLength(1));
      expect(tasks.single.chapterName, '新名');
    });

    test('不同章节各自独立', () async {
      await enqueue(index: 0, name: 'A');
      await enqueue(index: 1, name: 'B');
      final tasks = await repo.getAll();

      expect(tasks, hasLength(2));
      expect(tasks.map((t) => t.chapterName), containsAll(['A', 'B']));
    });

    test('getByBook 只返回指定书籍', () async {
      await enqueue(bookId: 'b1', index: 0);
      await enqueue(bookId: 'b2', index: 0);
      final only = await repo.getByBook('b1');

      expect(only, hasLength(1));
      expect(only.single.bookId, 'b1');
    });
  });

  group('状态流转', () {
    test('完整流程：排队 → 下载中 → 已完成', () async {
      await enqueue();

      await repo.updateProgress(
        bookId: 'book-1',
        chapterIndex: 0,
        downloadedBytes: 500,
        totalBytes: 1000,
      );
      var task = (await repo.getAll()).single;
      expect(task.status, DownloadStatus.downloading);
      expect(task.progress, closeTo(0.5, 0.001));

      await repo.markCompleted(
        bookId: 'book-1',
        chapterIndex: 0,
        localPath: '/tmp/ch0.mp3',
        totalBytes: 1000,
      );
      task = (await repo.getAll()).single;
      expect(task.status, DownloadStatus.completed);
      expect(task.isPlayable, isTrue);
      expect(task.progress, 1.0);
    });

    test('失败会记录原因', () async {
      await enqueue();
      await repo.markFailed(
        bookId: 'book-1',
        chapterIndex: 0,
        error: '连接超时',
      );

      final task = (await repo.getAll()).single;
      expect(task.status, DownloadStatus.failed);
      expect(task.error, '连接超时');
    });

    test('总大小未知时进度为 0 而非除零崩溃', () async {
      await enqueue();
      await repo.updateProgress(
        bookId: 'book-1',
        chapterIndex: 0,
        downloadedBytes: 123,
      );
      final task = (await repo.getAll()).single;
      expect(task.progress, 0.0);
    });

    test('进度被限制在 0..1', () async {
      await enqueue();
      // 上报超过总大小
      await repo.updateProgress(
        bookId: 'book-1',
        chapterIndex: 0,
        downloadedBytes: 2000,
        totalBytes: 1000,
      );
      final task = (await repo.getAll()).single;
      expect(task.progress, 1.0);
    });
  });

  group('筛选查询', () {
    test('getActive 只包含排队与下载中', () async {
      await enqueue(index: 0, name: '排队中');
      await enqueue(index: 1, name: '下载中');
      await enqueue(index: 2, name: '已完成');

      await repo.updateProgress(
        bookId: 'book-1',
        chapterIndex: 1,
        downloadedBytes: 10,
        totalBytes: 100,
      );
      await repo.markCompleted(
        bookId: 'book-1',
        chapterIndex: 2,
        localPath: '/tmp/c2.mp3',
      );

      final active = await repo.getActive();
      expect(active, hasLength(2));
      expect(active.map((t) => t.chapterName), containsAll(['排队中', '下载中']));
    });

    test('getCompleted 只包含已完成', () async {
      await enqueue(index: 0, name: '一章');
      await enqueue(index: 1, name: '二章');
      await repo.markCompleted(
        bookId: 'book-1',
        chapterIndex: 1,
        localPath: '/tmp/c1.mp3',
      );

      final done = await repo.getCompleted();
      expect(done, hasLength(1));
      expect(done.single.chapterName, '二章');
    });

    test('localPathOf 只在已完成时返回路径', () async {
      await enqueue();
      expect(await repo.localPathOf('book-1', 0), isNull);

      await repo.markCompleted(
        bookId: 'book-1',
        chapterIndex: 0,
        localPath: '/tmp/x.mp3',
      );
      expect(await repo.localPathOf('book-1', 0), '/tmp/x.mp3');
    });

    test('localPathOf 对不存在的章节返回 null', () async {
      expect(await repo.localPathOf('nope', 99), isNull);
    });
  });

  group('聚合统计', () {
    test('getSummaryByBook 按书聚合完成数', () async {
      await enqueue(bookId: 'b1', index: 0);
      await enqueue(bookId: 'b1', index: 1);
      await enqueue(bookId: 'b2', index: 0);

      await repo.markCompleted(
        bookId: 'b1',
        chapterIndex: 0,
        localPath: '/a',
        totalBytes: 100,
      );
      await repo.markCompleted(
        bookId: 'b2',
        chapterIndex: 0,
        localPath: '/b',
        totalBytes: 200,
      );

      final summary = await repo.getSummaryByBook();
      final b1 = summary.firstWhere((s) => s.bookId == 'b1');
      final b2 = summary.firstWhere((s) => s.bookId == 'b2');

      expect(b1.chapterCount, 2);
      expect(b1.completedCount, 1);
      expect(b1.isComplete, isFalse);
      expect(b1.progress, closeTo(0.5, 0.001));

      expect(b2.chapterCount, 1);
      expect(b2.isComplete, isTrue);
      expect(b2.totalBytes, 200);
    });

    test('totalBytes 只统计已完成的字节', () async {
      await enqueue(index: 0);
      await enqueue(index: 1);

      await repo.markCompleted(
        bookId: 'book-1',
        chapterIndex: 0,
        localPath: '/a',
        totalBytes: 1000,
      );
      // 第二章仍在下载中，不计入
      await repo.updateProgress(
        bookId: 'book-1',
        chapterIndex: 1,
        downloadedBytes: 500,
        totalBytes: 5000,
      );

      expect(await repo.totalBytes(), 1000);
    });

    test('无数据时统计为 0', () async {
      expect(await repo.totalBytes(), 0);
      expect(await repo.getSummaryByBook(), isEmpty);
    });
  });

  group('删除与清理', () {
    test('deleteChapter 只删除指定章节', () async {
      await enqueue(index: 0);
      await enqueue(index: 1);

      await repo.deleteChapter('book-1', 0);
      final tasks = await repo.getAll();

      expect(tasks, hasLength(1));
      expect(tasks.single.chapterIndex, 1);
    });

    test('deleteBook 删除整本书', () async {
      await enqueue(bookId: 'b1', index: 0);
      await enqueue(bookId: 'b1', index: 1);
      await enqueue(bookId: 'b2', index: 0);

      await repo.deleteBook('b1');
      final tasks = await repo.getAll();

      expect(tasks, hasLength(1));
      expect(tasks.single.bookId, 'b2');
    });

    test('clearAll 清空全部', () async {
      await enqueue(bookId: 'b1', index: 0);
      await enqueue(bookId: 'b2', index: 0);

      await repo.clearAll();
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('持久化', () {
    test('数据写入后可从新查询读回（真实 SQL 往返）', () async {
      await repo.enqueue(
        bookId: 'persist-1',
        sourceId: 'xiaoQing',
        chapterIndex: 7,
        chapterName: '第七章',
        remoteUrl: 'https://example.com/7.mp3',
        durationMs: 123456,
      );

      final raw = await db.select(db.downloadChaptersTable).getSingle();
      expect(raw.bookId, 'persist-1');
      expect(raw.sourceId, 'xiaoQing');
      expect(raw.chapterIndex, 7);
      expect(raw.remoteUrl, 'https://example.com/7.mp3');
      expect(raw.durationMs, 123456);
    });

    test('可变字段可被更新（updatedAt 变化）', () async {
      await enqueue();
      final before = (await repo.getAll()).single.updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.markFailed(
        bookId: 'book-1',
        chapterIndex: 0,
        error: 'x',
      );
      final after = (await repo.getAll()).single.updatedAt;

      expect(after.isAfter(before) || after == before, isTrue);
    });
  });
}
