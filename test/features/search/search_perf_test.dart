import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:soft_sound/features/search/search_page.dart';

/// 搜索性能与准确度的接线守卫。
///
/// 用户反馈：搜索慢、结果不准。实测根因：
/// - 串行搜每个源（延迟相加），且懒人 Edge 搜索接口服务端已坏，
///   每次都要先打两次再兜底；
/// - 上游模糊匹配带回无关书，我们原样展示。
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('并发', () {
    test('多源并发而不是串行', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('Future.wait('), isTrue,
          reason: '串行是「慢」的主因：各源延迟相加');
      expect(src.contains('maxConcurrent'), isTrue);
    });

    test('并发数有上限（避免撞 Edge 项目级 429）', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('static const int maxConcurrent = 3'), isTrue);
    });

    test('单源超时，慢源不拖住整体', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('timeout(sourceTimeout)'), isTrue);
      expect(src.contains('sourceTimeout'), isTrue);
    });

    test('逐源出结果（先回来的先显示）', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('grouped[source.sourceId] = ranked'), isTrue);
      expect(src.contains('isLoading: remaining > 1'), isTrue,
          reason: '还有源在跑时保持加载态，但结果已经可以先显示');
    });

    test('结果缓存（同关键词 5 分钟内直接命中）', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('_readCache'), isTrue);
      expect(src.contains('cacheTtl'), isTrue);
    });

    test('缓存增量写入：中途离开也留得住（旧实现只在全部完成时写）', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('_mergeCache('), isTrue,
          reason: '只在结束时写缓存 → 用户返回上一页就白搜一次');
      expect(src.contains('_writeCache'), isFalse);
    });

    test('部分缓存时只补搜缺失的书源', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('!grouped.containsKey(s.sourceId)'), isTrue);
    });
  });

  group('渐进结果的可用性', () {
    test('已有结果时不再被全屏加载态盖住', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('searchState.isLoading && searchState.results.isEmpty'),
          isTrue,
          reason: '否则慢源没回来时，已回来的结果会被转圈挡住');
    });

    test('分组按书源配置顺序稳定', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('_ordered('), isTrue,
          reason: '并发返回顺序不定，列表会跳');
    });

    test('作者字段入口清洗（不出现「作者: 作者：xx」）', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('SearchRelevance.cleanAuthor('), isTrue);
    });
  });

  group('准确度', () {
    test('搜索后按相关度过滤 + 排序', () {
      final src = read('lib/features/search/search_page.dart');
      expect(src.contains('SearchRelevance.rank('), isTrue,
          reason: '不过滤就会把「惊！她能穿梭时空」这类无关书展示出来');
    });
  });

  group('懒人源：跳过已坏的 Edge 搜索', () {
    test('记住 Edge 搜索不可用，期间直接走 PHP 兜底', () {
      final src = read('lib/services/typed_sources/lrts_source_adapter.dart');
      expect(src.contains('_edgeSearchBroken'), isTrue);
      expect(src.contains('_edgeSearchBrokenUntil'), isTrue);
      expect(src.contains("json['error']"), isTrue,
          reason: '服务端报错要能被识别并记住');
    });
  });

  group('缓存可清理（供测试与内存回收）', () {
    test('提供 clearCache', () {
      SearchNotifier.clearCache();
      expect(true, isTrue);
    });
  });
}
