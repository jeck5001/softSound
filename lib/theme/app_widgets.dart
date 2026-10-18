import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_strings.dart';

/// 通用空状态 —— 移植自聆阅的空态样式。
///
/// 聆阅每处空态都是「图标 + 主文案 + 辅助说明 + 可选行动按钮」，
/// 这里统一为一个组件，避免各页面重复拼装。
class AppEmptyState extends StatelessWidget {
  /// 主图标。
  final IconData icon;

  /// 主文案（如 [AppStrings.shelfEmpty]）。
  final String title;

  /// 辅助说明（如 [AppStrings.shelfEmptyHint]）。
  final String? description;

  /// 行动按钮文案。
  final String? actionLabel;

  /// 行动按钮回调。
  final VoidCallback? onAction;

  /// 是否为紧凑布局（用于嵌入列表/区块内）。
  final bool compact;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 80,
              height: compact ? 56 : 80,
              decoration: BoxDecoration(
                color: c.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 38,
                color: c.mutedForeground,
              ),
            ),
            SizedBox(height: compact ? 12 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.foreground,
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.mutedForeground,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? 16 : 24),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 通用错误状态 —— 带重试按钮。
class AppErrorState extends StatelessWidget {
  /// 错误说明文案。
  final String message;

  /// 重试回调；为 null 时不显示按钮。
  final VoidCallback? onRetry;

  /// 重试按钮文案，默认「重新加载」。
  final String retryLabel;

  final bool compact;

  const AppErrorState({
    super.key,
    this.message = AppStrings.loadFailedNetwork,
    this.onRetry,
    this.retryLabel = AppStrings.reload,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: compact ? 32 : 44,
              color: c.mutedForeground,
            ),
            SizedBox(height: compact ? 10 : 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.mutedForeground,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 通用加载状态 —— 带文案的居中转圈。
class AppLoadingState extends StatelessWidget {
  /// 加载文案，如「正在为您高速拉取精选好书」。
  final String message;

  final bool compact;

  const AppLoadingState({
    super.key,
    this.message = AppStrings.loadingPlease,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 24 : 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 20 : 26,
              height: compact ? 20 : 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.mutedForeground,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 区块标题 —— 左侧竖条 + 标题 + 可选右侧动作。
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.foreground,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.mutedForeground,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: c.mutedForeground,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
