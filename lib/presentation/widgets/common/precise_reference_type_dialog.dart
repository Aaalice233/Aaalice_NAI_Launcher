import 'package:flutter/material.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/content_sized_adaptive_form.dart';

class PreciseReferenceTypeDialog extends StatelessWidget {
  const PreciseReferenceTypeDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  static Future<PreciseRefType?> show(BuildContext context) {
    return AdaptivePresenter.showForm<PreciseRefType>(
      context: context,
      title: context.l10n.preciseRef_referenceType,
      dialogWidth: 420,
      builder: (context, controller) =>
          PreciseReferenceTypeDialog(scrollController: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentSizedAdaptiveForm(
      scrollController: scrollController,
      content: [
        ...PreciseRefType.values.map((type) {
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
        }),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
        ),
      ],
    );
  }
}
