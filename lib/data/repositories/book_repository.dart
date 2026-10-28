import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/book.dart';

/// 数据库 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

/// 书籍数据访问层
class BookRepository {
  final AppDatabase _db;

  BookRepository(this._db);

  /// 添加书籍到书架。
  ///
  /// 冲突目标必须是 `book_id`（业务唯一键），不能只靠主键：
  /// `touchPlayedBook` 可能已经为这本书插了一行（inBookshelf=false），
  /// 此时按主键做 DO UPDATE 会撞 `book_id` 唯一索引直接抛异常
  /// —— 「先听再收藏」这条常见路径会崩。测试覆盖。
  Future<void> addToBookshelf(Book book) async {
    await _db.into(_db.booksTable).insert(
          BooksTableCompanion.insert(
            bookId: book.bookId,
            sourceId: book.sourceId,
            name: book.name,
            author: Value(book.author),
            narrator: Value(book.narrator),
            coverUrl: Value(book.coverUrl),
            intro: Value(book.intro),
            detailUrl: book.detailUrl,
            chapterCount: Value(book.chapterCount),
            latestChapter: Value(book.latestChapter),
            inBookshelf: const Value(true),
            addTime: Value(DateTime.now()),
            updateTime: Value(book.updateTime),
          ),
          onConflict: DoUpdate(
            (old) => BooksTableCompanion(
              sourceId: Value(book.sourceId),
              name: Value(book.name),
              author: Value(book.author),
              narrator: Value(book.narrator),
              coverUrl: Value(book.coverUrl),
              intro: Value(book.intro),
              detailUrl: Value(book.detailUrl),
              chapterCount: Value(book.chapterCount),
              latestChapter: Value(book.latestChapter),
              inBookshelf: const Value(true),
              updateTime: Value(book.updateTime),
            ),
            target: [_db.booksTable.bookId],
          ),
        );
  }

  /// 记录「播放过的书」——**不改动书架状态**。
  ///
  /// 背景：此前只有点「加入书架」才会写 `books` 表，于是「听过但没收藏」的书
  /// 在重启后查不到书名，续播功能等于失效。
  ///
  /// 已存在时只刷新元数据（作者/演播/封面/简介/章节数），
  /// **保留 `inBookshelf` 与 `addTime`** —— 不能因为播放就把用户移出书架。
  Future<void> touchPlayedBook(Book book) async {
    final existing = await getBookById(book.bookId);
    if (existing == null) {
      await _db.into(_db.booksTable).insert(
            BooksTableCompanion.insert(
              bookId: book.bookId,
              sourceId: book.sourceId,
              name: book.name,
              author: Value(book.author),
              narrator: Value(book.narrator),
              coverUrl: Value(book.coverUrl),
              intro: Value(book.intro),
              detailUrl: book.detailUrl,
              chapterCount: Value(book.chapterCount),
              latestChapter: Value(book.latestChapter),
              // 只是听过，不进书架
              inBookshelf: const Value(false),
              addTime: Value(DateTime.now()),
              updateTime: Value(book.updateTime),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return;
    }

    await (_db.update(_db.booksTable)
          ..where((t) => t.bookId.equals(book.bookId)))
        .write(
      BooksTableCompanion(
        name: Value(book.name),
        author: Value(book.author),
        narrator: Value(book.narrator),
        coverUrl: Value(book.coverUrl),
        intro: Value(book.intro),
        detailUrl: Value(book.detailUrl),
        chapterCount: Value(book.chapterCount),
        latestChapter: Value(book.latestChapter),
        updateTime: Value(book.updateTime ?? DateTime.now()),
      ),
    );
  }

  /// 从书架移除
  Future<void> removeFromBookshelf(String bookId) async {
    await (_db.delete(_db.booksTable)
      ..where((t) => t.bookId.equals(bookId)))
      .go();
  }

  /// 获取书架中的所有书籍
  Future<List<Book>> getBookshelfBooks() async {
    final rows = await (_db.select(_db.booksTable)
      ..where((t) => t.inBookshelf.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.addTime)]))
      .get();

    return rows.map(_rowToBook).toList();
  }

  /// 获取最近阅读的书籍（通过播放历史）
  Future<List<Book>> getRecentBooks({int limit = 10}) async {
    final query = _db.select(_db.booksTable).join([
      innerJoin(
        _db.playHistoryTable,
        _db.playHistoryTable.bookId.equalsExp(_db.booksTable.bookId),
      ),
    ]);
    query.orderBy([OrderingTerm.desc(_db.playHistoryTable.lastPlayTime)]);
    query.limit(limit);

    final rows = await query.get();
    return rows.map((row) => _rowToBook(row.readTable(_db.booksTable))).toList();
  }

  /// 检查书籍是否在书架中
  Future<bool> isInBookshelf(String bookId) async {
    final count = await (_db.select(_db.booksTable)
      ..where((t) => t.bookId.equals(bookId) & t.inBookshelf.equals(true)))
      .get();
    return count.isNotEmpty;
  }

  /// 根据 bookId 获取书籍
  Future<Book?> getBookById(String bookId) async {
    final rows = await (_db.select(_db.booksTable)
      ..where((t) => t.bookId.equals(bookId)))
      .get();
    if (rows.isEmpty) return null;
    return _rowToBook(rows.first);
  }

  /// 将数据库行转换为 Book 模型
  Book _rowToBook(BooksTableData row) {
    return Book(
      bookId: row.bookId,
      sourceId: row.sourceId,
      name: row.name,
      author: row.author,
      narrator: row.narrator,
      coverUrl: row.coverUrl,
      intro: row.intro,
      detailUrl: row.detailUrl,
      chapterCount: row.chapterCount,
      latestChapter: row.latestChapter,
      updateTime: row.updateTime,
      inBookshelf: row.inBookshelf,
      addTime: row.addTime,
    );
  }
}

/// BookRepository Provider
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BookRepository(db);
});
