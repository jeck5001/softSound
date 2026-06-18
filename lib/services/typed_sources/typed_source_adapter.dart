import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../data/models/source_rule.dart';

/// Source adapter for sites whose flows are too complex for selector-only rules.
abstract class TypedSourceAdapter {
  String get sourceId;

  Future<List<Book>> search(SourceRule source, String keyword);

  Future<Book?> getBookDetail(SourceRule source, Book book);

  Future<List<Chapter>> getChapterList(SourceRule source, Book book);

  Future<String?> getAudioUrl(SourceRule source, Chapter chapter);
}
