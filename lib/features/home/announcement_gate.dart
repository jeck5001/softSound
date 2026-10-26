import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soft_sound/services/remote_config_api.dart';

import '../settings/update_dialogs.dart';

/// 启动时的公告闸门（聆阅 `announcement` 契约）。
///
/// 行为对齐字节码 #20358 / #20382：
/// - 拉 `remote-config` → 有 `announcement` 才考虑展示；
/// - 用 **内容指纹**（djb2 → base36）判断是否已被「不再显示」；
/// - 展示一次后本会话不再重复（避免切页签反复弹）。
///
/// 失败/限流/无公告时静默跳过，绝不阻塞启动或弹错误。
class AnnouncementGate extends ConsumerStatefulWidget {
  const AnnouncementGate({super.key, this.child});

  final Widget? child;

  @override
  ConsumerState<AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends ConsumerState<AnnouncementGate> {
  /// 本会话已尝试过（无论结果），避免热重载/重建时重复请求。
  static bool _attemptedThisSession = false;

  @override
  void initState() {
    super.initState();
    if (!_attemptedThisSession) {
      _attemptedThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  Future<void> _maybeShow() async {
    RemoteConfig cfg;
    try {
      cfg = await ref.read(remoteConfigProvider.future);
    } catch (_) {
      return;
    }
    final a = cfg.announcement;
    if (a == null || (a.title.isEmpty && a.content.isEmpty)) return;

    final store = ref.read(announcementDismissStoreProvider);
    if (await store.isDismissed(a)) return;
    if (!mounted) return;

    final mute = await showAnnouncementDialog(context, announcement: a);
    if (mute) await store.dismiss(a);
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

/// 供测试重置「本会话已尝试」标记。
@visibleForTesting
void resetAnnouncementGateForTest() =>
    _AnnouncementGateState._attemptedThisSession = false;
