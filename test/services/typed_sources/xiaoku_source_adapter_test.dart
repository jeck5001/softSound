import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/xiaoku_source_adapter.dart';

void main() {
  late XiaoKuSourceAdapter adapter;
  late SourceRule source;

  setUp(() {
    adapter = XiaoKuSourceAdapter();
    source = _source('xiaoKu', '小酷听书（酷我）', 'http://search.kuwo.cn');
  });

  test('parses Kuwo single-quoted album search response', () {
    const response = """
{'SHOW':'3','albumlist':[{'DC_TARGETID':'42158089','albumid':'42158089','artist':'聴见','img':'http://img.example/cover.png','info':'简介','musiccnt':'1077','name':'超凡蓝图|热血机甲|科幻未来|多人爽文'}]}
""";

    final books = adapter.parseSearchResponse(source, '超凡', response);

    expect(books, hasLength(1));
    expect(books.single.bookId, 'xiaoKu_42158089');
    expect(books.single.name, '超凡蓝图|热血机甲|科幻未来|多人爽文');
    expect(books.single.narrator, '聴见');
    expect(books.single.chapterCount, 1077);
  });

  test('parses Kuwo album chapter response', () {
    final book = Book(
      bookId: 'xiaoKu_84026749',
      sourceId: source.sourceId,
      name: '盗墓笔记',
      detailUrl: '84026749',
    );
    const response = """
{"musiclist":[{"musicrid":"535057927","name":"第1集","duration":"28"},{"id":"535057928","name":"第2集","duration":31}]}
""";

    final chapters = adapter.parseChapterResponse(book, response);

    expect(chapters, hasLength(2));
    expect(chapters.first.url, '535057927');
    expect(chapters.first.duration, 28);
    expect(chapters.last.url, '535057928');
  });

  test('parses signed Kuwo audio response and filters wma urls', () {
    expect(
      adapter.parseAudioResponse(
        '{"code":200,"data":{"url":"https://a/b.mp3"}}',
      ),
      'https://a/b.mp3',
    );
    expect(
      adapter.parseAudioResponse(
        '{"code":200,"data":{"url":"https://a/b.wma"}}',
      ),
      isNull,
    );
  });
}

SourceRule _source(String id, String name, String url) {
  return SourceRule(
    sourceId: id,
    sourceName: name,
    sourceUrl: url,
    search: SearchRule(
      url: 'typed',
      bookList: 'typed',
      bookName: 'typed',
      bookUrl: 'typed',
    ),
    detail: DetailRule(chapterList: 'typed'),
    chapter: ChapterRule(chapterName: 'typed', chapterUrl: 'typed'),
    audio: AudioRule(audioUrl: 'typed'),
  );
}
