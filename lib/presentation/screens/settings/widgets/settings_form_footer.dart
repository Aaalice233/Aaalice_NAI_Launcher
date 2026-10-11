import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';

class SettingsFormFooter extends StatelessWidget {
  const SettingsFormFooter({super.key, required this.onSave, this.leading});

  final VoidCallback onSave;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (leading != null) leading!,
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.common_cancel),
                  ),
                  FilledButton(
                    onPressed: onSave,
                    child: Text(context.l10n.common_save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
