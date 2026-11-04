import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/books_table.dart';
import 'tables/play_history_table.dart';
import 'tables/download_chapters_table.dart';
import 'tables/listening_stats_table.dart';
import 'tables/book_chapters_table.dart';

part 'app_database.g.dart';

/// 应用数据库
@DriftDatabase(tables: [
  BooksTable,
  PlayHistoryTable,
  DownloadChaptersTable,
  ListeningStatsTable,
  BookChaptersTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 供测试注入执行器（如内存数据库）。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v1 -> v2：新增下载章节表（离线缓存）。
        if (from < 2) {
          await m.createTable(downloadChaptersTable);
        }
        // v2 -> v3：新增累计收听统计表。
        if (from < 3) {
          await m.createTable(listeningStatsTable);
        }
        // v3 -> v4：新增目录缓存表（大目录分页可跨会话累积补齐）。
        if (from < 4) {
          await m.createTable(bookChaptersTable);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'soft_sound.db'));
    return NativeDatabase.createInBackground(file);
  });
}
