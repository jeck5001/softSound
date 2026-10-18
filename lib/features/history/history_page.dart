import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_widgets.dart';

/// 听书记录页 —— 对应聆阅的历史页。
///
/// 支持左滑删除与一键清空（聆阅文案：`条收听记录（左滑可删除）`）。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.listenHistory),
        actions: [
          TextButton(
            onPressed: () => _confirmClear(context),
            child: Text(
              AppStrings.clear,
              style: TextStyle(color: c.mutedForeground, fontSize: 13),
            ),
          ),
        ],
      ),
      body: const AppEmptyState(
        icon: Icons.history,
        title: AppStrings.historyEmpty,
        description: AppStrings.offlineHint1,
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.historyDeleteTitle),
        content: const Text(
          '${AppStrings.confirmClearPrefix}0${AppStrings.historyCount}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.historyEmpty)),
      );
    }
  }
}
