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
    if (compact) {
      return KeyedSubtree(
        key: const ValueKey('generation_prompt_compact_surface'),
        child: UnifiedPromptInput(
          key: const ValueKey('generation_prompt_compact_input'),
          controller: controller.promptController,
          focusNode: controller.promptFocusNode,
          surfaceColor: inputSurfaceFillColor(
            Theme.of(context).colorScheme,
            prominent: true,
          ),
          sessionId: PromptHistorySessionIds.generationPrompt,
          onOpenAssistantSettings: commands.openAssistantSettings,
          config: UnifiedPromptConfig(
            enableSyntaxHighlight: enableHighlight,
            numericEmphasisEnabled: viewData.numericEmphasisEnabled,
            enableAutocomplete: enableAutocomplete,
            enableComfyuiImport: true,
            autocompleteConfig: const AutocompleteConfig(
              showTranslation: true,
              autoInsertComma: true,
            ),
            hintText: context.l10n.prompt_inputPrompt,
          ),
          decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
          maxLines: null,
          expands: true,
          enableAssistant: false,
          onComfyuiImport: commands.importComfyuiPrompt,
          onChanged: commands.updatePrompt,
        ),
      );
    }

    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableSdSyntaxAutoConvert = ref.watch(
      sdSyntaxAutoConvertSettingsProvider,
    );
    final negative = controller.isNegativeMode;
    return UnifiedPromptInput(
      key: ValueKey(
        negative
            ? 'generation_prompt_negative_input'
            : 'generation_prompt_positive_input',
      ),
      controller: negative
          ? controller.negativeController
          : controller.promptController,
      focusNode: negative
          ? controller.negativeFocusNode
          : controller.promptFocusNode,
      sessionId: negative
          ? PromptHistorySessionIds.generationNegative
          : PromptHistorySessionIds.generationPrompt,
      onOpenAssistantSettings: commands.openAssistantSettings,
      config: UnifiedPromptConfig(
        enableSyntaxHighlight: enableHighlight,
        numericEmphasisEnabled: viewData.numericEmphasisEnabled,
        enableAutocomplete: enableAutocomplete,
        enableAutoFormat: enableAutoFormat,
        enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
        enableComfyuiImport: !negative,
        autocompleteConfig: AutocompleteConfig(
          showTranslation: true,
          showCategory: !negative,
          showCount: !negative,
          autoInsertComma: true,
        ),
        hintText: negative
            ? context.l10n.prompt_unwantedContent
            : enableAutocomplete
            ? context.l10n.prompt_describeImageWithHint
            : context.l10n.prompt_describeImage,
      ),
      decoration: const InputDecoration(contentPadding: EdgeInsets.all(12)),
      maxLines: null,
      minLines: viewData.autoGrow ? 4 : null,
      expands: !viewData.autoGrow,
      fitContent: viewData.autoGrow,
      enableAssistant: false,
      onComfyuiImport: negative ? null : commands.importComfyuiPrompt,
      onChanged: negative
          ? commands.updateNegativePrompt
          : commands.updatePrompt,
    );
  }
}
