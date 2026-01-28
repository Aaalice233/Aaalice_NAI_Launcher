import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';

/// 预设名称输入对话框
class PresetNameDialog extends StatefulWidget {
  final String? Function(String)? validator;

  const PresetNameDialog({
    super.key,
    this.validator,
  });

  /// 显示预设名称输入对话框
  static Future<String?> show(
    BuildContext context, {
    String? Function(String)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => PresetNameDialog(validator: validator),
    );
  }

  @override
  State<PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<PresetNameDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    final error = widget.validator?.call(value);
    setState(() => _errorText = error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.presetEdit_presetName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.presetEdit_presetName,
          hintText: l10n.presetEdit_enterPresetName,
          border: const OutlineInputBorder(),
          errorText: _errorText,
        ),
        onChanged: _validate,
        onSubmitted: (value) {
          final error = widget.validator?.call(value);
          if (error == null && value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _errorText == null && _controller.text.trim().isNotEmpty
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(l10n.common_confirm),
        ),
      ],
    );
  }
}
