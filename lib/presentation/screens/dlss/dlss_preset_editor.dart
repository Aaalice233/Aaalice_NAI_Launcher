import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_presets.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/dlss_provider.dart';
import '../../widgets/common/safe_dropdown.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../settings/widgets/settings_card.dart';
import 'dlss_options_editor.dart';

enum _PresetAction { create, save, rename, delete }

class DlssPresetEditor extends ConsumerStatefulWidget {
  const DlssPresetEditor({super.key, this.enabled = true});
  final bool enabled;
  @override
  ConsumerState<DlssPresetEditor> createState() => _DlssPresetEditorState();
}

class _DlssPresetEditorState extends ConsumerState<DlssPresetEditor> {
  bool _busy = false;
  Object? _error;

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy || !widget.enabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handle(_PresetAction action) {
    final controller = ref.read(dlssProvider);
    final selected = controller.presetState.selected;
    final l10n = context.l10n;
    return _perform(() async {
      if (action == _PresetAction.save) {
        await controller.savePreset(selected.id);
        return;
      }
      if (action == _PresetAction.delete) {
        final confirmed = await ThemedConfirmDialog.showDelete(
          context: context,
          itemName: _name(selected, l10n),
          content: l10n.dlss_deletePresetHint,
        );
        if (confirmed && mounted) await controller.deletePreset(selected.id);
        return;
      }
      final rename = action == _PresetAction.rename;
      final name = await ThemedInputDialog.show(
        context: context,
        title: rename ? l10n.dlss_renamePreset : l10n.dlss_createPreset,
        labelText: l10n.dlss_presetName,
        initialValue: rename ? selected.name : null,
        validator: (value) =>
            controller.presetState.nameAvailable(
              value,
              exceptId: rename ? selected.id : null,
            )
            ? null
            : l10n.dlss_invalidPresetName,
      );
      if (name == null || !mounted) return;
      if (rename) {
        await controller.renamePreset(selected.id, name);
      } else {
        await controller.createPreset(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(dlssProvider);
    final state = controller.presetState;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = widget.enabled && !_busy;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsCard(
              key: const Key('dlss-preset-group'),
              title: l10n.dlss_parameterPreset,
              icon: Icons.bookmark_border,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _presetSelector(controller, state, enabled, l10n),
                    const SizedBox(height: 8),
                    Text(
                      state.modified
                          ? l10n.dlss_draftSaved
                          : state.selected.builtIn
                          ? l10n.dlss_builtinPreset
                          : l10n.dlss_customPreset,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_error != null)
                      Text(
                        '$_error',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DlssOptionsEditor(
              value: state.options,
              onChanged: enabled ? controller.setOptions : null,
              onReset: enabled
                  ? () => _perform(
                      () => controller.selectPreset(state.selected.id),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetSelector(
    DlssController controller,
    DlssPresetState state,
    bool enabled,
    AppLocalizations l10n,
  ) => Row(
    children: [
      Expanded(
        child: SafeDropdown<String>(
          key: const Key('dlss-preset-selector'),
          value: state.selected.id,
          isExpanded: true,
          itemHeight: null,
          items: [
            for (final preset in state.presets)
              DropdownMenuItem(
                value: preset.id,
                child: Tooltip(
                  message: _name(preset, l10n),
                  child: Text(
                    _name(preset, l10n),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
          onChanged: enabled
              ? (id) {
                  if (id != null) {
                    _perform(() => controller.selectPreset(id));
                  }
                }
              : null,
        ),
      ),
      const SizedBox(width: 4),
      _presetMenu(state, enabled, l10n),
    ],
  );

  Widget _presetMenu(
    DlssPresetState state,
    bool enabled,
    AppLocalizations l10n,
  ) => PopupMenuButton<_PresetAction>(
    key: const Key('dlss-preset-actions'),
    enabled: enabled,
    tooltip: l10n.dlss_managePresets,
    onSelected: _handle,
    itemBuilder: (_) => [
      PopupMenuItem(
        value: _PresetAction.create,
        child: Text(l10n.dlss_createPreset),
      ),
      if (!state.selected.builtIn) ...[
        PopupMenuItem(
          value: _PresetAction.save,
          enabled: state.modified,
          child: Text(l10n.dlss_savePreset),
        ),
        PopupMenuItem(
          value: _PresetAction.rename,
          child: Text(l10n.dlss_renamePreset),
        ),
        PopupMenuItem(
          value: _PresetAction.delete,
          child: Text(l10n.common_delete),
        ),
      ],
    ],
  );

  static String _name(DlssPreset preset, AppLocalizations l10n) =>
      switch (preset.id) {
        DlssPresetState.defaultId => l10n.dlss_presetLight,
        'soft-light' => l10n.dlss_presetSoft,
        'natural-light' => l10n.dlss_presetNatural,
        'cinematic-soft' => l10n.dlss_presetCinema,
        'crisp-light' => l10n.dlss_presetCrisp,
        'color-light' => l10n.dlss_presetColor,
        _ => preset.name ?? preset.id,
      };
}
