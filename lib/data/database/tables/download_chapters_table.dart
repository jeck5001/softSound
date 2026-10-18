import 'package:drift/drift.dart';

/// 下载任务状态。
///
/// 取值对齐聆阅的下载态文案：排队 / 下载中 / 已下载 / 失败。
enum DownloadStatus {
  /// 排队中（聆阅：`排队`）
  queued,

  /// 下载中（聆阅：`正在下载`）
  downloading,

  /// 已完成（聆阅：`已下载`）
  completed,

  /// 失败（聆阅：`下载失败`）
  failed,
}

/// 下载章节表 —— 缓存/离线收听的核心数据。
///
/// 每行代表「某本书的某一章」的下载状态与本地文件位置，
/// 支撑「下载管理」「已缓存章节」「离线收听」三类界面。
class DownloadChaptersTable extends Table {
  @override
  String get tableName => 'download_chapters';

  IntColumn get id => integer().autoIncrement()();

  /// 所属书籍 ID（与 BooksTable.bookId 对应）。
  TextColumn get bookId => text()();

  /// 书源 ID，便于按源清理。
  TextColumn get sourceId => text()();

  /// 章节序号（与 Chapter 列表顺序一致）。
  IntColumn get chapterIndex => integer()();

  /// 章节名，用于列表展示。
  TextColumn get chapterName => text()();

  /// 远端音频地址（缓存来源）。
  TextColumn get remoteUrl => text().nullable()();

  /// 本地文件路径；完成后才有值。
  TextColumn get localPath => text().nullable()();

  /// 已下载字节数，用于进度展示。
  IntColumn get downloadedBytes =>
      integer().withDefault(const Constant(0))();

  /// 文件总字节数；未知时为 0。
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();

  /// 下载状态（存 [DownloadStatus] 的 index）。
  IntColumn get status => intEnum<DownloadStatus>()
      .withDefault(Constant(DownloadStatus.queued.index))();

  /// 失败原因。
  TextColumn get error => text().nullable()();

  /// 音频时长（毫秒），用于展示与空间统计。
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 同一本书的同一章只允许一条记录。
  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, chapterIndex},
      ];
}
