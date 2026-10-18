import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/repositories/book_repository.dart';
import 'package:soft_sound/data/repositories/download_repository.dart';
import 'package:soft_sound/features/downloads/downloads_notifier.dart';

/// 验证「设置页清缓存」与「下载页」共享同一份真实数据。
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// 造一条已完成的下载记录。
  Future<void> seed(String bookId, int index, {String? path}) async {
    final repo = container.read(downloadRepositoryProvider);
    await repo.enqueue(
      bookId: bookId,
      sourceId: 'XA',
      chapterIndex: index,
      chapterName: '第$index章',
    );
    if (path != null) {
      await repo.markCompleted(
        bookId: bookId,
        chapterIndex: index,
        localPath: path,
        totalBytes: 1024,
      );
    }
  }

  group('DownloadsNotifier', () {
    test('初始加载：进行中与已完成分别归类', () async {
      await seed('b1', 0, path: '/tmp/0.mp3');
      await seed('b1', 1);

      // 触发 provider 创建（构造时会 refresh）
      container.read(downloadsProvider);
      await container.read(downloadsProvider.notifier).refresh();

      final state = container.read(downloadsProvider);
      expect(state.completed, hasLength(1));
      expect(state.active, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('deleteChapter 后列表刷新', () async {
      await seed('b1', 0, path: '/tmp/0.mp3');
      await seed('b1', 1, path: '/tmp/1.mp3');

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.refresh();
      expect(container.read(downloadsProvider).completed, hasLength(2));

      await notifier.deleteChapter('b1', 0);
      final after = container.read(downloadsProvider).completed;
      expect(after, hasLength(1));
      expect(after.single.chapterIndex, 1);
    });

    test('deleteBook 移除整本', () async {
      await seed('b1', 0, path: '/a');
      await seed('b2', 0, path: '/b');

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.refresh();
      await notifier.deleteBook('b1');

      final after = container.read(downloadsProvider).completed;
      expect(after, hasLength(1));
      expect(after.single.bookId, 'b2');
    });

    test('clearAll 清空并让统计归零', () async {
      await seed('b1', 0, path: '/a');
      await seed('b1', 1, path: '/b');

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.refresh();
      expect(container.read(downloadsProvider).totalBytes, greaterThan(0));

      await notifier.clearAll();
      final after = container.read(downloadsProvider);
      expect(after.completed, isEmpty);
      expect(after.active, isEmpty);
      expect(after.totalBytes, 0);
    });

    test('totalBytes 汇总已完成章节', () async {
      await seed('b1', 0, path: '/a');
      await seed('b1', 1, path: '/b');

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.refresh();

      // 每章 markCompleted 时写入 1024 字节
      expect(container.read(downloadsProvider).totalBytes, 2048);
    });
  });

  group('cacheUsageProvider（设置页用量）', () {
    test('与下载数据一致', () async {
      await seed('b1', 0, path: '/a');
      await seed('b1', 1, path: '/b');

      final bytes = await container.read(cacheUsageProvider.future);
      expect(bytes, 2048);
    });

    test('无缓存时为 0', () async {
      final bytes = await container.read(cacheUsageProvider.future);
      expect(bytes, 0);
    });

    test('clearAll 后 invalidate 能读到 0', () async {
      await seed('b1', 0, path: '/a');
      expect(await container.read(cacheUsageProvider.future), 1024);

      await container.read(downloadRepositoryProvider).clearAll();
      container.invalidate(cacheUsageProvider);
      expect(await container.read(cacheUsageProvider.future), 0);
    });
  });

  group('downloadSummaryProvider（按书聚合）', () {
    test('按书汇总章节数与完成数', () async {
      await seed('b1', 0, path: '/a');
      await seed('b1', 1);
      await seed('b2', 0, path: '/c');

      final summary = await container.read(downloadSummaryProvider.future);
      expect(summary, hasLength(2));

      final b1 = summary.firstWhere((s) => s.bookId == 'b1');
      expect(b1.chapterCount, 2);
      expect(b1.completedCount, 1);
      expect(b1.isComplete, isFalse);
    });
  });

  group('bookHasDownloadProvider（书架离线标记）', () {
    test('有已完成章节时为 true', () async {
      await seed('b1', 0, path: '/a');
      expect(
        await container.read(bookHasDownloadProvider('b1').future),
        isTrue,
      );
    });

    test('仅有进行中章节时为 false', () async {
      await seed('b1', 0);
      expect(
        await container.read(bookHasDownloadProvider('b1').future),
        isFalse,
      );
    });

    test('无记录时为 false', () async {
      expect(
        await container.read(bookHasDownloadProvider('nope').future),
        isFalse,
      );
    });
  });
}
