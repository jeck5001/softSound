import 'package:flutter_test/flutter_test.dart';

import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/services/search_relevance.dart';

/// 搜索相关性测试。
///
/// 背景（用户反馈）：搜索结果很不准确。实测上游 PHP 接口搜「大唐明月」
/// 返回 7 条，其中 2 条是「惊！她能穿梭时空」——模糊匹配且我们原样展示。
void main() {
  Book book({
    required String name,
    String? author,
    String? narrator,
    String id = '1',
  }) =>
      Book(
        bookId: id,
        sourceId: 'lrts',
        name: name,
        author: author,
        narrator: narrator,
        detailUrl: id,
      );

  group('打分', () {
    test('完全一致 > 前缀 > 包含 > 作者 > 不匹配', () {
      expect(SearchRelevance.score(book(name: '大唐明月'), '大唐明月'), 100);
      expect(SearchRelevance.score(book(name: '大唐明月传'), '大唐明月'), 80);
      expect(SearchRelevance.score(book(name: '新大唐明月'), '大唐明月'), 60);
      expect(
        SearchRelevance.score(book(name: '别的书', author: '大唐明月'), '大唐明月'),
        40,
      );
      expect(
        SearchRelevance.score(book(name: '别的书', narrator: '大唐明月'), '大唐明月'),
        30,
      );
      expect(SearchRelevance.score(book(name: '惊！她能穿梭时空'), '大唐明月'), 0);
    });

    test('忽略书名号、竖线、空格与大小写', () {
      expect(
        SearchRelevance.score(
          book(name: '大唐明月|《风起霓裳》原著'),
          '大唐明月',
        ),
        80,
        reason: '归一化后以关键词开头',
      );
      expect(
        SearchRelevance.score(book(name: 'The  Great Gatsby'), 'great gatsby'),
        60,
      );
      expect(
        SearchRelevance.score(book(name: '　大唐明月　'), '大唐明月'),
        100,
        reason: '全角空格要忽略',
      );
    });

    test('空关键词不命中任何书', () {
      expect(SearchRelevance.score(book(name: '大唐明月'), '  '), 0);
    });
  });

  group('作者字段清洗', () {
    test('去掉自带前缀（否则显示成「作者: 作者：邵雪城」）', () {
      expect(SearchRelevance.cleanAuthor('作者：邵雪城'), '邵雪城');
      expect(SearchRelevance.cleanAuthor('作者: 邵雪城'), '邵雪城');
      expect(SearchRelevance.cleanAuthor('著者：张三'), '张三');
      expect(SearchRelevance.cleanAuthor('by: Alex'), 'Alex');
    });

    test('正常作者名不动', () {
      expect(SearchRelevance.cleanAuthor('余华'), '余华');
      expect(SearchRelevance.cleanAuthor('  冯唐  '), '冯唐');
      expect(SearchRelevance.cleanAuthor(null), isNull);
      expect(SearchRelevance.cleanAuthor(''), '');
    });

    test('只有前缀没有名字时保留原值（不产生空作者）', () {
      expect(SearchRelevance.cleanAuthor('作者：'), '作者：');
    });
  });

  group('rank 过滤与排序', () {
    test('丢掉完全无关的结果，并按相关度排序', () {
      final input = [
        book(name: '惊！她能穿梭时空|爽文|系统', id: 'a'),
        book(name: '大唐明月|《风起霓裳》原著', id: 'b'),
        book(name: '大唐明月', author: '蓝云舒', id: 'c'),
        book(name: '大唐明月传', id: 'd'),
      ];

      final out = SearchRelevance.rank(input, '大唐明月');

      expect(out.map((b) => b.bookId), ['c', 'b', 'd']);
      expect(out.any((b) => b.bookId == 'a'), isFalse, reason: '无关结果必须剔除');
    });

    test('同分保持上游原序（上游有播放量权重）', () {
      final input = [
        book(name: '大唐明月', id: 'first'),
        book(name: '大唐明月', id: 'second'),
        book(name: '大唐明月', id: 'third'),
      ];
      expect(
        SearchRelevance.rank(input, '大唐明月').map((b) => b.bookId),
        ['first', 'second', 'third'],
      );
    });

    test('一条都不命中时全保留（拼音/繁体不能误杀）', () {
      // 关键词是拼音：字符串层面两条都不含它，此时不能把结果全删掉
      final input = [
        book(name: 'Tang Dynasty', id: 'a'),
        book(name: '大唐明月(繁体)', id: 'b'),
      ];
      expect(SearchRelevance.rank(input, 'datangmingyue').length, 2);
    });

    test('拼音命中时仍按命中项返回（英文名归一化）', () {
      final input = [
        book(name: 'Da Tang Ming Yue', id: 'a'),
        book(name: '无关的书', id: 'b'),
      ];
      expect(
        SearchRelevance.rank(input, 'datangmingyue').map((b) => b.bookId),
        ['a'],
      );
    });

    test('空列表安全', () {
      expect(SearchRelevance.rank(const [], 'x'), isEmpty);
    });
  });
}
