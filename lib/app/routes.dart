import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/features/home/home_page.dart';
import 'package:soft_sound/features/search/search_page.dart';
import 'package:soft_sound/features/book_detail/book_detail_page.dart';
import 'package:soft_sound/features/player/player_page.dart';
import 'package:soft_sound/features/bookshelf/bookshelf_page.dart';
import 'package:soft_sound/features/source_manager/source_manager_page.dart';

/// 应用路由配置
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/bookshelf',
            name: 'bookshelf',
            builder: (context, state) => const BookshelfPage(),
          ),
          GoRoute(
            path: '/sources',
            name: 'sources',
            builder: (context, state) => const SourceManagerPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/book/:bookId',
        name: 'book_detail',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookDetailPage(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        builder: (context, state) => const PlayerPage(),
      ),
    ],
  );
});

/// 主脚手架（底部导航）
class MainScaffold extends StatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/bookshelf');
              break;
            case 2:
              context.go('/sources');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '书源',
          ),
        ],
      ),
    );
  }
}
