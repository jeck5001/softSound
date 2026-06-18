import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/typed_source_adapter.dart';
import 'package:soft_sound/services/typed_sources/typed_source_registry.dart';

class FakeAdapter implements TypedSourceAdapter {
  @override
  String get sourceId => 'fake_typed';

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async => const [];

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async => book;

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async =>
      const [];

  @override
  Future<String?> getAudioUrl(SourceRule source, Chapter chapter) async => null;
}

void main() {
  test('registry returns adapter for matching typed source id', () {
    final registry = TypedSourceRegistry([FakeAdapter()]);

    expect(registry.adapterFor('fake_typed'), isA<FakeAdapter>());
    expect(registry.adapterFor('plain_json'), isNull);
  });

  test('production registry contains first batch typed sources', () {
    expect(typedSourceRegistry.adapterFor('XA'), isNotNull);
    expect(typedSourceRegistry.adapterFor('xiaoKu'), isNotNull);
    expect(typedSourceRegistry.adapterFor('liuYue'), isNotNull);
    expect(typedSourceRegistry.adapterFor('xiaoLiang'), isNotNull);
    expect(typedSourceRegistry.adapterFor('xiaoQing'), isNotNull);
  });
}
