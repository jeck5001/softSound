import 'package:drift/drift.dart';

/// 目录缓存表 —— 让「章节列表」可以跨会话累积补齐。
///
/// 为什么需要：懒人目录要**连拉近百页**（5795 集 = 97 页），
/// 而书源代理（Edge）有项目级并发限制，实测会返回 429 / 500
/// `InvalidWorkerCreation`。一次会话很难 100% 拉全；
/// 旧实现每次都从零重拉，于是**永远差几页**。
///
/// 有了这张表，每次把成功拿到的页写进来，多次进入即可累积成完整目录。
/// 上游响应里每章都带 `section`（书内绝对序号），因此按序号存储
/// 不会因为缺页而错位。
class BookChaptersTable extends Table {
  @override
  String get tableName => 'book_chapters';

  IntColumn get id => integer().autoIncrement()();

  /// 书籍 ID（与 BooksTable.bookId 对应）。
  TextColumn get bookId => text()();

  /// 书源 ID，便于按源清理。
  TextColumn get sourceId => text().withDefault(const Constant(''))();

  /// 上游 `section` 序号（1 起）。**存原值**，缺页时会有空洞，
  /// 正是靠它判断目录是否完整。
  IntColumn get section => integer()();

  /// 章节 token（真实响应中 id 与 sectionId 相同），换音频地址要用。
  TextColumn get chapterId => text()();

  TextColumn get name => text()();

  /// 时长（毫秒）；上游未给时为 0。
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// 是否付费/不可听（上游 feeType/payType/cantListen 归一）。
  BoolColumn get isVip => boolean().withDefault(const Constant(false))();

  /// 直接可用的音频地址（多数章节为空，播放时再换）。
  TextColumn get audioUrl => text().nullable()();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// 同一本书的同一个 section 只允许一条。
  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, section},
      ];
}
