import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edge_gate.dart';

/// 聆阅「远程配置」契约 —— 2026-10-26 从 Hermes 字节码 #20358 函数体深挖 + 实测。
///
/// 字节码里这个模块（`remote-config`）同时负责四件事，全部由**一次请求**下发：
///
/// ```
/// POST {edge}/functions/v1/remote-config      (空 body `{}`)
///   headers: apikey / Authorization: Bearer <anonKey>
/// → {code:0, message:"ok", data:{
///      version: {version_code, version_name, update_description,
///                download_url, download_url2, has_update, force_update},
///      announcement: {title, content, has_link, link_url, link_text,
///                     open_external, created_at, updated_at} | null,
///      umeng: {enabled, app_key, channel},
///      play_api: {enabled, url},
///      festivals: [...],
///      server_time: "2026-10-26 11:32:22"
///   }}
/// ```
///
/// 字节码里的 `DEFAULT_CONFIG` 常量（逐字）：版本字段全空/`false`、
/// `announcement: null`、`umeng:{enabled:false, app_key:'', channel:'default'}`、
/// `play_api:{enabled:false, url:''}`、`festivals: []`。
///
/// **本地缓存**：键 `tingshu_remote_config_cache_v1`（逐字），
/// 拉取失败时回落缓存，避免离线时更新检查与公告全部消失。
///
/// **play_api**：`enabled && url` 时，酷我播放地址改用
/// `{host}/kuwo.php?type={type}&rid={rid}`（字节码 #17989 `buildPlayUrl`），
/// host 取 URL 的 origin 且去掉 `:80`（#17988 `resolvePlayHost`）。
/// 当前服务端为 `enabled:false`，即不启用。
class RemoteConfigApi {
  RemoteConfigApi({
    Dio? dio,
    this.gate,
    this.timeout = const Duration(seconds: 10),
    this.maxAttempts = 2,
    this.retryDelay = const Duration(milliseconds: 600),
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final EdgeGate? gate;
  final Duration timeout;
  final int maxAttempts;
  final Duration retryDelay;

  static const String fnBase =
      'https://backend.appmiaoda.com/projects/supabase345057433544081408/functions/v1';

  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhw'
      'IjoyMTAxNjk1MzAzLCJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwic3ViIjoiYW5vbiJ9'
      '.d_zv-NO7ifqZtHZHdEFYo0Kaxldn9NeW7Yy4YmHnsnc';

  /// 本地缓存键（字节码逐字）。
  static const String cacheKey = 'tingshu_remote_config_cache_v1';

  /// 公告「已关闭」指纹键（字节码逐字：`rc_ann_dismiss_v1`）。
  ///
  /// 字节码行为：用户点「不再显示」时，把 `announcementHash(announcement)`
  /// 写进该键；下次启动若指纹相同则不再弹。公告内容一改，指纹就变，
  /// 于是会重新提示 —— 不需要服务端配合。
  static const String dismissKey = 'rc_ann_dismiss_v1';

  /// 拉远程配置；失败时返回 [RemoteConfig.fallback]（而不是抛异常）。
  Future<RemoteConfig> fetch() async {
    final g = gate ?? edgeGate;
    return g.run(() async {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) await Future<void>.delayed(retryDelay);
        try {
          final r = await _dio.post<String>(
            '$fnBase/remote-config',
            data: const <String, dynamic>{},
            options: Options(
              responseType: ResponseType.plain,
              contentType: Headers.jsonContentType,
              validateStatus: (c) => c != null && c < 600,
              headers: {'apikey': anonKey, 'Authorization': 'Bearer $anonKey'},
              receiveTimeout: timeout,
              sendTimeout: timeout,
            ),
          );
          final body = r.data;
          if (body == null) continue;
          if (body.contains('projectConcurrencyLimitExceeded')) continue;
          final parsed = parseResponse(body);
          if (parsed != null) return parsed;
        } catch (_) {
          // 重试
        }
      }
      return RemoteConfig.fallback;
    });
  }

  /// 解析响应（独立方法便于 fixture 单测）。
  ///
  /// 字节码语义：`JSON.parse(body)` 后要求 `code === 0`（或缺失）且 `data` 存在。
  RemoteConfig? parseResponse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final code = json['code'];
      if (code != null && code != 0) return null;
      final data = json['data'];
      if (data is! Map) return null;
      return parseData(data);
    } catch (_) {
      return null;
    }
  }

  /// 解析 `data` 段（也是本地缓存的形状）。
  RemoteConfig parseData(Map<dynamic, dynamic> data) {
    return RemoteConfig(
      version: _parseVersion(data['version']),
      announcement: _parseAnnouncement(data['announcement']),
      playApi: _parsePlayApi(data['play_api']),
      serverTime: _str(data['server_time']),
    );
  }

  AppVersionInfo _parseVersion(Object? raw) {
    if (raw is! Map) return const AppVersionInfo();
    return AppVersionInfo(
      versionCode: raw['version_code'] is num
          ? (raw['version_code'] as num).toInt()
          : int.tryParse('${raw['version_code']}') ?? 0,
      versionName: _str(raw['version_name']),
      updateDescription: _str(raw['update_description']),
      downloadUrl: _str(raw['download_url']),
      downloadUrl2: _str(raw['download_url2']),
      hasUpdate: raw['has_update'] == true,
      forceUpdate: raw['force_update'] == true,
    );
  }

  Announcement? _parseAnnouncement(Object? raw) {
    if (raw is! Map) return null;
    final title = _str(raw['title']);
    final content = _str(raw['content']);
    if (title.isEmpty && content.isEmpty) return null;
    return Announcement(
      title: title,
      content: content,
      hasLink: raw['has_link'] == true,
      linkUrl: _str(raw['link_url']),
      linkText: _str(raw['link_text']),
      openExternal: raw['open_external'] == true,
    );
  }

  PlayApiConfig _parsePlayApi(Object? raw) {
    if (raw is! Map) return const PlayApiConfig();
    return PlayApiConfig(
      enabled: raw['enabled'] == true,
      url: _str(raw['url']),
    );
  }

  static String _str(Object? v) => v == null ? '' : '$v';
}

/// 远程配置。
class RemoteConfig {
  const RemoteConfig({
    this.version = const AppVersionInfo(),
    this.announcement,
    this.playApi = const PlayApiConfig(),
    this.serverTime = '',
  });

  /// 字节码 `DEFAULT_CONFIG` 的等价物。
  static const RemoteConfig fallback = RemoteConfig();

  final AppVersionInfo version;
  final Announcement? announcement;
  final PlayApiConfig playApi;
  final String serverTime;

  /// 是否应提示更新（`has_update` 且确有更高版本号）。
  ///
  /// 字节码先按 `.` 切分逐段比数字；这里用同样的逐段比较，
  /// 避免 `1.1.10 < 1.1.7` 这类字符串比较错误。
  bool shouldPromptUpdate(String currentVersion) =>
      version.hasUpdate &&
      version.versionName.isNotEmpty &&
      compareVersions(version.versionName, currentVersion) > 0;

  /// 逐段比较点分版本号：`a > b` 返回正数，相等 0，`a < b` 负数。
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final pa = parts(a);
    final pb = parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }
}

/// 版本信息（字节码 `version` 段）。
class AppVersionInfo {
  const AppVersionInfo({
    this.versionCode = 0,
    this.versionName = '',
    this.updateDescription = '',
    this.downloadUrl = '',
    this.downloadUrl2 = '',
    this.hasUpdate = false,
    this.forceUpdate = false,
  });

  final int versionCode;
  final String versionName;
  final String updateDescription;
  final String downloadUrl;
  final String downloadUrl2;
  final bool hasUpdate;
  final bool forceUpdate;

  /// 首选下载地址（主地址为空时用备用地址，字节码同款兜底）。
  String get effectiveDownloadUrl =>
      downloadUrl.isNotEmpty ? downloadUrl : downloadUrl2;

  /// 更新说明（空时用聆阅的默认文案）。
  String get effectiveDescription =>
      updateDescription.trim().isEmpty ? '修复已知问题，优化使用体验' : updateDescription;
}

/// 公告（字节码 `announcement` 段）。
class Announcement {
  const Announcement({
    required this.title,
    required this.content,
    this.hasLink = false,
    this.linkUrl = '',
    this.linkText = '',
    this.openExternal = false,
  });

  final String title;
  final String content;
  final bool hasLink;
  final String linkUrl;
  final String linkText;
  final bool openExternal;

  /// 是否有可跳转链接。
  bool get hasUsableLink => hasLink && linkUrl.trim().isNotEmpty;

  /// 「不再显示」用的稳定指纹。
  ///
  /// 字节码 #20382 `announcementHash`：把 title / content / link_url / link_text
  /// 用 `\u0001` 拼接后做 djb2（初值 5381，`hash*33 + charCode`，`>>> 0`），
  /// 最后 `toString(36)`。这里逐条等价实现，保证跨端「已读」判定一致。
  String get hash => announcementHash(
    title: title,
    content: content,
    linkUrl: linkUrl,
    linkText: linkText,
  );

  static String announcementHash({
    required String title,
    required String content,
    required String linkUrl,
    required String linkText,
  }) {
    final joined = '$title\u0001$content\u0001$linkUrl\u0001$linkText';
    var hash = 5381;
    for (var i = 0; i < joined.length; i++) {
      // JS: hash = ((hash << 5) + hash + code) >>> 0
      hash = ((hash << 5) + hash + joined.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toRadixString(36);
  }
}

/// 播放代理配置（字节码 `play_api` 段）。
class PlayApiConfig {
  const PlayApiConfig({this.enabled = false, this.url = ''});

  final bool enabled;
  final String url;

  /// 是否真的启用（两者都要有）。
  bool get isActive => enabled && url.trim().isNotEmpty;

  /// 播放代理的 origin（去掉 `:80`），即字节码 #17988 `resolvePlayHost`。
  String get host {
    final u = url.trim();
    final m = RegExp(r'^https?://[^/]+', caseSensitive: false).firstMatch(u);
    if (m == null) return '';
    return m.group(0)!.replaceFirst(RegExp(r':80$'), '');
  }

  /// 构造播放地址，即字节码 #17989 `buildPlayUrl(host, type, rid)`。
  String buildPlayUrl({required String type, required String rid}) {
    if (!isActive) return '';
    return '$host/kuwo.php?type=$type&rid=${Uri.encodeComponent(rid)}';
  }
}

/// 远程配置 Provider（会话内缓存一次）。
final remoteConfigProvider = FutureProvider<RemoteConfig>(
  (ref) => RemoteConfigApi().fetch(),
);

/// 公告「已读」状态（持久化在 [RemoteConfigApi.dismissKey]）。
///
/// 与聆阅一致：按**内容指纹**判定，而不是按 id 或时间。
class AnnouncementDismissStore {
  AnnouncementDismissStore({this.prefs});

  SharedPreferences? prefs;

  Future<SharedPreferences> _p() async =>
      prefs ??= await SharedPreferences.getInstance();

  /// 该公告是否已被用户关掉。
  Future<bool> isDismissed(Announcement a) async {
    try {
      final p = await _p();
      return p.getString(RemoteConfigApi.dismissKey) == a.hash;
    } catch (_) {
      return false;
    }
  }

  /// 记住该公告已被关掉。
  Future<void> dismiss(Announcement a) async {
    try {
      final p = await _p();
      await p.setString(RemoteConfigApi.dismissKey, a.hash);
    } catch (_) {
      // 写失败不阻断 UI
    }
  }

  /// 清除（调试/测试用）。
  Future<void> reset() async {
    try {
      final p = await _p();
      await p.remove(RemoteConfigApi.dismissKey);
    } catch (_) {}
  }
}

/// 全局「已读公告」存储。
final announcementDismissStoreProvider = Provider<AnnouncementDismissStore>(
  (ref) => AnnouncementDismissStore(),
);
