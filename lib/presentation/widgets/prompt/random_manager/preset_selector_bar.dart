import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../common/app_toast.dart';
import '../../common/safe_dropdown.dart';
import '../../common/themed_input_dialog.dart';
import '../new_preset_dialog.dart';
import 'random_config_l10n.dart';

class PresetSelectorBar extends ConsumerWidget {
  const PresetSelectorBar({
    super.key,
    this.onImportExport,
    this.showWorkspaceHeading = false,
  });

  final VoidCallback? onImportExport;
  final bool showWorkspaceHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(randomPresetNotifierProvider);
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final selected = state.selectedPreset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showExpandedActions = constraints.maxWidth >= 760;
        final dropdown = KeyedSubtree(
          key: const ValueKey('random-manager-preset-selector'),
          child: _PresetDropdown(
            presets: state.presets,
            selectedPreset: selected,
            onSelected: (preset) => ref
                .read(randomPresetNotifierProvider.notifier)
                .selectPreset(preset.id),
            onCreateNew: () => _showCreatePresetDialog(context, ref),
          ),
        );
        final menu = _buildPresetMenu(
          context,
          ref,
          selected,
          syncState,
          includeSync: !showExpandedActions,
        );
        if (showWorkspaceHeading) {
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final stackControls = shouldStackWorkspacePresetHeader(
            constraints.maxWidth,
            textScale,
          );
          final controls = KeyedSubtree(
            key: const ValueKey('random-manager-controls-row'),
            child: dropdown,
          );
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.casino_outlined,
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  context.l10n.randomManager_workspaceTitle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
          final heading = stackControls
              ? Column(
                  key: const ValueKey('random-manager-heading-row'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        menu,
                      ],
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('random-manager-heading-row'),
                  children: [title, const Spacer(), menu],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [heading, const SizedBox(height: 8), controls],
          );
        }

        if (!showExpandedActions) {
          return Row(
            children: [
              Expanded(child: dropdown),
              const SizedBox(width: 8),
              menu,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 250, child: dropdown),
            const Spacer(),
            if (selected?.isDefault == true)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ReadOnlyIndicator(
                  label: context.l10n.randomManager_readOnlyMode,
                ),
              ),
            _ToolbarAction(
              icon: Icons.sync_rounded,
              tooltip: context.l10n.randomManager_syncDanbooruTags,
              loading: syncState.isSyncing,
              onPressed: selected != null && !selected.isDefault
                  ? () => _syncDanbooru(context, ref)
                  : null,
            ),
            menu,
          ],
        );
      },
    );
  }

  Widget _buildPresetMenu(
    BuildContext context,
    WidgetRef ref,
    RandomPreset? selected,
    TagGroupSyncState syncState, {
    required bool includeSync,
  }) {
    return PopupMenuButton<_PresetAction>(
      key: const ValueKey('random-manager-more-actions'),
      tooltip: context.l10n.randomManager_moreActions,
      onSelected: (action) => _handleAction(context, ref, action, selected),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _PresetAction.importExport,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.swap_vert_rounded),
            title: Text(context.l10n.randomManager_importExport),
          ),
        ),
        PopupMenuItem(
          value: _PresetAction.create,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_rounded),
            title: Text(context.l10n.config_newPreset),
          ),
        ),
        if (includeSync)
          PopupMenuItem(
            value: _PresetAction.sync,
            enabled:
                selected != null && !selected.isDefault && !syncState.isSyncing,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: syncState.isSyncing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              title: Text(context.l10n.randomManager_syncDanbooruTags),
            ),
          ),
        if (selected != null && !selected.isDefault) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _PresetAction.rename,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.common_rename),
            ),
          ),
          if (selected.isBasedOnDefault)
            PopupMenuItem(
              value: _PresetAction.reset,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt_rounded),
                title: Text(context.l10n.randomManager_resetDefaultConfirm),
              ),
            ),
          PopupMenuItem(
            value: _PresetAction.delete,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.l10n.common_delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      ],
      icon: const Icon(Icons.more_horiz_rounded),
    );
  }

  Future<void> _showCreatePresetDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await NewPresetDialog.show(context);
    if (result == null) return;

    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final preset = await notifier.createPreset(
      name: result.name,
      copyFromCurrent: result.mode == PresetCreationMode.template,
    );
    await notifier.selectPreset(preset.id);
    if (context.mounted) {
      AppToast.success(
        context,
        context.l10n.randomManager_presetCreated(result.name),
      );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _PresetAction action,
    RandomPreset? preset,
  ) async {
    switch (action) {
      case _PresetAction.importExport:
        onImportExport?.call();
      case _PresetAction.create:
        await _showCreatePresetDialog(context, ref);
      case _PresetAction.rename:
        if (preset != null) await _renamePreset(context, ref, preset);
      case _PresetAction.sync:
        await _syncDanbooru(context, ref);
      case _PresetAction.reset:
        if (preset != null) await _resetToDefault(context, ref, preset);
      case _PresetAction.delete:
        if (preset != null) await _deletePreset(context, ref, preset);
    }
  }

  Future<void> _renamePreset(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final name = await ThemedInputDialog.show(
      context: context,
      title: context.l10n.common_rename,
      labelText: context.l10n.newPresetDialog_nameLabel,
      initialValue: preset.name,
      confirmText: context.l10n.common_save,
      validator: (value) => value.trim().isEmpty
          ? context.l10n.newPresetDialog_nameRequired
          : null,
    );
    if (name == null || name == preset.name) return;
    await ref
        .read(randomPresetNotifierProvider.notifier)
        .renamePreset(preset.id, name);
  }

  Future<void> _syncDanbooru(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(tagGroupSyncNotifierProvider.notifier);
    final success = await notifier.syncTagGroups();
    if (!context.mounted) return;
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

  Future<void> _deletePreset(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(randomPresetNotifierProvider.notifier)
          .deletePreset(preset.id);
    }
  }

  Future<void> _resetToDefault(
    BuildContext context,
    WidgetRef ref,
    RandomPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true) return;
    await ref
        .read(randomPresetNotifierProvider.notifier)
        .resetToDefault(preset.id);
    if (context.mounted) {
      AppToast.success(context, context.l10n.randomManager_resetDefaultDone);
    }
  }
}

class _PresetDropdown extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeDropdown<String>(
      value: selectedPreset?.id,
      isExpanded: true,
      icon: const Icon(Icons.unfold_more_rounded, size: 18),
      items: [
        ...presets.map(
          (preset) => DropdownMenuItem(
            value: preset.id,
            child: Row(
              children: [
                Icon(
                  preset.isDefault
                      ? Icons.lock_outline_rounded
                      : Icons.tune_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.presetDisplayName(preset),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        DropdownMenuItem(
          value: '__create_new__',
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 16),
              const SizedBox(width: 8),
              Text('${context.l10n.config_newPreset}...'),
            ],
          ),
        ),
      ],
      onChanged: (id) {
        if (id == '__create_new__') {
          onCreateNew();
          return;
        }
        final preset = presets.where((item) => item.id == id).firstOrNull;
        if (preset != null) onSelected(preset);
      },
    );
  }
}

class _ReadOnlyIndicator extends StatelessWidget {
  const _ReadOnlyIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.randomManager_readOnlyTooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: loading ? null : onPressed,
      tooltip: tooltip,
      icon: loading
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 19),
    );
    return button;
  }
}

bool shouldStackWorkspacePresetHeader(double availableWidth, double textScale) {
  final scaleAdjustment = (textScale - 1).clamp(0, 2) * 100;
  return availableWidth < 360 + scaleAdjustment;
}

enum _PresetAction { importExport, create, rename, sync, reset, delete }
