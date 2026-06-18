import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/source_rule.dart';

void main() {
  test('typed source assets are schema-complete SourceRule JSON files', () {
    final paths = [
      'assets/sources/xa.json',
      'assets/sources/xiaoku.json',
      'assets/sources/liuyue.json',
      'assets/sources/xiaoliang.json',
      'assets/sources/xiaoqing.json',
    ];

    for (final path in paths) {
      final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final source = SourceRule.fromJson(json);

      expect(source.sourceType, 'typed-audio');
      expect(source.search.bookList, 'typed');
      expect(source.detail.chapterList, 'typed');
      expect(source.chapter.chapterUrl, 'typed');
      expect(source.audio.audioUrl, 'typed');
    }
  });

  test('removed missing ting56 built-in asset reference', () {
    final sourceManager = File('lib/features/source_manager/source_manager_page.dart')
        .readAsStringSync();

    expect(sourceManager, isNot(contains('assets/sources/ting56.json')));
  });
}
