import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// 应用自更新：检查版本 → 下载 APK → 调系统安装器。
///
/// ## 为什么必须用「自己的」更新源
///
/// 项目原有的「检查更新」走**聆阅的** `remote-config`，其 `download_url`
/// 指向聆阅作者的个人网盘（`wwayk.lanzoum.com/...`），版本号是聆阅的 `1.1.7`。
/// 对本应用而言这**既错且危险**：
///
/// - 我们的版本是 `0.2.x`，永远小于 `1.1.7` → **永远**提示"发现新版本"；
/// - 用户点「立即下载」后装上的却是**聆阅**，等于把本应用替换掉。
///
/// 所以自更新必须走独立清单，不能复用上游那段。
///
/// ## 清单格式（静态 JSON，放 GitHub Releases / 对象存储 / 自有 CDN 皆可）
///
/// ```json
/// {
///   "version_code": 30,
///   "version_name": "0.3.0",
///   "update_description": "修复 X，优化 Y",
///   "download_url": "https://example.com/qingting-0.3.0.apk",
///   "sha256": "…",
///   "force_update": false,
///   "min_supported_code": 1
/// }
/// ```
///
/// ## 尚未解决的前置条件（必须你确认）
///
/// - **签名**：release 目前仍是 debug 签名（`android/app/build.gradle.kts`
///   有 TODO）。Android 拒绝「签名不一致」的覆盖安装 —— 正式分发前
///   必须先配正式签名并从此固定，否则用户装不上更新。
/// - **托管位置**：清单与 APK 放哪里由你决定。
class UpdateManifest {
  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    this.updateDescription = '',
    this.downloadUrl = '',
    this.sha256 = '',
    this.forceUpdate = false,
    this.minSupportedCode = 0,
  });

  final int versionCode;
  final String versionName;
  final String updateDescription;
  final String downloadUrl;

  /// APK 的 SHA-256（小写十六进制）。为空则跳过校验（不推荐）。
  final String sha256;
  final bool forceUpdate;

  /// `versionCode` 低于此值的安装必须更新。
  final int minSupportedCode;

  /// 解析清单；字段不合法返回 null（调用方给可读提示）。
  static UpdateManifest? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final code = raw['version_code'];
    final name = raw['version_name'];
    if (code is! int || name is! String || name.trim().isEmpty) return null;
    return UpdateManifest(
      versionCode: code,
      versionName: name.trim(),
      updateDescription: '${raw['update_description'] ?? ''}'.trim(),
      downloadUrl: '${raw['download_url'] ?? ''}'.trim(),
      sha256: '${raw['sha256'] ?? ''}'.trim().toLowerCase(),
      forceUpdate: raw['force_update'] == true,
      minSupportedCode:
          raw['min_supported_code'] is int ? raw['min_supported_code'] as int : 0,
    );
  }

  bool get hasDownload => downloadUrl.startsWith('http');
}

/// 检查 / 下载 / 安装 的编排（纯逻辑，便于单测）。
class AppUpdater {
  AppUpdater({
    required this.manifestUrl,
    required this.currentVersionCode,
    this.fallbackUrls = const [],
    Dio? dio,
  }) : _dio = dio ?? _defaultDio();

  /// 创建 Dio。
  ///
  /// 注意：Dart 的 `HttpClient` **不读取** Android 系统代理设置（OkHttp 会），
  /// 所以「模拟器里设了代理、App 却仍直连」是正常现象。真机直连即可；
  /// 若你的网络必须走代理，用 `--dart-define=UPDATE_PROXY=host:port` 构建。
  static Dio _defaultDio() {
    const fromDefine = String.fromEnvironment('UPDATE_PROXY');
    final dio = Dio();
    if (fromDefine.isNotEmpty) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (_) => 'PROXY $fromDefine';
          return client;
        },
      );
    }
    return dio;
  }

  /// 所有候选清单地址（去重、保持顺序）。
  List<String> get _candidates {
    final out = <String>[];
    for (final u in [manifestUrl, ...fallbackUrls]) {
      if (u.startsWith('http') && !out.contains(u)) out.add(u);
    }
    return out;
  }

  /// 自更新清单地址（主）。为空 = 未配置 → UI 必须明确说"未配置"，
  /// **绝不能**回退到聆阅的地址。
  final String manifestUrl;

  /// 备用清单地址（主地址不可达时依次尝试）。
  ///
  /// 实测 `raw.githubusercontent.com` 在部分网络下**间歇性超时**
  /// （同一分钟内有 200 也有 000），单一地址会让"检查更新"像坏了一样。
  final List<String> fallbackUrls;
  final int currentVersionCode;
  final Dio _dio;

  bool get isConfigured => manifestUrl.startsWith('http');

  /// 拉取清单；依次尝试主地址与备用地址，全部失败才返回 null。
  Future<UpdateManifest?> fetchManifest() async {
    if (!isConfigured) return null;
    for (final url in _candidates) {
      // 每个地址重试 2 次：GitHub raw 存在间歇性超时，
      // 单次失败不代表真的不可用。
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await _dio.get<String>(
            url,
            options: Options(
              responseType: ResponseType.plain,
              // 清单必须实时：CDN 缓存会导致"检查不到新版本"
              headers: {'Cache-Control': 'no-cache'},
              // 8 秒足够；太长会让用户以为卡死
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
            ),
          );
          final body = res.data;
          if (body == null || body.trim().isEmpty) break;
          final parsed = UpdateManifest.tryParse(jsonDecode(body));
          if (parsed != null) return parsed;
        } catch (e) {
          debugPrint('拉取更新清单失败 ($url, 第 ${attempt + 1} 次): $e');
        }
      }
    }
    return null;
  }

  /// 是否需要更新（清单版本号更大）。
  bool needsUpdate(UpdateManifest m) => m.versionCode > currentVersionCode;

  /// 是否强制更新。
  bool isForced(UpdateManifest m) =>
      m.forceUpdate ||
      (m.minSupportedCode > 0 && currentVersionCode < m.minSupportedCode);

  /// APK 下载候选前缀（空串 = 直连）。
  ///
  /// 实测（走本机代理）：直连 36 秒下完 71MB（约 1.9 MB/s），足够。
  /// 保留 ghproxy 仅作备用；每个候选都必须过 SHA-256 校验，
  /// 所以镜像返回错误内容也不会被安装。
  static const List<String> downloadMirrors = [
    '',
    'https://ghproxy.net/',
  ];

  /// 下载 APK 到临时目录；失败或校验不通过返回 null。
  ///
  /// 依次尝试直连与镜像。每个候选都要过 SHA-256 校验，
  /// 所以即使镜像返回了错误内容也不会被安装。
  Future<File?> downloadApk(
    UpdateManifest m, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!m.hasDownload) return null;
    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}/update-${m.versionCode}.apk');

    for (final prefix in downloadMirrors) {
      final url = '$prefix${m.downloadUrl}';
      try {
        if (await target.exists()) await target.delete();
        await _dio.download(
          url,
          target.path,
          onReceiveProgress: onProgress,
          options: Options(
            receiveTimeout: const Duration(minutes: 10),
            sendTimeout: const Duration(seconds: 15),
          ),
        );
        if (!await target.exists() || await target.length() == 0) continue;

        if (m.sha256.isNotEmpty) {
          final actual = await sha256OfFile(target);
          if (actual != m.sha256) {
            debugPrint('APK 校验失败（$url）: 期望 ${m.sha256}, 实际 $actual');
            await target.delete();
            continue;
          }
        }
        return target;
      } catch (e) {
        debugPrint('下载 APK 失败（$url）: $e');
      }
    }
    return null;
  }

  /// 调系统安装器。返回是否成功唤起。
  ///
  /// 注意：Android 8.0+ 需要用户为本应用开启「安装未知应用」权限，
  /// 否则系统会弹授权页而不是安装页 —— 这是系统行为，无法绕过。
  /// 调用方应在点击前给用户一句说明，避免以为"点了没反应"。
  static Future<bool> installApk(File apk) async {
    try {
      final result = await OpenFilex.open(
        apk.path,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('唤起安装器失败: $e');
      return false;
    }
  }
}

/// 分块计算文件 SHA-256（避免把整个 APK 读进内存）。
Future<String> sha256OfFile(File f) async {
  final output = AccumulatorSink<Digest>();
  final input = sha256.startChunkedConversion(output);
  await for (final chunk in f.openRead()) {
    input.add(chunk);
  }
  input.close();
  return output.events.single.toString();
}

// ── 配置 ────────────────────────────────────────────────────────────
//
// 【需要你填】把 APK 和 manifest.json 传到任意可公开下载的位置
// （GitHub Releases 最省事），然后把清单地址填到这里。
//
// 留空时「检查更新」会明确显示「尚未配置更新源」，**不会**回退到
// 聆阅的 remote-config（那会把应用替换成聆阅）。

/// 自更新清单地址。
/// 主清单地址：**GitHub raw**。
///
/// 选型经过实测（都走本机代理 127.0.0.1:7890）：
/// - `raw.githubusercontent.com`：2.4 秒返回，**内容实时**（无缓存延迟）
/// - `cdn.jsdelivr.net@main`：1.0 秒返回，但**有缓存延迟** ——
///   实测发版后仍返回旧 sha256，会导致用户下载新包后校验失败
///
/// 所以主地址用 raw，jsDelivr 仅作兜底（它能覆盖 raw 偶发超时的场景）。
const String kUpdateManifestUrl =
    'https://raw.githubusercontent.com/jeck5001/softSound/main/manifest.json';

/// 备用清单地址（主地址失败时依次尝试）。
const List<String> kUpdateManifestFallbacks = [
  'https://raw.githubusercontent.com/jeck5001/softSound/refs/heads/main/manifest.json',
  'https://cdn.jsdelivr.net/gh/jeck5001/softSound@main/manifest.json',
];

/// 当前 versionCode（与 pubspec 的 `version: x.y.z+N` 的 N 一致）。
const int kCurrentVersionCode = 4;

final appUpdaterProvider = Provider<AppUpdater>((ref) {
  return AppUpdater(
    manifestUrl: kUpdateManifestUrl,
    fallbackUrls: kUpdateManifestFallbacks,
    currentVersionCode: kCurrentVersionCode,
  );
});
