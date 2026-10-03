import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../l10n/app_localizations.dart';

extension AssistantTaskTypeLocalizedLabel on AssistantTaskType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    AssistantTaskType.llm => l10n.promptAssistant_taskOptimize,
    AssistantTaskType.translate => l10n.promptAssistant_taskTranslate,
    AssistantTaskType.reverse => l10n.promptAssistant_taskReverse,
    AssistantTaskType.characterReplace =>
      l10n.promptAssistant_taskCharacterReplace,
    AssistantTaskType.custom => l10n.promptAssistant_taskCustom,
    AssistantTaskType.chat => l10n.agentChat_tab,
  };
}

String localizedRuleName(AppLocalizations l10n, PromptRuleTemplate rule) {
  if (!rule.isDefault) return rule.name;
  return switch (rule.id) {
    'opt_default' => l10n.promptAssistant_defaultOptimizeRuleName,
    'translate_default' => l10n.promptAssistant_defaultTranslateRuleName,
    'reverse_default' => l10n.promptAssistant_defaultReverseRuleName,
    'character_replace_default' =>
      l10n.promptAssistant_defaultCharacterReplaceRuleName,
    'custom_default' => l10n.promptAssistant_defaultCustomRuleName,
    _ => rule.name,
  };
}
