import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';

/// 编辑预设描述对话框
class EditDescriptionDialog extends StatefulWidget {
  final String? currentDescription;

  const EditDescriptionDialog({
    super.key,
    this.currentDescription,
  });

  /// 显示编辑描述对话框
  static Future<String?> show(
    BuildContext context, {
    String? currentDescription,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => EditDescriptionDialog(
        currentDescription: currentDescription,
      ),
    );
  }

  @override
  State<EditDescriptionDialog> createState() => _EditDescriptionDialogState();
}

class _EditDescriptionDialogState extends State<EditDescriptionDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentDescription ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: const Text('编辑描述'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '预设描述',
          hintText: '输入此预设的用途或特点...',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
        textInputAction: TextInputAction.newline,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.common_confirm),
        ),
      ],
    );
  }
}
