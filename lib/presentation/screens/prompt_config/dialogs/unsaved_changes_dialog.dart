import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';

/// 未保存变更提示对话框
class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({super.key});

  /// 显示未保存变更提示对话框
  /// 返回 true 表示用户选择放弃更改，false 或 null 表示取消
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const UnsavedChangesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.preset_unsavedChanges),
      content: Text(l10n.preset_unsavedChangesConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.preset_discard),
        ),
      ],
    );
  }
}
