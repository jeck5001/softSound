import 'package:drift/drift.dart';

/// 书籍表 - 存储书架中的书籍信息
class BooksTable extends Table {
  @override
  String get tableName => 'books';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get bookId => text().unique()();

  TextColumn get sourceId => text()();

  TextColumn get name => text()();

  TextColumn get author => text().nullable()();

  TextColumn get narrator => text().nullable()();

  TextColumn get coverUrl => text().nullable()();

  TextColumn get intro => text().nullable()();

  TextColumn get detailUrl => text()();

  IntColumn get chapterCount => integer().nullable()();

  TextColumn get latestChapter => text().nullable()();

  BoolColumn get inBookshelf => boolean().withDefault(const Constant(true))();

  DateTimeColumn get addTime => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updateTime => dateTime().nullable()();
}
