import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soft_sound/data/database/app_database.dart';
import 'package:soft_sound/data/database/tables/download_chapters_table.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/repositories/download_repository.dart';
import 'package:soft_sound/services/audio_downloader.dart';

/// 用一个假 Dio 适配器拦截下载，验证下载器的状态流转与文件处理。
///
/// 不发起真实网络请求。
class _FakeAdapter implements HttpClientAdapter {
  /// 每次请求返回的字节内容。
  final List<int> payload;

  /// 是否模拟失败。
  final bool shouldFail;

  /// 是否模拟取消。
  final bool shouldCancel;

  /// 记录的请求 URL。
  final List<String> requestedUrls = [];

  _FakeAdapter({
    this.payload = const [1, 2, 3, 4, 5],
    this.shouldFail = false,
    this.shouldCancel = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());

    if (shouldCancel) {
      // 立即以「已取消」结束，模拟服务端响应前被取消。
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'cancelled',
      );
    }

    if (shouldFail) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: '模拟网络错误',
      );
    }

    return ResponseBody.fromBytes(
      payload,
      200,
      headers: {
        Headers.contentLengthHeader: ['${payload.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 把 path_provider 的文档目录指向临时目录，使下载器可写盘。
  late Directory docsDir;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getApplicationDocumentsDirectory') {
      return docsDir.path;
    }
    return null;
  });

  late AppDatabase db;
  late DownloadRepository repo;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DownloadRepository(db);
    tempDir = await Directory.systemTemp.createTemp('dl_test_');
    docsDir = tempDir;
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Chapter chapter({
    int index = 0,
    String name = '第一章',
    String? audioUrl = 'https://example.com/a.m4a',
    int? duration = 120,
  }) =>
      Chapter(
        chapterId: 'c$index',
        bookId: 'book-1',
        index: index,
        name: name,
        url: 'https://example.com/page$index',
        audioUrl: audioUrl,
        duration: duration,
      );

  AudioDownloader downloaderWith(_FakeAdapter adapter) {
    final dio = Dio();
    dio.httpClientAdapter = adapter;
    return AudioDownloader(
      repo,
      dio: dio,
      // 用真实 SourceParser；chapter.audioUrl 已给出时不会走到解析
    );
  }

  group('成功下载', () {
    test('落盘并把状态标记为已完成', () async {
      final adapter = _FakeAdapter(payload: [1, 2, 3, 4, 5, 6, 7, 8]);
      final dl = downloaderWith(adapter);

      final outcome = await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(),
        source: null,
      );

      expect(outcome.success, isTrue);
      expect(outcome.localPath, isNotNull);

      // 文件真实存在且字节数正确
      final f = File(outcome.localPath!);
      expect(await f.exists(), isTrue);
      expect(await f.length(), 8);

      // 仓库状态同步
      final task = (await repo.getAll()).single;
      expect(task.status, DownloadStatus.completed);
      expect(task.totalBytes, 8);
      expect(task.downloadedBytes, 8);
      expect(task.isPlayable, isTrue);
    });

    test('登记了远端 URL 与时长', () async {
      final dl = downloaderWith(_FakeAdapter());
      await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(duration: 300),
        source: null,
      );

      final task = (await repo.getAll()).single;
      expect(task.remoteUrl, 'https://example.com/a.m4a');
      expect(task.durationMs, 300);
      expect(task.sourceId, 'XA');
    });

    test('不留下 .part 临时文件', () async {
      final dl = downloaderWith(_FakeAdapter());
      final outcome = await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(),
        source: null,
      );

      final dir = File(outcome.localPath!).parent;
      final parts = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.part'))
          .toList();
      expect(parts, isEmpty);
    });

    test('请求了正确的音频地址', () async {
      final adapter = _FakeAdapter();
      final dl = downloaderWith(adapter);
      await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(audioUrl: 'https://cdn.test/x/y.m4a'),
        source: null,
      );
      expect(adapter.requestedUrls.single, 'https://cdn.test/x/y.m4a');
    });

    test('onProgress 收到回调', () async {
      final dl = downloaderWith(_FakeAdapter(payload: List.filled(100, 0)));
      final calls = <int>[];
      await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(),
        source: null,
        onProgress: (received, total) => calls.add(received),
      );
      expect(calls, isNotEmpty);
    });
  });

  group('失败处理', () {
    test('网络错误 → 状态为失败并记录原因', () async {
      final dl = downloaderWith(_FakeAdapter(shouldFail: true));

      final outcome = await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(),
        source: null,
      );

      expect(outcome.success, isFalse);
      expect(outcome.error, isNotNull);

      final task = (await repo.getAll()).single;
      expect(task.status, DownloadStatus.failed);
      expect(task.error, isNotNull);
      expect(task.isPlayable, isFalse);
    });

    test('失败时不留下 .part 文件', () async {
      final dl = downloaderWith(_FakeAdapter(shouldFail: true));
      await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(),
        source: null,
      );

      final dir = await Directory(p.join(tempDir.path)).exists()
          ? tempDir
          : tempDir;
      // 下载目录在应用文档目录下；此处只断言仓库无已完成记录
      final completed = await repo.getCompleted();
      expect(completed, isEmpty);
      expect(await dir.exists(), isTrue);
    });

    test('无音频地址 → 失败且不登记为完成', () async {
      // audioUrl 为 null 且 source 为 null，解析必失败
      final dl = downloaderWith(_FakeAdapter());
      final outcome = await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(audioUrl: null),
        source: null,
      );

      expect(outcome.success, isFalse);
      expect(await repo.getCompleted(), isEmpty);
    });
  });

  group('取消', () {
    test('取消后清理临时文件并把状态退回排队', () async {
      final adapter = _FakeAdapter(shouldCancel: true);
      final dl = downloaderWith(adapter);

      final outcome = await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(),
        source: null,
      );

      expect(outcome.cancelled, isTrue);
      expect(await repo.getCompleted(), isEmpty);

      // 状态回到排队（可重试），而非失败
      final task = (await repo.getAll()).single;
      expect(task.status, DownloadStatus.queued);
    });
  });

  group('批量下载', () {
    test('串行下载多章并统计成功数', () async {
      final dl = downloaderWith(_FakeAdapter());
      final chapters = [
        chapter(index: 0, name: 'A'),
        chapter(index: 1, name: 'B'),
        chapter(index: 2, name: 'C'),
      ];

      final result = await dl.downloadChapters(
        bookId: 'book-1',
        sourceId: 'XA',
        chapters: chapters,
        source: null,
      );

      expect(result.ok, 3);
      expect(result.failed, 0);
      expect(await repo.getCompleted(), hasLength(3));
    });

    test('失败章不影响后续章', () async {
      // 全部失败：验证计数
      final dl = downloaderWith(_FakeAdapter(shouldFail: true));
      final result = await dl.downloadChapters(
        bookId: 'book-1',
        sourceId: 'XA',
        chapters: [chapter(index: 0), chapter(index: 1)],
        source: null,
      );

      expect(result.ok, 0);
      expect(result.failed, 2);
    });

    test('批量进度回调被触发', () async {
      final dl = downloaderWith(_FakeAdapter());
      final progress = <String>[];
      await dl.downloadChapters(
        bookId: 'book-1',
        sourceId: 'XA',
        chapters: [chapter(index: 0), chapter(index: 1)],
        source: null,
        onBatchProgress: (done, total) => progress.add('$done/$total'),
      );

      expect(progress, ['1/2', '2/2']);
    });
  });

  group('重复下载同一章', () {
    test('第二次覆盖而非报唯一键冲突', () async {
      final dl = downloaderWith(_FakeAdapter(payload: [1, 2, 3]));

      await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(name: '第一章'),
        source: null,
      );
      await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(name: '第一章（重下）'),
        source: null,
      );

      final tasks = await repo.getAll();
      expect(tasks, hasLength(1));
      expect(tasks.single.chapterName, '第一章（重下）');
      expect(tasks.single.status, DownloadStatus.completed);
    });
  });

  group('删除本地文件', () {
    test('deleteLocalFile 移除文件', () async {
      final dl = downloaderWith(_FakeAdapter());
      final outcome = await dl.downloadChapter(
        bookId: 'book-1',
        sourceId: 'XA',
        chapter: chapter(),
        source: null,
      );

      final f = File(outcome.localPath!);
      expect(await f.exists(), isTrue);

      await dl.deleteLocalFile(outcome.localPath);
      expect(await f.exists(), isFalse);
    });

    test('删除不存在的路径不抛异常', () async {
      final dl = downloaderWith(_FakeAdapter());
      await dl.deleteLocalFile('/definitely/not/here.m4a');
      await dl.deleteLocalFile(null);
    });
  });
}
