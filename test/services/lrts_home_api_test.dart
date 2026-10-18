import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/services/lrts_home_api.dart';

/// 首页推荐流契约测试（fixture 为 2026-10-16 真实响应裁剪）。
void main() {
  final api = LrtsHomeApi();

  group('parseHome（真实报文）', () {
    late LrtsHomeData data;

    setUpAll(() {
      final body = File('test/fixtures/lrts_home_real.json').readAsStringSync();
      data = api.parseHome(body);
    });

    test('top books 与 sections 结构完整', () {
      expect(data.books, isNotEmpty);
      expect(data.sections, isNotEmpty);
      expect(data.sections.map((s) => s.label),
          containsAll(['听友推荐', '都市传说', '玄幻奇幻']));
      for (final s in data.sections) {
        expect(s.books, isNotEmpty, reason: '栏目 ${s.label} 无书');
      }
    });

    test('书字段真实（封面 CDN / 评分 / 演播）', () {
      final b = data.sections.first.books.first;
      expect(b.cover, startsWith('https://bookpic.lrts.me/'));
      expect(b.rating, isNotNull);
      expect(b.title, isNotEmpty);
      expect(b.id, isNotEmpty);
    });

    test('畸形输入 → empty 不抛', () {
      expect(api.parseHome('nope').isEmpty, isTrue);
      expect(api.parseHome('[]').isEmpty, isTrue);
      expect(api.parseHome('{}').isEmpty, isTrue);
    });

    test('sections 缺 books 时该栏目为空但不影响其他', () {
      final d = api.parseHome(jsonEncode({
        'books': [
          {'id': '1', 'title': 'x'}
        ],
        'sections': [
          {'label': '空栏'},
          {
            'label': '有书',
            'books': [
              {'id': '2', 'title': 'y'}
            ]
          },
        ],
      }));
      expect(d.sections.first.books, isEmpty);
      expect(d.sections.last.books, hasLength(1));
    });
  });
}
