import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edge_gate.dart';

/// 酷我排行榜数据源 —— 经聆阅的 Supabase Edge Functions。
///
/// 2026-10-14 实测契约：
/// - `GET kuwo-rank-tabs` → `{tabs: [{id, name, tags: [{id, name, rankCount}]}]}`
/// - `GET kuwo-rank-data?tabId={id}` → `{list: [{id, title, cover, songNum, playCnt, rank}], total}`
///
/// 服务端有**项目级**并发限流（429 `projectConcurrencyLimitExceeded`，
/// 无 `Retry-After`），见 [EdgeGate] 的实测数据：并发即互相打挂。
/// 因此这里的请求统一过 [EdgeGate] 串行，且重试次数/退避都有上限 ——
/// 旧实现是「8 秒 × 重试 2 次」+ 裸 `Dio()` 无超时，最坏能挂 30 秒以上，
/// 表现就是发现页那张卡一直停在「加载榜单…」。
class KuwoRankApi {
  KuwoRankApi({
    Dio? dio,
    this.retryDelay = const Duration(milliseconds: 600),
    this.maxAttempts = 2,
    this.gate,
    this.timeout = const Duration(seconds: 8),
  }) : _dio = dio ?? Dio();

  final Dio _dio;

  /// 429 之后的重试间隔（测试注入 `Duration.zero`）。
  final Duration retryDelay;

  /// 总尝试次数（含首次）。1 = 不重试。
  final int maxAttempts;

  /// 串行闸门；`null` 时用全局 [edgeGate]（测试可注入独立实例）。
  final EdgeGate? gate;

  /// 单次请求超时。**必须**有值：裸 Dio 默认无限等，弱网下会永久卡住。
  final Duration timeout;

  static const String _fnBase =
      'https://backend.appmiaoda.com/projects/supabase345057433544081408/functions/v1';

  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhw'
      'IjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9'
      '.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc';

  /// 榜单页签。
  Future<List<KuwoRankTab>> fetchTabs() async {
    final body = await _get('/kuwo-rank-tabs');
    if (body == null) return const [];
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tabs = json['tabs'];
      if (tabs is! List) return const [];
      return [
        for (final t in tabs)
          if (t is Map)
            KuwoRankTab(
              id: '${t['id']}',
              name: '${t['name'] ?? ''}',
            ),
      ];
    } catch (e) {
      return const [];
    }
  }

  /// 榜单书籍。
  ///
  /// **失败抛 [EdgeUnavailableException]，不静默返回空列表**：空列表意味着
  /// 「这个榜确实没有内容」，UI 会显示「这个榜单暂时没有内容」；而没拿到
  /// 数据必须显示「服务正忙 + 重新加载」，两者不能混为一谈。
  Future<List<KuwoRankBook>> fetchRankData(String tabId) async {
    final body = await _get('/kuwo-rank-data?tabId=$tabId');
    if (body == null) {
      throw const EdgeUnavailableException('kuwo-rank-data 未返回内容');
    }
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final list = json['list'];
      if (list is! List) {
        throw const EdgeUnavailableException('kuwo-rank-data 缺少 list');
      }
      return [
        for (final b in list)
          if (b is Map)
            KuwoRankBook(
              id: '${b['id'] ?? ''}',
              title: '${b['title'] ?? ''}',
              cover: b['cover'] == null ? null : '${b['cover']}',
              playCount: '${b['playCnt'] ?? ''}',
              chapterCount: '${b['songNum'] ?? ''}',
              rank: '${b['rank'] ?? ''}',
            ),
      ];
    } on EdgeUnavailableException {
      rethrow;
    } catch (e) {
      throw EdgeUnavailableException('kuwo-rank-data 解析失败: $e');
    }
  }

  /// 单次 Edge 请求（经串行闸门 + 有限重试）。
  ///
  /// 返回 `null` 表示「确实没拿到」，调用方据此回退，不再无限等待。
  Future<String?> _get(String path) {
    final g = gate ?? edgeGate;
    return g.run(() async {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(retryDelay);
        }
        try {
          final r = await _dio.get<String>(
            '$_fnBase$path',
            options: Options(
              responseType: ResponseType.plain,
              validateStatus: (c) => c != null && c < 600,
              headers: {
                'apikey': _anonKey,
                'Authorization': 'Bearer $_anonKey',
              },
              receiveTimeout: timeout,
              sendTimeout: timeout,
            ),
          );
          final body = r.data;
          if (body == null) return null;
          if (body.contains('projectConcurrencyLimitExceeded')) continue;
          return body;
        } catch (_) {
          // 超时/网络错误也按尝试次数上限走，绝不无限重试。
        }
      }
      return null;
    });
  }
}

/// 榜单页签。
class KuwoRankTab {
  final String id;
  final String name;

  const KuwoRankTab({required this.id, required this.name});
}

/// 榜单书籍（通用榜行模型：酷我榜与懒人榜共用）。
class KuwoRankBook {
  final String id;
  final String title;
  final String? cover;
  final String playCount;
  final String chapterCount;
  final String rank;

  /// 作者（懒人榜真实返回；酷我榜暂无则空串）。
  final String author;

  const KuwoRankBook({
    required this.id,
    required this.title,
    this.cover,
    this.playCount = '',
    this.chapterCount = '',
    this.rank = '',
    this.author = '',
  });
}

/// Provider。
final kuwoRankApiProvider = Provider<KuwoRankApi>((ref) => KuwoRankApi());

/// 线上分类树（`kuwo-classify`；2026-10-16 实测契约，7 个大类）。
/// 失败返回空列表，由 UI 回退到本地兜底分类。
///
/// `keepAlive`：发现页重建时不必重打一次 Edge 请求（配额紧张，见 [EdgeGate]）。
final kuwoClassifyProvider =
    FutureProvider<List<KuwoClassifySection>>((ref) {
  ref.keepAlive();
  return ref.watch(kuwoRankApiProvider).fetchClassify();
});

/// 发现页排行榜入口的预览内容：首个页签名 + 榜首书名。
typedef KuwoRankPreview = ({String tabName, String topTitle});

/// 排行榜入口预览。
///
/// 两步**串行**请求（`kuwo-rank-tabs` → `kuwo-rank-data?tabId=`）：该 Edge 后端
/// 是项目级并发配额，并行会自己把自己限死（见 [EdgeGate] 实测）。
/// 页签取不到时抛错，由 UI 显示可点的兜底文案（而不是假装一直在加载）。
///
/// `keepAlive`：发现页每次切回底部 tab 都会重建，不保活就会重新打两次
/// Edge 请求，在本来就紧张的配额里白白多占两份。
///
/// 整体再套一个 [previewDeadline]：卡片是副标题，绝不能为了它把用户
/// 卡在「加载榜单…」上十几秒。超时即抛错 → UI 换成可点的兜底文案。
final kuwoRankPreviewProvider =
    FutureProvider<KuwoRankPreview>((ref) async {
  ref.keepAlive();
  final api = ref.watch(kuwoRankApiProvider);
  return _fetchPreview(api).timeout(previewDeadline);
});

/// 预览的整体预算（含闸门排队 + 重试）。
const Duration previewDeadline = Duration(seconds: 7);

Future<KuwoRankPreview> _fetchPreview(KuwoRankApi api) async {
  final tabs = await api.fetchTabs();
  if (tabs.isEmpty) throw StateError('榜单页签为空');
  final tab = tabs.first;
  final books = await api.fetchRankData(tab.id);
  return (
    tabName: tab.name,
    topTitle: books.isEmpty ? '' : books.first.title,
  );
}

/// 分类浏览数据（聆阅分类页的真实契约）。
///
/// 三层结构：
/// 1. 固定分类卡（categoryId 2=有声小说 5=相声曲艺 37=儿童 …）
/// 2. `channel-tabs?categoryId=` → 该分类下的子频道（郭德纲/评书大全…）
/// 3. `albums?classifyId=&categoryId=&pn=&rn=&sortType=` → 书籍列表（分页）
extension KuwoCategoryApi on KuwoRankApi {
  /// 分类 → 子频道列表。
  Future<List<KuwoChannel>> fetchChannels(String categoryId) async {
    final body = await _get('/kuwo-channel-tabs?categoryId=$categoryId');
    if (body == null) return const [];
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tabs = json['tabs'];
      if (tabs is! List) return const [];
      return [
        for (final t in tabs)
          if (t is Map)
            KuwoChannel(id: '${t['id'] ?? ''}', name: '${t['name'] ?? ''}'),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 分类/频道下的书籍列表（分页）。
  Future<KuwoAlbumPage> fetchAlbums({
    required String categoryId,
    String classifyId = '0',
    int page = 1,
    int pageSize = 20,
    String sortType = 'playCnt',
  }) async {
    final body = await _get(
      '/kuwo-albums?classifyId=$classifyId&pn=$page&rn=$pageSize'
      '&categoryId=$categoryId&sortType=$sortType',
    );
    if (body == null) return const KuwoAlbumPage(books: [], total: 0);
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final list = json['books'];
      return KuwoAlbumPage(
        books: [
          if (list is List)
            for (final b in list)
              if (b is Map)
                KuwoRankBook(
                  id: '${b['id'] ?? ''}',
                  title: '${b['title'] ?? ''}',
                  cover: b['cover'] == null ? null : '${b['cover']}',
                  playCount: '${b['listeners'] ?? ''}',
                  // 真实观测：chapters 可能是数组（渲染成 "[]"）或数字字符串
                  chapterCount: b['chapters'] is List
                      ? '${(b['chapters'] as List).length}'
                      : '${b['chapters'] ?? ''}',
                ),
        ],
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const KuwoAlbumPage(books: [], total: 0);
    }
  }

  /// 分类树（字节码 #17953；2026-10-16 实测契约）。
  ///
  /// `GET /kuwo-classify` → `{sections:[{id,name,desc,imgUrl,categoryId,
  /// child:[{id,classifyId,categoryId,name}]}]}`。
  /// 这是**权威分类数据**（服务端可更新），替代写死的分类卡。
  Future<List<KuwoClassifySection>> fetchClassify() async {
    final body = await _get('/kuwo-classify');
    if (body == null) return const [];
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final sections = json['sections'];
      if (sections is! List) return const [];
      return [
        for (final s in sections)
          if (s is Map)
            KuwoClassifySection(
              name: '${s['name'] ?? ''}',
              categoryId: '${s['categoryId'] ?? ''}',
              desc: s['desc'] == null ? null : '${s['desc']}',
              imgUrl: s['imgUrl'] == null ? null : '${s['imgUrl']}',
              children: [
                if (s['child'] is List)
                  for (final c in (s['child'] as List))
                    if (c is Map)
                      KuwoClassifyChild(
                        name: '${c['name'] ?? ''}',
                        classifyId: '${c['classifyId'] ?? ''}',
                        categoryId: '${c['categoryId'] ?? ''}',
                      ),
              ],
            ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// 分类大类（section）。
class KuwoClassifySection {
  final String name;

  /// 传给 channel-tabs / albums 的 categoryId。
  final String categoryId;
  final String? desc;
  final String? imgUrl;
  final List<KuwoClassifyChild> children;

  const KuwoClassifySection({
    required this.name,
    required this.categoryId,
    this.desc,
    this.imgUrl,
    this.children = const [],
  });
}

/// 分类下的子类目（child）。
class KuwoClassifyChild {
  final String name;
  final String classifyId;
  final String categoryId;

  const KuwoClassifyChild({
    required this.name,
    required this.classifyId,
    required this.categoryId,
  });
}

/// 分类下的子频道。
class KuwoChannel {
  final String id;
  final String name;

  const KuwoChannel({required this.id, required this.name});
}

/// 书籍分页结果。
class KuwoAlbumPage {
  final List<KuwoRankBook> books;
  final int total;

  const KuwoAlbumPage({required this.books, required this.total});
}
