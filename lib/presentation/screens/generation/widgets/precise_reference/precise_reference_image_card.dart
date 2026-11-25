import 'package:flutter/material.dart';

import '../../../../../core/constants/model_capabilities.dart';
import '../../../../../core/enums/precise_ref_type.dart';
import '../../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/image/image_params.dart';
import '../../../../widgets/common/decoded_memory_image.dart';
import '../../../../widgets/common/hover_image_preview.dart';
import '../../../../widgets/common/image_card_action.dart';
import '../../../../widgets/common/image_viewport_surface.dart';
import 'precise_reference_card_header.dart';
import 'precise_reference_slider_row.dart';
import 'precise_reference_warning.dart';

class PreciseReferenceImageCard extends StatelessWidget {
  const PreciseReferenceImageCard({
    super.key,
    required this.index,
    required this.reference,
    required this.capabilities,
    required this.outfitWillBeSkipped,
    required this.onRemove,
    required this.onSaveToLibrary,
    required this.onEnabledChanged,
    required this.onTypeChanged,
    required this.onPreferSameOutfitChanged,
    required this.onStrengthChanged,
    required this.onFidelityChanged,
  });

  final int index;
  final PreciseReference reference;
  final PreciseReferenceCapabilities capabilities;
  final bool outfitWillBeSkipped;
  final VoidCallback onRemove;
  final ImageCardCallback onSaveToLibrary;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<PreciseRefType> onTypeChanged;
  final ValueChanged<bool?> onPreferSameOutfitChanged;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onFidelityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedOpacity(
        key: ValueKey('precise-reference-enabled-opacity-$index'),
        opacity: reference.enabled ? 1.0 : 0.48,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            if (outfitWillBeSkipped &&
                reference.type == PreciseRefType.costume) ...[
              const SizedBox(height: 8),
              PreciseReferenceWarning(
                message: l10n.preciseRef_outfitUnsupported,
              ),
            ],
            const SizedBox(height: 12),
            PreciseReferenceSliderRow(
              label: l10n.preciseRef_strength,
              value: reference.strength,
              maximum: capabilities.strengthSliderMax,
              onChanged: onStrengthChanged,
            ),
            if (capabilities.supportsFidelity)
              PreciseReferenceSliderRow(
                label: l10n.preciseRef_fidelity,
                value: reference.fidelity,
                onChanged: onFidelityChanged,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PreciseReferenceCardHeader(
      index: index,
      enabled: reference.enabled,
      onEnabledChanged: onEnabledChanged,
      thumbnail: _buildThumbnail(),
      editor: _buildTypeEditor(context),
      actions: [
        ImageCardAction(
          id: ImageCardActionId.saveToLibrary,
          key: Key('precise-reference-save-to-library-$index'),
          icon: Icons.bookmark_add_outlined,
          iconColor: colors.primary,
          label: context.l10n.preciseRefLib_saveCurrentToLibrary,
          invoke: onSaveToLibrary,
        ),
        ImageCardAction(
          id: ImageCardActionId.delete,
          key: Key('precise-reference-delete-$index'),
          icon: Icons.delete_outline,
          iconColor: colors.error,
          label: context.l10n.preciseRef_remove,
          invoke: onRemove,
          isDanger: true,
        ),
      ],
    );
  }

  Widget _buildTypeEditor(BuildContext context) {
    final type = reference.type;
    final showPreference =
        capabilities.supportsOutfit && type.acceptsSameOutfitPreference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTypeDropdown(context),
        if (showPreference)
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: ValueKey('precise-reference-prefer-outfit-$index'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                context.l10n.preciseRef_preferSameOutfit,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: type.effectiveSameOutfitPreference(
                reference.preferSameOutfit,
              ),
              onChanged: onPreferSameOutfitChanged,
            ),
          ),
      ],
    );
  }

  Widget _buildTypeDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return DropdownButtonFormField<PreciseRefType>(
      key: ValueKey(reference.type),
      initialValue: reference.type,
      isDense: false,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(
        labelText: l10n.preciseRef_referenceType,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final type in {
          ...PreciseRefType.selectable(outfit: capabilities.supportsOutfit),
          reference.type,
        })
          DropdownMenuItem(
            value: type,
            child: Text(
              type.getDisplayName(
                character: l10n.preciseRef_typeCharacter,
                style: l10n.preciseRef_typeStyle,
                characterAndStyle: l10n.preciseRef_typeCharacterAndStyle,
                outfit: l10n.preciseRef_typeOutfit,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null && value != reference.type) onTypeChanged(value);
      },
    );
  }

  Widget _buildThumbnail() {
    return HoverImagePreview(
      imageBytes: reference.image,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 64,
          height: 64,
          color: ImageViewportSurface.background,
          child: DecodedMemoryImage(
            bytes: reference.image,
            fit: BoxFit.cover,
            maxLogicalWidth: 64,
            maxLogicalHeight: 64,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.person,
                size: 24,
                color: ImageViewportSurface.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
