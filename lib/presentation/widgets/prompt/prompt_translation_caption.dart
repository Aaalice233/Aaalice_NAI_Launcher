import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/autocomplete/tag_translation_lookup.dart';
import '../../../core/utils/localization_extension.dart';
import 'prompt_translation_controller.dart';

class PromptTranslationCaption extends ConsumerStatefulWidget {
  const PromptTranslationCaption({super.key, required this.text});
  final String text;
  @override
  ConsumerState<PromptTranslationCaption> createState() =>
      _PromptTranslationCaptionState();
}

class _PromptTranslationCaptionState
    extends ConsumerState<PromptTranslationCaption> {
  PromptTranslationController? _translation;
  TagTranslationLookup? _lookup;
  @override
  void dispose() {
    _translation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Localizations.localeOf(context).languageCode != 'zh') {
      _translation?.dispose();
      _translation = null;
      _lookup = null;
      return const SizedBox.shrink();
    }
    final lookup = ref.watch(tagTranslationLookupProvider);
    if (!identical(lookup, _lookup)) {
      _translation?.dispose();
      _lookup = lookup;
      _translation = PromptTranslationController(lookup);
    }
    _translation!.update([widget.text]);
    return ListenableBuilder(
      listenable: _translation!,
      builder: (context, _) => PromptTranslationLabel(
        value: _translation!.values[widget.text],
        onRetry: _translation!.retry,
      ),
    );
  }
}

class PromptTranslationLabel extends StatelessWidget {
  const PromptTranslationLabel({
    super.key,
    required this.value,
    required this.onRetry,
  });
  final PromptTranslation? value;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (value?.status) {
      PromptTranslationStatus.translated => value!.text!,
      PromptTranslationStatus.missing => l10n.tagMode_missingTranslation,
      PromptTranslationStatus.failed => l10n.tagMode_translationFailed,
      _ => l10n.tagMode_loadingTranslation,
    };
    final label = Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
    );
    return value?.status == PromptTranslationStatus.failed
        ? TextButton(onPressed: onRetry, child: label)
        : label;
  }
}
