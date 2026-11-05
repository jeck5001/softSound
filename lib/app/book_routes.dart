import '../data/models/book.dart';

/// 构造「书籍详情」路由，**始终带上本地已知的书名与封面**。
///
/// 为什么必须统一走这里：
/// 详情页拿到 `bookId` 后要先造一个占位 `Book`（`name = 加载书籍信息…`）
/// 等 `getBookDetail` 补全。而详情接口经常失败（实测酷我 `getBookDetail`
/// 长期失败），于是标题**永久停在占位串上** —— 用户从搜索点进来看到的
/// 「加载书籍信息…」就是这么来的，目录明明有 925 集，标题却是空的。
///
/// 各入口（搜索/书架/历史/首页/分类）本来就握着真实书名与封面，
/// 传进路由就能立刻显示，根本不依赖详情接口成功。
///
/// 历史教训：6.53 只给榜单补了 cover、6.63 只给书架补了 name，
/// 每次修一条路径，其它路径继续犯同一个错。所以做成唯一入口。
String bookDetailRoute(
  String bookId, {
  String? name,
  String? cover,
}) {
  final cleanName = (name ?? '').trim();
  final cleanCover = (cover ?? '').trim();
  final query = <String, String>{
    // 占位串/纯数字 id 不算"已知书名"，不传（否则会把占位当权威写进状态）
    if (cleanName.isNotEmpty &&
        !isPlaceholderName(cleanName) &&
        int.tryParse(cleanName) == null)
      'name': cleanName,
    if (cleanCover.isNotEmpty) 'cover': cleanCover,
  };
  return Uri(
    path: '/book/$bookId',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// 从 [Book] 构造路由。
String bookDetailRouteForBook(Book book) => bookDetailRoute(
      book.bookId,
      name: book.name,
      cover: book.coverUrl,
    );

/// 与 `PlayerNotifier.isPlaceholderBook` 保持一致的名单判定。
///
/// 这里不直接复用，是为了避开 `app/` 反向依赖 `services/`。
bool isPlaceholderName(String name) =>
    name.isEmpty || name.startsWith('加载书籍信息');
