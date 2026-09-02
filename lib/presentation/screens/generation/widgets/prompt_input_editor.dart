import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../themes/core/input_surface_style.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/prompt/unified/unified_prompt_config.dart';
import '../../../widgets/prompt/unified/unified_prompt_input.dart';
import 'prompt_input_controller.dart';
import 'prompt_input_models.dart';

class PromptInputEditor extends ConsumerWidget {
  const PromptInputEditor({
    super.key,
    required this.controller,
    required this.commands,
    required this.viewData,
    this.compact = false,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final PromptInputViewData viewData;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableHighlight = ref.watch(highlightEmphasisSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableSdSyntaxAutoConvert = ref.watch(
      sdSyntaxAutoConvertSettingsProvider,
    );
    final negative = controller.isNegativeMode;
    final promptController = negative
        ? controller.negativeController
        : controller.promptController;
    final focusNode = negative
        ? controller.negativeFocusNode
        : controller.promptFocusNode;

    return KeyedSubtree(
      key: const ValueKey('generation_prompt_compact_input'),
      child: Container(
        key: const ValueKey('generation_prompt_compact_surface'),
        child: UnifiedPromptInput(
          key: ValueKey(
            negative
                ? 'generation_prompt_negative_input'
                : 'generation_prompt_positive_input',
          ),
          controller: promptController,
          focusNode: focusNode,
          surfaceColor: compact
              ? inputSurfaceFillColor(
                  Theme.of(context).colorScheme,
                  prominent: true,
                )
              : null,
          sessionId: negative
              ? PromptHistorySessionIds.generationNegative
              : PromptHistorySessionIds.generationPrompt,
          onOpenAssistantSettings: commands.openAssistantSettings,
          config: UnifiedPromptConfig(
            enableSyntaxHighlight: enableHighlight,
            numericEmphasisEnabled: viewData.numericEmphasisEnabled,
            enableAutocomplete: enableAutocomplete,
            enableAutoFormat: compact ? false : enableAutoFormat,
            enableSdSyntaxAutoConvert: compact
                ? false
                : enableSdSyntaxAutoConvert,
            enableComfyuiImport: !negative,
            autocompleteConfig: AutocompleteConfig(
              showTranslation: true,
              showCategory: !negative,
              showCount: !negative,
              autoInsertComma: true,
            ),
            hintText: compact
                ? negative
                      ? context.l10n.prompt_unwantedContent
                      : context.l10n.prompt_inputPrompt
                : negative
                ? context.l10n.prompt_unwantedContent
                : enableAutocomplete
                ? context.l10n.prompt_describeImageWithHint
                : context.l10n.prompt_describeImage,
          ),
          decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
          maxLines: null,
          minLines: compact ? null : (viewData.autoGrow ? 4 : null),
          expands: compact || !viewData.autoGrow,
          fitContent: !compact && viewData.autoGrow,
          enableAssistant: false,
          onComfyuiImport: negative ? null : commands.importComfyuiPrompt,
          onChanged: negative
              ? commands.updateNegativePrompt
              : commands.updatePrompt,
        ),
      ),
    );
  }
}
