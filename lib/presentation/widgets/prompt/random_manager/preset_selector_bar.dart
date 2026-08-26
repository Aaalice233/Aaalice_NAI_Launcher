import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../common/app_toast.dart';
import '../new_preset_dialog.dart';
import 'random_config_l10n.dart';
import 'random_manager_widgets.dart';

/// 预设选择栏组件
///
/// 显示预设下拉选择、统计信息和操作按钮
/// 采用 Dimensional Layering 风格设计
class PresetSelectorBar extends ConsumerWidget {
  const PresetSelectorBar({
    super.key,
    this.onGeneratePreview,
    this.onImportExport,
  });

  final VoidCallback? onGeneratePreview;
  final VoidCallback? onImportExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetState = ref.watch(randomPresetNotifierProvider);
    final selectedPreset = presetState.selectedPreset;
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 响应式布局：窄屏时垂直排列
          final isNarrow = constraints.maxWidth < 760;

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 预设选择下拉框
                _PresetDropdown(
                  presets: presetState.presets,
                  selectedPreset: selectedPreset,
                  onSelected: (preset) {
                    ref
                        .read(randomPresetNotifierProvider.notifier)
                        .selectPreset(preset.id);
                  },
                  onCreateNew: () => _showCreatePresetDialog(context, ref),
                ),
                // 只读模式提示（窄屏时单独一行）
                if (selectedPreset?.isDefault == true) ...[
                  const SizedBox(height: 8),
                  const _ReadOnlyIndicator(),
                ],
                const SizedBox(height: 12),
                // 统计信息 + 操作按钮
                Row(
                  children: [
                    if (selectedPreset != null)
                      Expanded(child: _StatisticsInfo(preset: selectedPreset)),
                    _ActionButtons(
                      onDelete:
                          selectedPreset != null && !selectedPreset.isDefault
                          ? () => _deletePreset(context, ref, selectedPreset)
                          : null,
                      onResetToDefault:
                          selectedPreset != null &&
                              !selectedPreset.isDefault &&
                              selectedPreset.isBasedOnDefault
                          ? () => _resetToDefault(context, ref, selectedPreset)
                          : null,
                      onGeneratePreview: onGeneratePreview,
                      onImportExport: onImportExport,
                      onSync:
                          selectedPreset != null && !selectedPreset.isDefault
                          ? () => _syncDanbooru(context, ref)
                          : null,
                      isSyncing: syncState.isSyncing,
                    ),
                  ],
                ),
              ],
            );
          }

          // 宽屏布局：横向排列，带分隔线
          return Row(
            children: [
              // 预设选择下拉框 - 固定宽度
              SizedBox(
                width: 220,
                child: _PresetDropdown(
                  presets: presetState.presets,
                  selectedPreset: selectedPreset,
                  onSelected: (preset) {
                    ref
                        .read(randomPresetNotifierProvider.notifier)
                        .selectPreset(preset.id);
                  },
                  onCreateNew: () => _showCreatePresetDialog(context, ref),
                ),
              ),
              // 垂直分隔线
              _VerticalDivider(color: colorScheme.primary),
              // 全局信息区域 - 显示预设描述 + 只读提示
              Expanded(
                child: Row(
                  children: [
                    if (selectedPreset != null &&
                        (context.l10n.presetDisplayDescription(
                                  selectedPreset,
                                ) ??
                                '')
                            .isNotEmpty)
                      Flexible(
                        child: Text(
                          context.l10n.presetDisplayDescription(
                            selectedPreset,
                          )!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 只读模式提示（默认预设时显示）
                    if (selectedPreset?.isDefault == true) ...[
                      const SizedBox(width: 12),
                      const _ReadOnlyIndicator(),
                    ],
                  ],
                ),
              ),
              // 垂直分隔线
              _VerticalDivider(color: colorScheme.secondary),
              // 操作按钮组
              _ActionButtons(
                onDelete: selectedPreset != null && !selectedPreset.isDefault
                    ? () => _deletePreset(context, ref, selectedPreset)
                    : null,
                onResetToDefault:
                    selectedPreset != null &&
                        !selectedPreset.isDefault &&
                        selectedPreset.isBasedOnDefault
                    ? () => _resetToDefault(context, ref, selectedPreset)
                    : null,
                onGeneratePreview: onGeneratePreview,
                onImportExport: onImportExport,
                onSync: selectedPreset != null && !selectedPreset.isDefault
                    ? () => _syncDanbooru(context, ref)
                    : null,
                isSyncing: syncState.isSyncing,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 显示创建预设对话框
  Future<void> _showCreatePresetDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await NewPresetDialog.show(context);
    if (result == null) return;

    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final copyFromDefault = result.mode == PresetCreationMode.template;

    final newPreset = await notifier.createPreset(
      name: result.name,
      copyFromCurrent: copyFromDefault,
    );
    await notifier.selectPreset(newPreset.id);

    if (context.mounted) {
      AppToast.success(
        context,
        context.l10n.randomManager_presetCreated(result.name),
      );
    }
  }

  Future<void> _deletePreset(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.config_deletePreset),
        content: Text(
          context.l10n.randomManager_deletePresetConfirm(preset.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .deletePreset(preset.id);
    }
  }

  Future<void> _syncDanbooru(BuildContext context, WidgetRef ref) async {
    final syncNotifier = ref.read(tagGroupSyncNotifierProvider.notifier);
    final success = await syncNotifier.syncTagGroups();

    if (context.mounted) {
      if (success) {
        AppToast.success(context, context.l10n.randomManager_syncCompleted);
      } else {
        final error = ref.read(tagGroupSyncNotifierProvider).error;
        AppToast.error(
          context,
          context.l10n.randomManager_syncFailed(
            error ?? context.l10n.randomManager_unknownError,
          ),
        );
      }
    }
  }

  Future<void> _resetToDefault(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.randomManager_resetDefaultTitle),
        content: Text(context.l10n.randomManager_resetDefaultContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.randomManager_resetDefaultConfirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .resetToDefault(preset.id);
      if (context.mounted) {
        AppToast.success(context, context.l10n.randomManager_resetDefaultDone);
      }
    }
  }
}

class _PresetDropdown extends StatefulWidget {
  const _PresetDropdown({
    required this.presets,
    required this.selectedPreset,
    required this.onSelected,
    required this.onCreateNew,
  });

  final List<RandomPreset> presets;
  final RandomPreset? selectedPreset;
  final ValueChanged<RandomPreset> onSelected;
  final VoidCallback onCreateNew;

  @override
  State<_PresetDropdown> createState() => _PresetDropdownState();
}

class _PresetDropdownState extends State<_PresetDropdown> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: _isHovered
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButton<String>(
          value: widget.selectedPreset?.id,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          isDense: true,
          icon: AnimatedRotation(
            duration: const Duration(milliseconds: 150),
            turns: 0,
            child: Icon(
              Icons.expand_more,
              size: 18,
              color: _isHovered
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface,
          ),
          items: [
            // 现有预设列表
            ...widget.presets.map((preset) {
              return DropdownMenuItem<String>(
                value: preset.id,
                child: Row(
                  children: [
                    Icon(
                      preset.isDefault
                          ? Icons.star_rounded
                          : Icons.folder_outlined,
                      size: 14,
                      color: preset.isDefault
                          ? Colors.amber
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.presetDisplayName(preset),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // 分隔线 + 新建预设选项
            DropdownMenuItem<String>(
              value: '__create_new__',
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${context.l10n.config_newPreset}...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (id) {
            if (id == '__create_new__') {
              widget.onCreateNew();
            } else if (id != null) {
              final preset = widget.presets.firstWhere((p) => p.id == id);
              widget.onSelected(preset);
            }
          },
        ),
      ),
    );
  }
}

class _StatisticsInfo extends StatelessWidget {
  const _StatisticsInfo({required this.preset});

  final RandomPreset preset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: StatItem(
              icon: Icons.category_outlined,
              label: context.l10n.randomManager_categories,
              value: '${preset.categoryCount}',
              color: colorScheme.primary,
              compact: true,
            ),
          ),
          _GradientDivider(color: colorScheme.primary),
          Flexible(
            child: StatItem(
              icon: Icons.layers_outlined,
              label: context.l10n.randomManager_tagGroups,
              value:
                  '${preset.categories.fold(0, (sum, c) => sum + c.groupCount)}',
              color: colorScheme.secondary,
              compact: true,
            ),
          ),
          _GradientDivider(color: colorScheme.secondary),
          Flexible(
            child: StatItem(
              icon: Icons.label_outlined,
              label: context.l10n.randomManager_tags,
              value: '${preset.totalTagCount}',
              color: colorScheme.tertiary,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// 渐变分隔线
class _GradientDivider extends StatelessWidget {
  const _GradientDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color.withValues(alpha: 0.3),
    );
  }
}

/// 垂直分隔线组件
class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 1,
      height: 24,
      color: color.withValues(alpha: 0.3),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    this.onDelete,
    this.onResetToDefault,
    this.onGeneratePreview,
    this.onImportExport,
    this.onSync,
    this.isSyncing = false,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onResetToDefault;
  final VoidCallback? onGeneratePreview;
  final VoidCallback? onImportExport;
  final VoidCallback? onSync;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSync != null)
          TextButton.icon(
            onPressed: isSyncing ? null : onSync,
            icon: isSyncing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined, size: 18),
            label: Text(
              isSyncing ? context.l10n.randomManager_syncing : 'Danbooru',
            ),
          ),
        if (onGeneratePreview != null)
          Tooltip(
            message: context.l10n.randomManager_generatePreview,
            child: FilledButton.icon(
              onPressed: onGeneratePreview,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(context.l10n.randomManager_generatePreview),
            ),
          ),
        if (onResetToDefault != null)
          IconButton(
            onPressed: onResetToDefault,
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: context.l10n.resetToDefaultTooltip,
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            color: colorScheme.error,
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.config_deletePreset,
          ),
        if (onImportExport != null)
          IconButton(
            onPressed: onImportExport,
            icon: const Icon(Icons.import_export_rounded),
            tooltip: context.l10n.randomManager_importExport,
          ),
      ],
    );
  }
}

/// 只读模式指示器（紧凑版，用于顶栏）
class _ReadOnlyIndicator extends StatelessWidget {
  const _ReadOnlyIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: context.l10n.randomManager_readOnlyTooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.randomManager_readOnlyMode,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
