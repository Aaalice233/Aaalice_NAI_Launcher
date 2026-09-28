import 'dart:math' as math;

import '../../models/agent_protocol.dart';

Map<String, dynamic> chatReasoningPayload(AgentReasoningRequest? reasoning) {
  if (reasoning == null) return const {};
  return switch (reasoning.api) {
    AgentReasoningApi.deepSeek => {
      if (reasoning.enabled || reasoning.sendWhenDisabled)
        'thinking': {'type': reasoning.enabled ? 'enabled' : 'disabled'},
      if (reasoning.enabled)
        if (reasoning.effort case final effort?) 'reasoning_effort': effort,
    },
    AgentReasoningApi.qwen => {
      'enable_thinking': reasoning.enabled,
      if (reasoning.effort case final effort?) 'reasoning_effort': effort,
    },
    AgentReasoningApi.openRouter => {
      if (reasoning.enabled || reasoning.sendWhenDisabled)
        'reasoning': {
          'effort': reasoning.enabled
              ? reasoning.effort
              : reasoning.effort ?? 'none',
        },
    },
    AgentReasoningApi.openAiCompletions => {
      if (reasoning.effort case final effort?) 'reasoning_effort': effort,
    },
    AgentReasoningApi.mistralPromptMode => {
      if (reasoning.enabled) 'prompt_mode': 'reasoning',
    },
    AgentReasoningApi.mistralEffort => {
      if (reasoning.enabled) 'reasoning_effort': reasoning.effort ?? 'high',
    },
    _ => const {},
  };
}

Map<String, dynamic> anthropicReasoningPayload({
  AgentReasoningRequest? reasoning,
  String? legacyLevel,
  int? maxOutputTokens,
  int? modelMaxOutputTokens,
}) {
  final legacyThinkingBudget = switch (legacyLevel) {
    'minimal' => 1024,
    'low' => 2048,
    'medium' => 8192,
    'high' || 'xhigh' || 'max' => 16384,
    _ => null,
  };
  final thinkingBudget = reasoning?.api == AgentReasoningApi.anthropicBudget
      ? reasoning!.budgetTokens
      : legacyThinkingBudget;
  final adaptive = reasoning?.api == AgentReasoningApi.anthropicAdaptive;
  final enabled = reasoning?.enabled ?? thinkingBudget != null;
  final configuredModelMaxTokens = modelMaxOutputTokens;
  final modelMaxTokens =
      configuredModelMaxTokens != null && configuredModelMaxTokens > 0
      ? configuredModelMaxTokens
      : 4096;
  final totalTokens = enabled && thinkingBudget != null
      ? maxOutputTokens == null
            ? modelMaxTokens
            : math.min(maxOutputTokens + thinkingBudget, modelMaxTokens)
      : maxOutputTokens ?? modelMaxTokens;
  final clampedThinkingBudget = thinkingBudget == null
      ? null
      : math.min(thinkingBudget, math.max(0, totalTokens - 1024));
  return {
    'max_tokens': totalTokens,
    if (adaptive && enabled) ...{
      'thinking': {'type': 'adaptive', 'display': 'summarized'},
      if (reasoning?.effort case final effort?)
        'output_config': {'effort': effort},
    } else if (enabled && thinkingBudget != null)
      'thinking': {
        'type': 'enabled',
        'budget_tokens': clampedThinkingBudget == 0
            ? 1024
            : clampedThinkingBudget,
        'display': 'summarized',
      }
    else if (reasoning != null && !enabled && reasoning.sendWhenDisabled)
      'thinking': {'type': 'disabled'},
  };
}

Map<String, dynamic>? geminiThinkingConfig(AgentReasoningRequest? reasoning) {
  return switch (reasoning?.api) {
    AgentReasoningApi.geminiBudget =>
      reasoning!.enabled
          ? {'includeThoughts': true, 'thinkingBudget': reasoning.budgetTokens}
          : reasoning.sendWhenDisabled
          ? {'thinkingBudget': 0}
          : null,
    AgentReasoningApi.geminiLevel =>
      reasoning!.enabled
          ? {'includeThoughts': true, 'thinkingLevel': reasoning.effort}
          : reasoning.sendWhenDisabled
          ? {'thinkingLevel': reasoning.effort}
          : null,
    _ => null,
  };
}

String? responsesReasoningEffort(
  AgentReasoningRequest? reasoning,
  String? legacyLevel,
) {
  return reasoning?.api == AgentReasoningApi.openAiResponses
      ? reasoning!.enabled
            ? reasoning.effort
            : reasoning.sendWhenDisabled
            ? reasoning.effort ?? 'none'
            : null
      : legacyLevel;
}
