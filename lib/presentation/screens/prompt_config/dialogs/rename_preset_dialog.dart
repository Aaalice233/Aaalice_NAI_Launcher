import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';

/// 重命名预设对话框
class RenamePresetDialog extends StatefulWidget {
  final String currentName;
  final String? Function(String)? validator;

  const RenamePresetDialog({
    super.key,
    required this.currentName,
    this.validator,
  });

  /// 显示重命名对话框
  static Future<String?> show(
    BuildContext context, {
    required String currentName,
    String? Function(String)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => RenamePresetDialog(
        currentName: currentName,
        validator: validator,
      ),
    );
  }

  @override
  State<RenamePresetDialog> createState() => _RenamePresetDialogState();
}

class _RenamePresetDialogState extends State<RenamePresetDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
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

  void _submit() {
    final error = widget.validator?.call(_controller.text);
    if (error == null) {
      Navigator.pop(context, _controller.text.trim());
    } else {
      setState(() => _errorText = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.preset_rename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.preset_presetName,
          hintText: l10n.presetEdit_enterPresetName,
          border: const OutlineInputBorder(),
          errorText: _errorText,
        ),
        onChanged: _validate,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.common_confirm),
        ),
      ],
    );
  }
}
