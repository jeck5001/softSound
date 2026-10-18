import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 路由一致性守卫。
///
/// 背景：重构底部导航时把首页从 `/` 改为 `/home`、把书源页移出页签壳层，
/// 但页面内的 `context.go('/')` / `context.go('/sources')` 未同步，
/// 会导致点击后跳转到不存在的路由。此测试静态扫描源码防止再次回归。
void main() {
  /// 从 routes.dart 提取已声明的路由。
  Set<String> declaredRoutes() {
    final src = File('lib/app/routes.dart').readAsStringSync();
    final matches =
        RegExp(r"""path:\s*['"]([^'"]+)['"]""").allMatches(src);
    return matches.map((m) => m.group(1)!).toSet();
  }

  /// 收集 lib/ 下所有导航调用。
  List<(String file, String target)> navigationCalls() {
    final result = <(String, String)>[];
    final dir = Directory('lib');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('routes.dart')) continue;

      final src = entity.readAsStringSync();
      for (final m in RegExp(r"""context\.(?:go|push)\(\s*['"]([^'"]+)['"]""")
          .allMatches(src)) {
        result.add((entity.path, m.group(1)!));
      }
    }
    return result;
  }

  /// 判断导航目标是否匹配某个已声明路由（支持动态段）。
  bool matchesAny(String target, Set<String> routes) {
    if (routes.contains(target)) return true;
    // 动态段：/book/xxx 匹配 /book/:bookId
    for (final r in routes) {
      if (!r.contains(':')) continue;
      final prefix = r.substring(0, r.indexOf(':'));
      if (target.startsWith(prefix) && target.length > prefix.length) {
        return true;
      }
    }
    return false;
  }

  group('路由一致性', () {
    test('所有 context.go / context.push 目标都有对应路由声明', () {
      final routes = declaredRoutes();
      expect(routes, isNotEmpty, reason: '应能解析出路由定义');

      final bad = <String>[];
      for (final (file, target) in navigationCalls()) {
        if (!matchesAny(target, routes)) {
          bad.add('$file -> $target');
        }
      }

      expect(
        bad,
        isEmpty,
        reason: '以下导航目标没有对应的路由声明（会导致跳转失败）:\n'
            '${bad.join('\n')}',
      );
    });

    test('关键路由均已声明', () {
      final routes = declaredRoutes();
      // 底部导航四页签
      expect(routes, contains('/home'));
      expect(routes, contains('/explore'));
      expect(routes, contains('/shelf'));
      expect(routes, contains('/profile'));
      // 全屏路由
      expect(routes, contains('/search'));
      expect(routes, contains('/book/:bookId'));
      expect(routes, contains('/player'));
      expect(routes, contains('/downloads'));
      expect(routes, contains('/history'));
      expect(routes, contains('/settings'));
      expect(routes, contains('/sources'));
      expect(routes, contains('/ranking'));
    });

    test('首页路由是 /home 而非旧版 /', () {
      final routes = declaredRoutes();
      expect(routes, contains('/home'));
      expect(routes, isNot(contains('/')),
          reason: '根路由已改为 /home，若仍声明 / 说明重构回退');
    });

    test('导航调用至少存在若干处（防止扫描逻辑失效）', () {
      final calls = navigationCalls();
      expect(calls.length, greaterThan(8));
    });
  });
}
