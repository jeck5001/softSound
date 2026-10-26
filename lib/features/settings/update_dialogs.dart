import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:soft_sound/services/remote_config_api.dart';
import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';

/// 打开外部链接（浏览器）。
///
/// 独立成函数便于测试替换；失败时返回 `false`（调用方给可读提示）。
typedef UrlOpener = Future<bool> Function(String url);

/// 默认实现：交给系统浏览器。
Future<bool> openInBrowser(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// 显示「检查更新」对话框。
///
/// 文案与流程对齐聆阅（字节码 #21402 的 `fetchRemoteConfig → 版本比较 → 弹窗`）：
/// - 标题：`发现新版本 v{version_name}`
/// - 内容：`{update_description}\n\n是否立即前往系统默认浏览器下载更新？`
/// - 按钮：`立即下载` / `稍后再说`
/// - 点「立即下载」→ `Linking.openURL(download_url || download_url2)`
///
/// 与聆阅不同的是：这里额外说明下载包来自上游渠道（不冒充本应用商店更新）。
Future<void> showUpdateDialog(
  BuildContext context, {
  required AppVersionInfo version,
  UrlOpener opener = openInBrowser,
}) async {
  final url = version.effectiveDownloadUrl;
  final action = await showDialog<String>(
    context: context,
    builder: (context) {
      final c = context.appColors;
      return AlertDialog(
        title: Text('${AppStrings.newVersionFound}${version.versionName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.updateContent,
              style: TextStyle(
                color: c.mutedForeground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(version.effectiveDescription),
            const SizedBox(height: 12),
            Text(
              url.isEmpty
                  ? AppStrings.updateNoLink
                  : AppStrings.updateUpstreamNote,
              style: TextStyle(color: c.mutedForeground, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('later'),
            child: const Text(AppStrings.updateLater),
          ),
          FilledButton(
            onPressed: url.isEmpty
                ? null
                : () => Navigator.of(context).pop('open'),
            child: const Text(AppStrings.updateNow),
          ),
        ],
      );
    },
  );

  if (action != 'open' || !context.mounted) return;
  final ok = await opener(url);
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppStrings.updateDownloadHint}：$url')),
    );
  }
}

/// 显示公告对话框（聆阅 `announcement` 段）。
///
/// 返回 `true` 表示用户点了「不再显示」（调用方据此写入已读指纹）。
Future<bool> showAnnouncementDialog(
  BuildContext context, {
  required Announcement announcement,
  UrlOpener opener = openInBrowser,
}) async {
  final action = await showDialog<String>(
    context: context,
    builder: (context) {
      final c = context.appColors;
      return AlertDialog(
        title: Text(
          announcement.title.isEmpty
              ? AppStrings.announcementFallbackTitle
              : announcement.title,
        ),
        content: SingleChildScrollView(
          child: Text(
            announcement.content,
            style: TextStyle(color: c.foreground, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('open'),
            child: Text(
              announcement.hasUsableLink && announcement.linkText.isNotEmpty
                  ? announcement.linkText
                  : AppStrings.understoodClose,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('mute'),
            child: const Text(AppStrings.dontShowAgain),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('close'),
            child: const Text(AppStrings.close),
          ),
        ],
      );
    },
  );

  if (action == 'mute') return true;
  if (action == 'open' && announcement.hasUsableLink) {
    final ok = await opener(announcement.linkUrl);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(announcement.linkUrl)));
    }
  }
  return false;
}
