import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models/chapter.dart';
import '../data/repositories/download_repository.dart';
import 'source_parser.dart';

/// 单章下载结果。
class DownloadOutcome {
  /// 是否成功。
  final bool success;

  /// 本地文件路径（成功时）。
  final String? localPath;

  /// 失败原因（失败时）。
  final String? error;

  /// 是否被取消。
  final bool cancelled;

  const DownloadOutcome._({
    required this.success,
    this.localPath,
    this.error,
    this.cancelled = false,
  });

  const DownloadOutcome.success(String path)
      : this._(success: true, localPath: path);

  const DownloadOutcome.failure(String message)
      : this._(success: false, error: message);

  const DownloadOutcome.cancelled()
      : this._(success: false, cancelled: true);
}

/// 音频下载器。
///
/// 负责把章节音频落盘到应用目录，并同步 [DownloadRepository] 的状态，
/// 使下载管理页能展示真实进度。
///
/// 设计要点：
/// - 通过 [downloadChapter] 串行下载，避免并发抢占带宽；
/// - 支持按「书 + 章」取消；
/// - 文件先写 `.part` 再原子改名，避免中断留下损坏文件；
/// - 失败会写入 `error` 字段，供 UI 展示与重试。
class AudioDownloader {
  final DownloadRepository _repo;
  final SourceParser _parser;
  final Dio _dio;

  /// 每本书的取消令牌。
  final Map<String, CancelToken> _tokens = {};

  AudioDownloader(
    this._repo, {
    SourceParser? parser,
    Dio? dio,
  })  : _parser = parser ?? SourceParser(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 10),
            ));

  /// 下载目录：应用文档目录下的 `downloads/`。
  Future<Directory> _downloadDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 生成安全的本地文件名。
  String _fileName(String bookId, int chapterIndex) {
    final safeBook = bookId.replaceAll(RegExp(r'[^\w.-]'), '_');
    return '${safeBook}_$chapterIndex.m4a';
  }

  /// 取消某本书的全部进行中下载。
  void cancelBook(String bookId) {
    _tokens.remove(bookId)?.cancel('用户取消下载');
  }

  /// 取消全部下载。
  void cancelAll() {
    for (final token in _tokens.values) {
      token.cancel('用户取消下载');
    }
    _tokens.clear();
  }

  /// 下载单章。
  ///
  /// [sourceId] 用于登记；[chapter] 需能解析出音频地址
  /// （优先用 `chapter.audioUrl`，否则经 [SourceParser] 解析）。
  Future<DownloadOutcome> downloadChapter({
    required String bookId,
    required String sourceId,
    required Chapter chapter,
    required dynamic source, // SourceRule
    void Function(int received, int total)? onProgress,
  }) async {
    final index = chapter.index;
    final fileName = _fileName(bookId, index);

    try {
      // 1) 解析音频地址
      var url = chapter.audioUrl;
      if (url == null || url.isEmpty) {
        url = await _parser.getAudioUrl(source, chapter);
      }
      if (url == null || url.isEmpty) {
        await _repo.markFailed(
          bookId: bookId,
          chapterIndex: index,
          error: '无法获取音频地址',
        );
        return const DownloadOutcome.failure('无法获取音频地址');
      }

      // 2) 登记任务（若已存在则覆盖为下载中）
      await _repo.enqueue(
        bookId: bookId,
        sourceId: sourceId,
        chapterIndex: index,
        chapterName: chapter.name,
        remoteUrl: url,
        durationMs: chapter.duration ?? 0,
      );

      final dir = await _downloadDir();
      final finalPath = p.join(dir.path, fileName);
      final partPath = '$finalPath.part';

      // 3) 下载到 .part
      final token = CancelToken();
      _tokens[bookId] = token;

      await _dio.download(
        url,
        partPath,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _repo.updateProgress(
              bookId: bookId,
              chapterIndex: index,
              downloadedBytes: received,
              totalBytes: total,
            );
          }
          onProgress?.call(received, total);
        },
      );

      // 4) 原子改名
      final partFile = File(partPath);
      final bytes = await partFile.length();
      await partFile.rename(finalPath);

      await _repo.markCompleted(
        bookId: bookId,
        chapterIndex: index,
        localPath: finalPath,
        totalBytes: bytes,
      );

      _tokens.remove(bookId);
      return DownloadOutcome.success(finalPath);
    } on DioException catch (e) {
      _tokens.remove(bookId);
      if (CancelToken.isCancel(e)) {
        // 取消：清理半成品，状态回到排队以便重试
        await _cleanupPartFile(bookId, index);
        await _repo.enqueue(
          bookId: bookId,
          sourceId: sourceId,
          chapterIndex: index,
          chapterName: chapter.name,
        );
        return const DownloadOutcome.cancelled();
      }
      await _cleanupPartFile(bookId, index);
      await _repo.markFailed(
        bookId: bookId,
        chapterIndex: index,
        error: _describe(e),
      );
      return DownloadOutcome.failure(_describe(e));
    } catch (e) {
      _tokens.remove(bookId);
      await _cleanupPartFile(bookId, index);
      await _repo.markFailed(
        bookId: bookId,
        chapterIndex: index,
        error: '$e',
      );
      return DownloadOutcome.failure('$e');
    }
  }

  /// 批量下载（串行），返回成功/失败计数。
  Future<({int ok, int failed})> downloadChapters({
    required String bookId,
    required String sourceId,
    required List<Chapter> chapters,
    required dynamic source, // SourceRule
    void Function(int done, int total)? onBatchProgress,
  }) async {
    var ok = 0;
    var failed = 0;

    for (var i = 0; i < chapters.length; i++) {
      final outcome = await downloadChapter(
        bookId: bookId,
        sourceId: sourceId,
        chapter: chapters[i],
        source: source,
      );
      if (outcome.success) {
        ok++;
      } else if (!outcome.cancelled) {
        failed++;
      } else {
        // 被取消则停止后续
        break;
      }
      onBatchProgress?.call(i + 1, chapters.length);
    }

    return (ok: ok, failed: failed);
  }

  /// 删除本地文件（供清理缓存使用）。
  Future<void> deleteLocalFile(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return;
    try {
      final f = File(localPath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('删除缓存文件失败: $e');
    }
  }

  Future<void> _cleanupPartFile(String bookId, int index) async {
    try {
      final dir = await _downloadDir();
      final part = File(p.join(dir.path, '${_fileName(bookId, index)}.part'));
      if (await part.exists()) await part.delete();
    } catch (e) {
      debugPrint('清理临时文件失败: $e');
    }
  }

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.receiveTimeout:
        return '接收超时';
      case DioExceptionType.connectionError:
        return '网络异常';
      case DioExceptionType.badResponse:
        return '服务器返回 ${e.response?.statusCode}';
      default:
        return e.message ?? '下载失败';
    }
  }
}

/// 音频下载器 Provider。
final audioDownloaderProvider = Provider<AudioDownloader>((ref) {
  return AudioDownloader(ref.watch(downloadRepositoryProvider));
});
