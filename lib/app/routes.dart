import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/features/home/announcement_gate.dart';
import 'package:soft_sound/features/home/home_page.dart';
import 'package:soft_sound/features/explore/explore_page.dart';
import 'package:soft_sound/features/bookshelf/bookshelf_page.dart';
import 'package:soft_sound/features/profile/profile_page.dart';
import 'package:soft_sound/features/search/search_page.dart';
import 'package:soft_sound/features/book_detail/book_detail_page.dart';
import 'package:soft_sound/features/player/player_page.dart';
import 'package:soft_sound/features/source_manager/source_manager_page.dart';
import 'package:soft_sound/features/ranking/ranking_page.dart';
import 'package:soft_sound/features/downloads/downloads_page.dart';
import 'package:soft_sound/features/history/history_page.dart';
import 'package:soft_sound/features/settings/settings_page.dart';
import 'package:soft_sound/features/reading/reading_page.dart';
import 'package:soft_sound/features/explore/category_books_page.dart';
import 'package:soft_sound/features/explore/lrts_category_books_page.dart';
import 'package:soft_sound/features/explore/lrts_channel_page.dart';
import 'package:soft_sound/services/player_service.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/brand_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 底部导航的四个页签 —— 对齐聆阅的「首页 / 发现 / 书架 / 我的」。
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 应用路由配置。
///
/// 说明：底部导航由 [StatefulShellRoute] 驱动，每个页签保留独立导航栈，
/// 这是聆阅（expo-router `(tabs)` 分组）行为的 Flutter 等价实现。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          // 页签 1：首页
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          // 页签 2：发现
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                name: 'explore',
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          // 页签 3：书架
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shelf',
                name: 'shelf',
                builder: (context, state) => const BookshelfPage(),
              ),
            ],
          ),
          // 页签 4：我的
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // ------------------------------------------------------ 全屏路由（覆盖底部导航）

      GoRoute(
        path: '/search',
        name: 'search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            SearchPage(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(
        path: '/book/:bookId',
        name: 'book_detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookDetailPage(
            bookId: bookId,
            initialName: state.uri.queryParameters['name'],
          );
        },
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlayerPage(),
      ),
      GoRoute(
        path: '/ranking',
        name: 'ranking',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RankingPage(),
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DownloadsPage(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/category/:categoryId',
        name: 'category_books',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CategoryBooksPage(
          categoryId: state.pathParameters['categoryId']!,
          name: state.uri.queryParameters['name'] ?? AppStrings.navCategory,
          classifyId: state.uri.queryParameters['classify'],
        ),
      ),
      GoRoute(
        path: '/lrts-category/:id',
        name: 'lrts_category_books',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => LrtsCategoryBooksPage(
          categoryId: state.pathParameters['id']!,
          name: state.uri.queryParameters['name'] ?? '分类',
        ),
      ),
      // 懒人「频道页」：一个分类的首页（页签 + 多栏目），
      // 契约来自字节码 #18090 `fetchLrtsChildren`（直接抓 Nuxt SSR，
      // 不经 Edge，因此不受 429 影响）。
      GoRoute(
        path: '/lrts-channel/:rootId',
        name: 'lrts_channel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => LrtsChannelPage(
          rootId: state.pathParameters['rootId']!,
          title: state.uri.queryParameters['name'] ?? '分类',
        ),
      ),
      GoRoute(
        path: '/reading',
        name: 'reading',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReadingPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/sources',
        name: 'sources',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SourceManagerPage(),
      ),
    ],
  );
});

/// 主脚手架（底部导航 + 迷你播放条）。
///
/// 对应聆阅的 `(tabs)/_layout.tsx`：页签上方悬浮迷你播放条
/// （封面 + 标题 + 波形 + 下一章 + 紫色暂停，2026-10-16 截图复刻）。
class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final showMini = playerState.currentBook != null;

    return Scaffold(
      body: Stack(
        children: [
          // 启动公告闸门（聆阅 remote-config 契约）：
          // 挂在壳层，避免只在使用某个页签时才检查。
          AnnouncementGate(child: navigationShell),
          if (showMini)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: _MiniPlayerBar(state: playerState),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // 再次点击当前页签时回到该分支根路由
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: AppStrings.navExplore,
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: AppStrings.navShelf,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }
}

/// 迷你播放条（聆阅截图复刻：白卡 + 小封面 + 波形点 + 下一章 + 紫色暂停）。
class _MiniPlayerBar extends ConsumerWidget {
  final PlayerState state;

  const _MiniPlayerBar({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final notifier = ref.read(playerProvider.notifier);
    final cover = state.currentBook?.coverUrl ?? '';

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDD6FE)),
          boxShadow: lyHardShadowSm,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 40,
                height: 40,
                child: cover.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: c.muted),
                      )
                    : Container(
                        color: c.muted,
                        child: Icon(Icons.headphones_rounded,
                            size: 20, color: c.mutedForeground),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.currentBook?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    state.currentChapter?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: c.mutedForeground, fontSize: 11),
                  ),
                ],
              ),
            ),
            // 波形点（聆阅静态装饰）
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _Dot(4, Color(0xFF8B5CF6)),
                  SizedBox(width: 3),
                  _Dot(7, Color(0xFF8B5CF6)),
                  SizedBox(width: 3),
                  _Dot(5, Color(0xFFA78BFA)),
                ],
              ),
            ),
            LyIconButton(
              icon: Icons.skip_next_rounded,
              size: 40,
              onTap: () => notifier.nextChapter(),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => notifier.togglePlay(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: lyHardShadowSm,
                ),
                child: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double h;
  final Color color;

  const _Dot(this.h, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 3.5,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
