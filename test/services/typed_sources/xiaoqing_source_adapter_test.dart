import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/xiaoqing_source_adapter.dart';

void main() {
  late XiaoQingSourceAdapter adapter;
  late SourceRule source;

  setUp(() {
    adapter = XiaoQingSourceAdapter();
    source = _source('xiaoQing', '小蜻听书（蜻蜓）', 'https://webapi.qtfm.cn');
  });

  test('parses Qingting all-tab search response using parent channel id', () {
    const response = """
{"all":{"total":1,"data":[{"id":23844397,"title":"三体星系的原型","parent_id":392510,"type":"program_ondemand","cover":"http://pic.example/cover.png","description":"来自专辑《奥秘全接触之未解之谜》"}]}}
""";

    final books = adapter.parseSearchResponse(source, '三体', response);

    expect(books, hasLength(1));
    expect(books.single.bookId, 'xiaoQing_392510');
    expect(books.single.detailUrl, '392510');
    expect(books.single.name, '三体星系的原型');
  });

  test('parses Qingting program audio from nested mediainfo and filters paid', () {
    final book = Book(
      bookId: 'xiaoQing_392510',
      sourceId: source.sourceId,
      name: '奥秘全接触',
      detailUrl: '392510',
    );
    const response = """
{"programs":[{"programId":"23844397","title":"第1集","duration":120,"isFree":true,"mediainfo":{"audioUrl":"https://audio.example/1.m4a"}},{"programId":"23844398","title":"第2集","isFree":false,"mediainfo":{"audioUrl":"https://audio.example/2.m4a"}}]}
""";

    final chapters = adapter.parseProgramsResponse(book, response);

    expect(chapters, hasLength(1));
    expect(chapters.single.url, '23844397');
    expect(chapters.single.audioUrl, 'https://audio.example/1.m4a');
    expect(chapters.single.duration, 120);
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
