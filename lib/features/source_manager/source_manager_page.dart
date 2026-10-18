import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/source_rule.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_strings.dart';

/// 书源状态管理
final sourcesProvider = StateNotifierProvider<SourcesNotifier, List<SourceRule>>((ref) {
  final notifier = SourcesNotifier();
  notifier._loadBuiltInSources();
  return notifier;
});

class SourcesNotifier extends StateNotifier<List<SourceRule>> {
  SourcesNotifier() : super([]);

  Future<void> _loadBuiltInSources() async {
    final sourceFiles = [
      'assets/sources/huanting.json',
      'assets/sources/ting55.json',
      'assets/sources/ting15.json',
      'assets/sources/netease.json',
      'assets/sources/xa.json',
      'assets/sources/xiaoku.json',
      'assets/sources/liuyue.json',
      'assets/sources/xiaoliang.json',
      'assets/sources/xiaoqing.json',
      'assets/sources/lrts.json',
    ];
    
    for (final file in sourceFiles) {
      try {
        final jsonString = await rootBundle.loadString(file);
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final source = SourceRule.fromJson(json);
        
        if (!state.any((s) => s.sourceId == source.sourceId)) {
          state = [...state, source];
        }
      } catch (e) {
        debugPrint('Failed to load source from $file: $e');
      }
    }
  }

  void addSource(SourceRule source) {
    if (state.any((s) => s.sourceId == source.sourceId)) {
      return;
    }
    state = [...state, source];
  }

  void removeSource(String sourceId) {
    state = state.where((s) => s.sourceId != sourceId).toList();
  }

  void toggleSource(String sourceId) {
    state = state.map((s) {
      if (s.sourceId == sourceId) {
        return SourceRule(
          sourceId: s.sourceId,
          sourceName: s.sourceName,
          sourceUrl: s.sourceUrl,
          sourceType: s.sourceType,
          enabled: !s.enabled,
          sortOrder: s.sortOrder,
          header: s.header,
          search: s.search,
          detail: s.detail,
          chapter: s.chapter,
          audio: s.audio,
        );
      }
      return s;
    }).toList();
  }

  Future<void> reloadBuiltInSources() async {
    await _loadBuiltInSources();
  }
}

/// 书源管理页面
class SourceManagerPage extends ConsumerWidget {
  const SourceManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sourceManagerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSourceDialog(context, ref),
          ),
        ],
      ),
      body: sources.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildSourceList(context, ref, sources),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.source_outlined,
            size: 80,
            color: context.appColors.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.sourceEmptyTitle,
            style: TextStyle(
              fontSize: 18,
              color: context.appColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.sourceEmptyHint,
            style: TextStyle(color: context.appColors.mutedForeground),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _loadBuiltInSource(context, ref),
            icon: const Icon(Icons.download),
            label: const Text(AppStrings.sourceLoadBuiltIn),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showAddSourceDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.sourceAddManual),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList(
    BuildContext context,
    WidgetRef ref,
    List<SourceRule> sources,
  ) {
    final c = context.appColors;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: source.enabled ? c.accent : c.muted,
              child: Icon(
                Icons.library_music,
                color: source.enabled ? c.accentForeground : c.mutedForeground,
              ),
            ),
            title: Text(source.sourceName),
            subtitle: Text(source.sourceUrl),
            trailing: Switch(
              value: source.enabled,
              onChanged: (value) {
                ref.read(sourcesProvider.notifier).toggleSource(source.sourceId);
              },
            ),
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text(AppStrings.sourceDeleteTitle),
                  content: Text('${AppStrings.sourceDeleteConfirmPrefix}${source.sourceName}${AppStrings.sourceDeleteConfirmSuffix}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.cancel),
                    ),
                    FilledButton(
                      onPressed: () {
                        ref.read(sourcesProvider.notifier).removeSource(source.sourceId);
                        Navigator.pop(context);
                      },
                      child: const Text(AppStrings.delete),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _loadBuiltInSource(BuildContext context, WidgetRef ref) async {
    try {
      final jsonString = await rootBundle.loadString('assets/sources/ting55.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final source = SourceRule.fromJson(json);
      ref.read(sourcesProvider.notifier).addSource(source);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.sourceAddSuccessPrefix}${source.sourceName}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.sourceLoadFailedPrefix}$e')),
        );
      }
    }
  }

  void _showAddSourceDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.sourceAddTitle),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: AppStrings.sourcePasteHint,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              try {
                final json = jsonDecode(controller.text) as Map<String, dynamic>;
                final source = SourceRule.fromJson(json);
                ref.read(sourcesProvider.notifier).addSource(source);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppStrings.sourceAddSuccessPrefix}${source.sourceName}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppStrings.sourceInvalidFormatPrefix}$e')),
                );
              }
            },
            child: const Text(AppStrings.sourceAddAction),
          ),
        ],
      ),
    );
  }
}
