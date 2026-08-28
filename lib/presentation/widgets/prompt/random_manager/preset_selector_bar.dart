import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_prompt_result.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_mode_provider.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_group_sync_provider.dart';
import '../../common/app_toast.dart';
import '../../common/safe_dropdown.dart';
import '../new_preset_dialog.dart';
import 'random_config_l10n.dart';

class PresetSelectorBar extends ConsumerWidget {
  const PresetSelectorBar({
    super.key,
    this.onGeneratePreview,
    this.onImportExport,
    this.showWorkspaceHeading = false,
  });

  final VoidCallback? onGeneratePreview;
  final VoidCallback? onImportExport;
  final bool showWorkspaceHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(randomPresetNotifierProvider);
    final syncState = ref.watch(tagGroupSyncNotifierProvider);
    final mode = ref.watch(randomModeNotifierProvider);
    final selected = state.selectedPreset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDescription = constraints.maxWidth >= 760;
        final dropdown = KeyedSubtree(
          key: const ValueKey('random-manager-mode-selector'),
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
          includeSync: !showDescription,
        );
        final previewButton = FilledButton.icon(
          key: const ValueKey('random-manager-preview-action'),
          onPressed: onGeneratePreview,
          icon: const Icon(Icons.shuffle_rounded),
          label: Text(context.l10n.randomManager_generatePreview),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        );

        if (showWorkspaceHeading) {
          final controls = constraints.maxWidth < 360
              ? Column(
                  key: const ValueKey('random-manager-controls-row'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dropdown,
                    const SizedBox(height: 8),
                    previewButton,
                  ],
                )
              : Row(
                  key: const ValueKey('random-manager-controls-row'),
                  children: [
                    Expanded(child: dropdown),
                    const SizedBox(width: 8),
                    previewButton,
                  ],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                key: const ValueKey('random-manager-heading-row'),
                children: [
                  Text(
                    context.l10n.randomManager_workspaceTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${context.l10n.randomManager_currentMode} · ${mode.getName(context.l10n)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  menu,
                ],
              ),
              const SizedBox(height: 8),
              controls,
            ],
          );
        }

        return Row(
          children: [
            Flexible(
              flex: showDescription ? 0 : 1,
              child: SizedBox(
                width: showDescription ? 250 : double.infinity,
                child: dropdown,
              ),
            ),
            if (showDescription && selected != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.l10n.presetDisplayDescription(selected) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ] else
              const SizedBox(width: 8),
            if (selected?.isDefault == true && showDescription)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ReadOnlyIndicator(
                  label: context.l10n.randomManager_readOnlyMode,
                ),
              ),
            _ToolbarAction(
              icon: Icons.shuffle_rounded,
              tooltip: context.l10n.randomManager_generatePreview,
              emphasized: true,
              onPressed: onGeneratePreview,
            ),
            if (showDescription)
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
      case _PresetAction.sync:
        await _syncDanbooru(context, ref);
      case _PresetAction.reset:
        if (preset != null) await _resetToDefault(context, ref, preset);
      case _PresetAction.delete:
        if (preset != null) await _deletePreset(context, ref, preset);
    }
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
    this.emphasized = false,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool emphasized;
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
    if (!emphasized) return button;
    return IconButton.filledTonal(
      onPressed: loading ? null : onPressed,
      tooltip: tooltip,
      icon: loading
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 19),
    );
  }
}

enum _PresetAction { importExport, create, sync, reset, delete }
