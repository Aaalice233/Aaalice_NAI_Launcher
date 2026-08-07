import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../widgets/common/editable_double_field.dart';

/// 编辑对话框返回结果
class PreciseRefEntryEditResult {
  const PreciseRefEntryEditResult({
    required this.name,
    required this.type,
    required this.strength,
    required this.fidelity,
  });

  final String name;
  final PreciseRefType type;
  final double strength;
  final double fidelity;
}

/// 精准参考库条目编辑对话框
///
/// 编辑名称、类型与默认参数（强度/保真度）。
/// 与精准参考面板一致：数值输入不设上下限，滑条范围 0-1。
class PreciseRefEntryEditDialog extends StatefulWidget {
  const PreciseRefEntryEditDialog({super.key, required this.entry});

  final PreciseRefLibraryEntry entry;

  static Future<PreciseRefEntryEditResult?> show(
    BuildContext context,
    PreciseRefLibraryEntry entry,
  ) {
    return showDialog<PreciseRefEntryEditResult>(
      context: context,
      builder: (context) => PreciseRefEntryEditDialog(entry: entry),
    );
  }

  @override
  State<PreciseRefEntryEditDialog> createState() =>
      _PreciseRefEntryEditDialogState();
}

class _PreciseRefEntryEditDialogState extends State<PreciseRefEntryEditDialog> {
  late final TextEditingController _nameController;
  late PreciseRefType _type;
  late double _strength;
  late double _fidelity;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _type = widget.entry.type;
    _strength = widget.entry.strength;
    _fidelity = widget.entry.fidelity;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      PreciseRefEntryEditResult(
        name: _nameController.text.trim().isEmpty
            ? widget.entry.name
            : _nameController.text.trim(),
        type: _type,
        strength: _strength,
        fidelity: _fidelity,
      ),
    );
  }

  String _typeLabel(BuildContext context, PreciseRefType type) {
    final l10n = context.l10n;
    return type.getDisplayName(
      character: l10n.preciseRef_typeCharacter,
      style: l10n.preciseRef_typeStyle,
      characterAndStyle: l10n.preciseRef_typeCharacterAndStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.preciseRefLib_editEntry),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('precise-ref-edit-name-field'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.preciseRefLib_nameLabel,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.preciseRef_referenceType,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<PreciseRefType>(
              key: const Key('precise-ref-edit-type-selector'),
              segments: [
                for (final type in PreciseRefType.values)
                  ButtonSegment(
                    value: type,
                    icon: Icon(type.icon, size: 16),
                    label: Text(
                      _typeLabel(context, type),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 16),
            _buildSliderRow(
              label: l10n.preciseRef_strength,
              value: _strength,
              fieldKey: const Key('precise-ref-edit-strength-field'),
              onChanged: (value) => setState(() => _strength = value),
            ),
            const SizedBox(height: 8),
            _buildSliderRow(
              label: l10n.preciseRef_fidelity,
              value: _fidelity,
              fieldKey: const Key('precise-ref-edit-fidelity-field'),
              onChanged: (value) => setState(() => _fidelity = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          key: const Key('precise-ref-edit-confirm'),
          onPressed: _submit,
          child: Text(l10n.common_confirm),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required Key fieldKey,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0.0, 1.0),
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
        EditableDoubleField(
          key: fieldKey,
          value: value,
          decimals: 2,
          width: 56,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
