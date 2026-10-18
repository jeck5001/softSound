import 'package:drift/drift.dart';

/// 累计收听统计表。
///
/// 单行表（`id` 固定为 1），累计记录用户的收听时长。
/// 之所以单独建表而非从 `play_history` 推导：
/// `play_history` 每本书只保留**当前**进度（唯一键 bookId），
/// 无法反映「听了多久」这种增量信息。
class ListeningStatsTable extends Table {
  @override
  String get tableName => 'listening_stats';

  IntColumn get id => integer().autoIncrement()();

  /// 累计收听秒数（只增不减，除非用户主动清空统计）。
  IntColumn get totalSeconds => integer().withDefault(const Constant(0))();

  /// 最近一次累计时间。
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
