import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';

/// 存在未保存修改时展示的退出确认对话框。
class EditorExitConfirmDialog extends StatelessWidget {
  const EditorExitConfirmDialog({
    super.key,
    required this.canExportAndClose,
    required this.onSaveAndExit,
  });

  final bool Function() canExportAndClose;
  final Future<void> Function() onSaveAndExit;

  static Future<bool?> show(
    BuildContext context, {
    required bool Function() canExportAndClose,
    required Future<void> Function() onSaveAndExit,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditorExitConfirmDialog(
        canExportAndClose: canExportAndClose,
        onSaveAndExit: onSaveAndExit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.editor_confirmExitTitle),
      content: Text(context.l10n.editor_confirmExitContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.common_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.editor_exit),
        ),
        FilledButton(
          onPressed: canExportAndClose()
              ? () async {
                  Navigator.pop(context, false);
                  await onSaveAndExit();
                }
              : null,
          child: Text(context.l10n.editor_saveAndExit),
        ),
      ],
    );
  }
}
