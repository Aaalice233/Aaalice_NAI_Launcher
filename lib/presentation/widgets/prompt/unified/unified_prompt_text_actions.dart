import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/utils/prompt_regex_replacer.dart';
import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../presentation/utils/text_selection_utils.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_state_provider.dart';
import '../../../prompt_assistant/services/prompt_assistant_service.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/prompt_regex_rules_provider.dart';
import '../../common/app_toast.dart';
import '../prompt_blur_formatting.dart';
import 'unified_prompt_config.dart';

/// 执行提示词助手流式优化或翻译操作，并返回新的流订阅。
Future<StreamSubscription<StreamingChunk>?> runUnifiedPromptAssistantAction({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
  required TextEditingController effectiveController,
  required String sessionId,
  required bool tagMode,
  required AssistantTaskType taskType,
  required StreamSubscription<StreamingChunk>? previousSubscription,
}) async {
  final l10n = context.l10n;
  final text = ref
      .read(fixedTagsNotifierProvider)
      .stripFromPrompt(effectiveController.text)
      .trim();
  if (text.isEmpty) {
    if (context.mounted) {
      AppToast.warning(context, l10n.promptAssistant_needPrompt);
    }
    return previousSubscription;
  }

  final beforeText = effectiveController.text;
  ref.read(promptAssistantHistoryProvider.notifier).push(sessionId, beforeText);

  final stateNotifier = ref.read(promptAssistantStateProvider.notifier);
  final label = taskType == AssistantTaskType.llm
      ? l10n.promptAssistant_optimizeProcessing
      : l10n.promptAssistant_translateProcessing;
  stateNotifier.startProcessing(sessionId, label);

  final service = ref.read(promptAssistantServiceProvider);
  final buffer = StringBuffer();

  await previousSubscription?.cancel();
  final stream = taskType == AssistantTaskType.llm
      ? service.optimizePrompt(text, sessionId: sessionId)
      : tagMode
      ? service.translateTagLabels(text, sessionId: sessionId)
      : service.translatePrompt(text, sessionId: sessionId);

  return stream.listen(
    (chunk) {
      if (chunk.done) return;
      if (chunk.delta.isEmpty) return;
      buffer.write(chunk.delta);
    },
    onError: (e) {
      stateNotifier.setError(sessionId, e.toString());
      if (isMounted() && context.mounted) {
        AppToast.error(context, l10n.promptAssistant_requestFailed(e));
      }
    },
    onDone: () {
      if (buffer.isNotEmpty) {
        final finalText = buffer.toString();
        effectiveController.text = finalText;
        effectiveController.selection = TextSelection.collapsed(
          offset: effectiveController.text.length,
        );
      }
      stateNotifier.finishProcessing(sessionId);
      final afterText = effectiveController.text;
      ref
          .read(promptAssistantHistoryProvider.notifier)
          .recordExternalChange(
            sessionId,
            before: beforeText,
            after: afterText,
          );
      ref
          .read(promptAssistantHistoryProvider.notifier)
          .push(sessionId, afterText);
    },
    cancelOnError: true,
  );
}

/// 失焦时执行正则替换与提示词自动格式化。
void formatUnifiedPromptOnBlur({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
  required UnifiedPromptConfig config,
  required TextEditingController effectiveController,
}) {
  if (!config.enableRegexReplace &&
      !PromptBlurFormatting.enabled(
        sdSyntaxAutoConvert: config.enableSdSyntaxAutoConvert,
        autoFormat: config.enableAutoFormat,
        separateNumericWeightClosing: config.separateNumericWeightClosing,
      )) {
    return;
  }

  final originalValue = effectiveController.value;
  var text = originalValue.text;
  if (text.isEmpty) return;

  var changed = false;
  final messages = <String>[];

  // 正则替换（最先执行，规则匹配的是用户原样输入的文本）
  if (config.enableRegexReplace) {
    final rules = ref.read(promptRegexRulesProvider);
    final result = PromptRegexReplacer.apply(text, rules);
    if (result.changed) {
      text = result.text;
      changed = true;
      messages.add(
        context.l10n.prompt_regexReplaceApplied(result.appliedRules.length),
      );
    }
    if (isMounted() && result.invalidRules.isNotEmpty) {
      AppToast.warning(
        context,
        context.l10n.prompt_regexInvalidRules(
          result.invalidRules.map((rule) => rule.displayLabel).join(', '),
        ),
      );
    }
  }

  final formatted = PromptBlurFormatting.apply(
    text,
    context.l10n,
    sdSyntaxAutoConvert: config.enableSdSyntaxAutoConvert,
    autoFormat: config.enableAutoFormat,
    separateNumericWeightClosing: config.separateNumericWeightClosing,
    replaceUnderscores: config.replaceUnderscores,
  );
  if (formatted.text != text) {
    text = formatted.text;
    changed = true;
    messages.addAll(formatted.messages);
  }

  if (changed) {
    final selection = TextSelectionUtils.preserveLineAndColumnSelection(
      oldText: originalValue.text,
      newText: text,
      selection: originalValue.selection,
    );
    effectiveController.value = originalValue.copyWith(
      text: text,
      selection: selection,
      composing: TextRange.empty,
    );
    if (isMounted() && messages.isNotEmpty) {
      AppToast.info(context, messages.join(' + '));
    }
  }
}
