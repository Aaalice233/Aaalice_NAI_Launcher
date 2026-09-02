import 'package:flutter/material.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../core/utils/localization_extension.dart';
import 'adaptive_dialog_frame.dart';

class PreciseReferenceTypeDialog extends StatelessWidget {
  const PreciseReferenceTypeDialog({super.key});

  static Future<PreciseRefType?> show(BuildContext context) {
    return showDialog<PreciseRefType>(
      context: context,
      builder: (context) => const PreciseReferenceTypeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(context.l10n.preciseRef_referenceType),
      content: AdaptiveDialogFrame(
        maxWidth: 420,
        maxHeight: 320,
        reservedVerticalSpace: 120,
        scaleReservedVerticalSpace: true,
        child: ListView(
          padding: EdgeInsets.zero,
          children: PreciseRefType.values.map((type) {
            return ListTile(
              key: ValueKey('precise-reference-type-${type.name}'),
              leading: Icon(type.icon),
              title: Text(
                type.getDisplayName(
                  character: context.l10n.preciseRef_typeCharacter,
                  style: context.l10n.preciseRef_typeStyle,
                  characterAndStyle:
                      context.l10n.preciseRef_typeCharacterAndStyle,
                ),
              ),
              onTap: () => Navigator.of(context).pop(type),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ],
    );
  }
}
