import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soft_sound/theme/app_colors.dart';
import 'package:soft_sound/theme/app_strings.dart';
import 'package:soft_sound/theme/app_theme.dart';
import 'package:soft_sound/theme/effects_settings.dart';
import 'package:soft_sound/theme/playback_settings.dart';
import 'package:soft_sound/theme/theme_controller.dart';

import 'package:soft_sound/services/remote_config_api.dart';
import 'package:soft_sound/services/system_settings_bridge.dart';

import '../downloads/downloads_notifier.dart';
import 'update_dialogs.dart';
import 'package:soft_sound/data/models/listener_stats.dart';
import 'package:soft_sound/data/repositories/stats_repository.dart';

/// 设置页 —— 对应聆阅的设置屏。
///
/// 分组照搬聆阅：
/// - 🎨 个性化与主题（外观主题、主题配色、全局动效、点击特效、节日特效）
/// - 🔊 播放与音频（倍速、跳过片头尾、后台保活）
/// - 🔄 数据与存储（清除缓存）
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final playback = ref.watch(playbackSettingsProvider);
    final playbackCtrl = ref.read(playbackSettingsProvider.notifier);
    final effects = ref.watch(effectsSettingsProvider);
    final effectsCtrl = ref.read(effectsSettingsProvider.notifier);
    final cacheBytes = ref.watch(cacheUsageProvider).valueOrNull ?? 0;
    final stats = ref.watch(listenerStatsProvider).valueOrNull ??
        const ListenerStats();
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ---------------------------------------------- 🎨 个性化与主题
          const SettingsSectionTitle(title: AppStrings.settingsAppearance),

          // 主题模式
          SettingsTile(
            icon: Icons.brightness_6_outlined,
            title: AppStrings.appearanceTheme,
            subtitle: appearance.mode.label,
            onTap: () => _pickThemeMode(context, controller, appearance),
          ),

          // 主题配色
          SettingsTile(
            icon: Icons.palette_outlined,
            title: AppStrings.themeSelectColor,
            subtitle: appearance.accent.label,
            trailing: _AccentDots(
              selected: appearance.accent,
              onSelect: controller.setAccent,
            ),
            onTap: () => _pickAccent(context, controller, appearance),
          ),

          SettingsTile(
            icon: Icons.animation_outlined,
            title: AppStrings.globalAnimations,
            subtitle: AppStrings.globalAnimationsHint,
            showSwitch: true,
            switchValue: effects.animationsEnabled,
            onTap: () =>
                effectsCtrl.setAnimationsEnabled(!effects.animationsEnabled),
          ),
          SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: AppStrings.tapEffect,
            subtitle: AppStrings.tapEffectHint,
            showSwitch: true,
            switchValue: effects.tapFxEnabled,
            // 动效总开关关闭时，点击特效不可能生效 → 置灰，避免"开了也没用"
            enabled: effects.animationsEnabled,
            onTap: () => effectsCtrl.setTapFxEnabled(!effects.tapFxEnabled),
          ),

          // ---------------------------------------------- 🔊 播放与音频
          const SettingsSectionTitle(title: AppStrings.settingsAudio),

          SettingsTile(
            icon: Icons.speed_outlined,
            title: AppStrings.speedSetting,
            subtitle: playback.speedLabel,
            onTap: () => _pickSpeed(context, playbackCtrl, playback),
          ),
          SettingsTile(
            icon: Icons.high_quality_outlined,
            title: AppStrings.audioQuality,
            subtitle: playback.quality.label,
            onTap: () => _pickQuality(context, playbackCtrl, playback),
          ),
          SettingsTile(
            icon: Icons.skip_next_outlined,
            title: AppStrings.introOutro,
            subtitle: playbackCtrl.introOutroSummary,
            onTap: () => _pickIntroOutro(context, playbackCtrl, playback),
          ),
          SettingsTile(
            icon: Icons.volume_up_outlined,
            title: AppStrings.volumeBoost,
            subtitle: playback.volumeBoostEnabled
                ? playbackCtrl.gainLabel()
                : AppStrings.volumeBoostNote,
            showSwitch: true,
            switchValue: playback.volumeBoostEnabled,
            onTap: () =>
                playbackCtrl.setVolumeBoostEnabled(!playback.volumeBoostEnabled),
          ),
          SettingsTile(
            icon: Icons.graphic_eq_outlined,
            title: AppStrings.audioMix,
            subtitle: AppStrings.audioMixHint,
            showSwitch: true,
            switchValue: playback.audioMixing,
            onTap: () => playbackCtrl.setAudioMixing(!playback.audioMixing),
          ),
          SettingsTile(
            icon: Icons.reorder_outlined,
            title: AppStrings.chapterOrderPlay,
            subtitle: playback.chapterOrderAscending
                ? AppStrings.ascending
                : AppStrings.descending,
            showSwitch: true,
            switchValue: playback.chapterOrderAscending,
            onTap: () => playbackCtrl.setChapterOrderAscending(
              !playback.chapterOrderAscending,
            ),
          ),
          // 后台常驻：聆阅只给文案，这里补上「真的跳到系统页面」的一步。
          // 之前这一行是灰着的恒开开关（点了没反应），属于假 UI。
          SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: AppStrings.enableBackground,
            subtitle: AppStrings.bgKeepAliveNote3,
            trailing: const Text('去设置'),
            onTap: () => _showKeepAliveGuide(context),
          ),

          // ---------------------------------------------- 🔄 数据与存储
          const SettingsSectionTitle(title: AppStrings.settingsData),

          SettingsTile(
            icon: Icons.cleaning_services_outlined,
            title: AppStrings.cacheClearTitle,
            subtitle: '${AppStrings.cacheOccupied}${_formatBytes(cacheBytes)}',
            onTap: () => _confirmClearCache(context, ref, cacheBytes),
          ),
          SettingsTile(
            icon: Icons.bar_chart_outlined,
            title: AppStrings.listeningTotal,
            subtitle: stats.formattedListening,
            onTap: () => _confirmResetStats(context, ref),
          ),
          SettingsTile(
            icon: Icons.system_update_outlined,
            title: AppStrings.checkUpdate,
            // 此前这里写死「已是最新版本」并且点击只弹同一句话 —— 是假功能。
            // 现在走聆阅的真实契约（remote-config），见 [_checkUpdate]。
            subtitle: AppStrings.updateBrowserHint,
            onTap: () => _checkUpdate(context, ref),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppStrings.appName} · v${AppStrings.appVersion}',
              style: TextStyle(color: c.mutedForeground, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 交互

  Future<void> _pickThemeMode(
    BuildContext context,
    AppearanceController controller,
    AppearanceState appearance,
  ) async {
    final picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (context) => _OptionSheet<AppThemeMode>(
        title: AppStrings.appearanceTheme,
        options: AppThemeMode.values,
        labelOf: (m) => m.label,
        selected: appearance.mode,
      ),
    );
    if (picked != null) await controller.setMode(picked);
  }

  Future<void> _pickAccent(
    BuildContext context,
    AppearanceController controller,
    AppearanceState appearance,
  ) async {
    final picked = await showModalBottomSheet<AppAccent>(
      context: context,
      builder: (context) => _OptionSheet<AppAccent>(
        title: AppStrings.themeSelectColor,
        options: AppAccent.values,
        labelOf: (a) => a.label,
        selected: appearance.accent,
        colorOf: (a) => a.resolve(Theme.of(context).brightness),
      ),
    );
    if (picked != null) await controller.setAccent(picked);
  }

  /// 选择播放倍速。
  Future<void> _pickSpeed(
    BuildContext context,
    PlaybackSettingsController ctrl,
    PlaybackSettingsState playback,
  ) async {
    final picked = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => _OptionSheet<double>(
        title: AppStrings.speedSetting,
        options: PlaybackSettingsController.speedOptions,
        labelOf: (v) => v == 1.0 ? '${v}x（${AppStrings.speedReset}）' : '${v}x',
        selected: playback.speed,
      ),
    );
    if (picked != null) await ctrl.setSpeed(picked);
  }

  /// 选择音质。
  Future<void> _pickQuality(
    BuildContext context,
    PlaybackSettingsController ctrl,
    PlaybackSettingsState playback,
  ) async {
    final picked = await showModalBottomSheet<AudioQuality>(
      context: context,
      builder: (context) => _OptionSheet<AudioQuality>(
        title: AppStrings.selectQuality,
        options: AudioQuality.values,
        labelOf: (q) => q.label,
        selected: playback.quality,
      ),
    );
    if (picked != null) await ctrl.setQuality(picked);
  }

  /// 片头/片尾跳过设置。
  Future<void> _pickIntroOutro(
    BuildContext context,
    PlaybackSettingsController ctrl,
    PlaybackSettingsState playback,
  ) async {
    /// 可选秒数档位。
    const choices = <int>[15, 30, 60, 90, 120];

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final c = sheetContext.appColors;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.introOutro,
                        style: TextStyle(
                          color: c.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              SwitchListTile(
                title: Text(
                  AppStrings.skipIntro,
                  style: TextStyle(color: c.foreground, fontSize: 15),
                ),
                subtitle: Text(
                  '${playback.introSeconds}s',
                  style: TextStyle(color: c.mutedForeground, fontSize: 12),
                ),
                value: playback.skipIntro,
                onChanged: (v) => ctrl.setSkipIntro(v),
              ),
              SwitchListTile(
                title: Text(
                  AppStrings.skipOutro,
                  style: TextStyle(color: c.foreground, fontSize: 15),
                ),
                subtitle: Text(
                  '${playback.outroSeconds}s',
                  style: TextStyle(color: c.mutedForeground, fontSize: 12),
                ),
                value: playback.skipOutro,
                onChanged: (v) => ctrl.setSkipOutro(v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.skipIntroNote,
                    style: TextStyle(color: c.mutedForeground, fontSize: 12),
                  ),
                ),
              ),
              // 秒数快选
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final s in choices)
                      ChoiceChip(
                        label: Text('${s}s'),
                        selected: playback.introSeconds == s,
                        onSelected: (sel) {
                          if (sel) ctrl.setIntroSeconds(s);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearCache(
    BuildContext context,
    WidgetRef ref,
    int cacheBytes,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.cacheClearTitle),
        content: Text(
          '${AppStrings.cacheClearConfirm}${_formatBytes(cacheBytes)}'
          '${AppStrings.cacheNote}',
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
    if ((confirmed ?? false)) {
      // 真正清空下载缓存。
      await ref.read(downloadsProvider.notifier).clearAll();
      ref.invalidate(cacheUsageProvider);
      if (!context.mounted) return;
      _snack(context, AppStrings.cacheCleared);
    }
  }

  /// 后台保活引导（对应聆阅 `bgKeepAliveNote*` / `bgKeepAliveStep*` 文案）。
  ///
  /// 两步都做成可点按钮，直接跳到对应的系统页面 —— 只给文字的话，
  /// 用户还得自己去翻「设置 → 应用 → 电池」，实际不会去。
  Future<void> _showKeepAliveGuide(BuildContext context) async {
    final bridge = SystemSettingsBridge();
    final ignoring = await bridge.isIgnoringBatteryOptimizations();
    if (!context.mounted) return;

    final status = ignoring == null
        ? null
        : ignoring
            ? '已加入电池优化白名单'
            : '尚未加入电池优化白名单';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.appColors;
        return AlertDialog(
          title: const Text(AppStrings.backgroundKeepAlive),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: ignoring!
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(AppStrings.bgKeepAliveNote,
                    style: TextStyle(color: c.mutedForeground, fontSize: 13)),
                const SizedBox(height: 12),
                Text(AppStrings.bgKeepAliveStep1,
                    style: TextStyle(color: c.foreground, fontSize: 14)),
                Text(AppStrings.bgKeepAliveNote2,
                    style: TextStyle(color: c.mutedForeground, fontSize: 12)),
                const SizedBox(height: 8),
                Text(AppStrings.bgKeepAliveStep2,
                    style: TextStyle(color: c.foreground, fontSize: 14)),
                Text(AppStrings.bgKeepAliveNote4,
                    style: TextStyle(color: c.mutedForeground, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(AppStrings.understoodClose),
            ),
            TextButton(
              onPressed: () => bridge.openAppSettings(),
              child: const Text('应用设置'),
            ),
            FilledButton(
              onPressed: () => bridge.openBatteryOptimizationSettings(),
              child: const Text(AppStrings.enableNow),
            ),
          ],
        );
      },
    );
  }

  /// 检查更新（聆阅 `remote-config` 契约，2026-10-26 实测）。
  ///
  /// 流程与字节码 #21402 一致：拉配置 → 逐段比较版本号 → 有更新弹窗，
  /// 无更新提示「当前已是最新版本 (vX)」。限流/失败给可读提示，不假装成功。
  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    _snack(context, AppStrings.checkingUpdate);
    RemoteConfig cfg;
    try {
      // 复用会话级缓存（与启动公告共用同一次请求）。
      cfg = await ref.read(remoteConfigProvider.future);
    } catch (_) {
      if (context.mounted) _snack(context, AppStrings.networkError);
      return;
    }
    if (!context.mounted) return;

    if (!cfg.shouldPromptUpdate(AppStrings.appVersion)) {
      _snack(context, '${AppStrings.alreadyLatest}${AppStrings.appVersion})');
      return;
    }
    await showUpdateDialog(context, version: cfg.version);
  }

  /// 确认清空累计收听统计。
  Future<void> _confirmResetStats(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.listeningTotal),
        content: const Text(AppStrings.resetStatsConfirm),
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
      await ref.read(statsRepositoryProvider).resetListening();
      ref.invalidate(listenerStatsProvider);
      if (!context.mounted) return;
      _snack(context, AppStrings.statsReset);
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 字节数格式化（B / KB / MB / GB）。
String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(value >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// 设置分组标题。
class SettingsSectionTitle extends StatelessWidget {
  final String title;

  const SettingsSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: c.mutedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// 设置行。
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showSwitch;
  final bool switchValue;
  final bool enabled;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showSwitch = false,
    this.switchValue = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final fg = enabled ? c.foreground : c.mutedForeground;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Icon(icon, size: 22, color: c.mutedForeground),
        title: Text(title, style: TextStyle(color: fg, fontSize: 15)),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: TextStyle(color: c.mutedForeground, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        trailing: showSwitch
            ? Switch(
                value: switchValue,
                onChanged: enabled ? (_) {} : null,
              )
            : (trailing ??
                (onTap == null
                    ? null
                    : Icon(Icons.chevron_right,
                        size: 18, color: c.mutedForeground))),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

/// 主题色小圆点组（当前选中高亮）。
class _AccentDots extends StatelessWidget {
  final AppAccent selected;
  final ValueChanged<AppAccent> onSelect;

  const _AccentDots({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final c = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in AppAccent.values)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: GestureDetector(
              onTap: () => onSelect(a),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: a.resolve(brightness),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: a == selected ? c.foreground : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 通用单选底部弹层。
class _OptionSheet<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final Color Function(T)? colorOf;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.selected,
    this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: c.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          for (final option in options)
            ListTile(
              leading: colorOf == null
                  ? null
                  : Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorOf!(option),
                        shape: BoxShape.circle,
                      ),
                    ),
              title: Text(
                labelOf(option),
                style: TextStyle(color: c.foreground, fontSize: 15),
              ),
              trailing: option == selected
                  ? Icon(Icons.check, color: c.primary, size: 20)
                  : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
