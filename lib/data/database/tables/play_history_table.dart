import 'package:drift/drift.dart';

/// 播放历史表 - 存储播放进度
class PlayHistoryTable extends Table {
  @override
  String get tableName => 'play_history';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get bookId => text().unique()();

  TextColumn get sourceId => text()();

  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();

  TextColumn get chapterName => text().nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  IntColumn get duration => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastPlayTime => dateTime().withDefault(currentDateAndTime)();
}
