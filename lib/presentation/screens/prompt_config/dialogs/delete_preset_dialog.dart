import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';

/// 删除预设确认对话框
class DeletePresetDialog extends StatelessWidget {
  final String presetName;

  const DeletePresetDialog({
    super.key,
    required this.presetName,
  });

  /// 显示删除确认对话框
  static Future<bool?> show(
    BuildContext context, {
    required String presetName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DeletePresetDialog(presetName: presetName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.preset_deletePreset),
      content: Text(l10n.preset_deletePresetConfirm(presetName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: Text(l10n.common_delete),
        ),
      ],
    );
  }
}
