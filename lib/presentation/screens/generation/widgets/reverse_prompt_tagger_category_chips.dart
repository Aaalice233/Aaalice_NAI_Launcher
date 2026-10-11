import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/services/local_onnx_tagger_labels.dart';
import '../../../providers/reverse_prompt_provider.dart';
import '../../../widgets/common/app_toast.dart';

class ReversePromptTaggerCategoryChips extends ConsumerWidget {
  const ReversePromptTaggerCategoryChips({
    super.key,
    required this.labelsPath,
    required this.enabled,
  });

  final String labelsPath;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelCategories = ref
        .watch(reversePromptTaggerCategoriesProvider(labelsPath))
        .valueOrNull;
    if (modelCategories == null) return const SizedBox.shrink();
    final available = [
      for (final category in OnnxTaggerLabelCategory.selectable)
        if (modelCategories.contains(category)) category,
    ];
    if (available.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final selected = ref.watch(
      reversePromptProvider.select((state) => state.taggerCategories),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.reversePrompt_taggerCategories,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final category in available)
              FilterChip(
                label: Text(_labelFor(context, category)),
                selected: selected.contains(category),
                onSelected: enabled
                    ? (value) => _setCategory(
                        context,
                        ref,
                        category,
                        value,
                        available.toSet(),
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _setCategory(
    BuildContext context,
    WidgetRef ref,
    OnnxTaggerLabelCategory category,
    bool selected,
    Set<OnnxTaggerLabelCategory> available,
  ) async {
    final changed = await ref
        .read(reversePromptProvider.notifier)
        .setTaggerCategory(category, selected, available: available);
    if (!changed && context.mounted) {
      AppToast.info(context, context.l10n.reversePrompt_keepOneTaggerCategory);
    }
  }

  String _labelFor(BuildContext context, OnnxTaggerLabelCategory category) {
    return switch (category) {
      OnnxTaggerLabelCategory.general => context.l10n.tagCategory_general,
      OnnxTaggerLabelCategory.character => context.l10n.tagCategory_character,
      OnnxTaggerLabelCategory.copyright => context.l10n.tagCategory_copyright,
      OnnxTaggerLabelCategory.artist => context.l10n.tagCategory_artist,
      OnnxTaggerLabelCategory.meta => context.l10n.tagCategory_meta,
      OnnxTaggerLabelCategory.rating ||
      OnnxTaggerLabelCategory.other => category.name,
    };
  }
}
