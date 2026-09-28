import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import 'tool_base.dart';

class MagicWandTool extends EditorTool {
  MagicWandSelectionMode _mode = MagicWandSelectionMode.smartObject;
  int _tolerance = 32;
  bool _invert = false;
  bool _isApplying = false;

  MagicWandSelectionMode get mode => _mode;
  int get tolerance => _tolerance;
  bool get invert => _invert;
  bool get isApplying => _isApplying;

  void setMode(MagicWandSelectionMode value) {
    _mode = value;
  }

  void setTolerance(int value) {
    _tolerance = value.clamp(0, 255);
  }

  void setInvert(bool value) {
    _invert = value;
  }

  @override
  String get id => 'magic_wand';

  @override
  String get name => 'Magic Wand';

  @override
  IconData get icon => Icons.auto_fix_high;

  @override
  LogicalKeyboardKey? get shortcutKey => LogicalKeyboardKey.keyW;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    if (_isApplying) {
      return;
    }

    _isApplying = true;
    unawaited(
      state
          .applyMagicWand(
            event.localPosition,
            mode: _mode,
            tolerance: _tolerance,
            invert: _invert,
          )
          .whenComplete(() {
            _isApplying = false;
          }),
    );
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {}

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {}

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.editor_toolMagicWand,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == MagicWandSelectionMode.smartObject
                    ? context.l10n.editor_magicWandSmartHelp
                    : context.l10n.editor_magicWandColorHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MagicWandSelectionMode>(
                initialValue: _mode,
                decoration: InputDecoration(
                  labelText: context.l10n.editor_magicWandMode,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: MagicWandSelectionMode.smartObject,
                    child: Text(context.l10n.editor_magicWandSmartObject),
                  ),
                  DropdownMenuItem(
                    value: MagicWandSelectionMode.colorArea,
                    child: Text(context.l10n.editor_magicWandColorArea),
                  ),
                ],
                onChanged: _isApplying
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => setMode(value));
                        }
                      },
              ),
              if (_mode == MagicWandSelectionMode.colorArea) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      context.l10n.editor_tolerance,
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text('$_tolerance', style: theme.textTheme.bodySmall),
                  ],
                ),
                Slider(
                  value: _tolerance.toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  onChanged: _isApplying
                      ? null
                      : (value) {
                          setState(() => setTolerance(value.round()));
                        },
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  context.l10n.editor_magicWandInvert,
                  style: theme.textTheme.bodySmall,
                ),
                value: _invert,
                onChanged: _isApplying
                    ? null
                    : (value) {
                        setState(() => setInvert(value));
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
