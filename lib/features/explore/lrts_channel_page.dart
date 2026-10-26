import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soft_sound/services/lrts_children_api.dart';
import 'package:soft_sound/services/lrts_home_api.dart'
    show LrtsHomeBook, LrtsHomeSection;
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/brand_widgets.dart';

/// 懒人听书「频道页」—— 聆阅 `channels/[categoryId].tsx` + #18090
/// `fetchLrtsChildren` 的 Flutter 等价实现。
///
/// 与「分类书籍列表页」（走 Edge `lrts-category`）的区别：
/// 频道页是**一个分类的首页**，一次请求拿到
/// 「14 个子类页签 + 听友推荐 + 各子类栏目」，而列表页只有分页书籍。
///
/// 数据源：`https://m.lrts.me/category/book?title=&rootId=&index=-2`
/// （直接抓网页解析 Nuxt SSR，不经 Edge，因此没有 429 限流）。
class LrtsChannelPage extends ConsumerWidget {
  const LrtsChannelPage({super.key, required this.rootId, required this.title});

  /// 分类根 id（如儿童 = 6、有声小说 = 1）。
  final String rootId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final async = ref.watch(
      lrtsChildrenProvider((title: title, rootId: rootId)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(
          lrtsChildrenProvider((title: title, rootId: rootId)),
        ),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              _Message(text: '频道加载失败，下拉重试', color: c.mutedForeground),
          data: (data) {
            if (data.isEmpty) {
              return _Message(text: '该频道暂无内容', color: c.mutedForeground);
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (data.tabs.isNotEmpty) _TabStrip(tabs: data.tabs),
                for (final section in data.sections)
                  _SectionBlock(section: section),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 子类页签（横向滚动 chip）。
///
/// 点击进入分类书籍列表页（`/lrts-category/:id`），与聆阅
/// 页签切换后按 `lrts-category` 取书的链路一致。
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tabs});

  final List<LrtsChannelTab> tabs;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = tabs[i];
          return GestureDetector(
            onTap: () => context.push(
              '/lrts-category/${t.id}?name=${Uri.encodeComponent(t.name)}',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE6E1F5), width: 1.5),
              ),
              child: Text(
                t.name,
                style: TextStyle(
                  color: c.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 一个栏目（标题 + 横向书卡）。
class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final LrtsHomeSection section;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${section.books.length} 本',
                style: TextStyle(color: c.mutedForeground, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          // 132 封面 + 6 间距 + 两行标题(≈30) + 播放量(≈15) + 余量
          height: 198,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _BookCard(book: section.books[i]),
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final LrtsHomeBook book;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () => context.push(
        '/book/lrts_${book.id}?name=${Uri.encodeComponent(book.title)}',
      ),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LyCover(url: book.cover, width: 104, height: 132, radius: 12),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (book.listeners.isNotEmpty)
              Text(
                book.listeners,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.mutedForeground, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 用 ListView 包一层，保证 RefreshIndicator 在空态也能下拉。
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
