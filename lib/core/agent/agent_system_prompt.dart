import '../../data/models/agent/agent_settings.dart';

String composeAgentSystemPrompt({
  required String builtInPrompt,
  required String customInstructions,
  required AgentSystemPromptMode mode,
  required String runtimeContext,
}) {
  final builtIn = builtInPrompt.trim();
  final custom = customInstructions.trim();
  return [
    if (mode == AgentSystemPromptMode.override)
      custom
    else ...[
      builtIn,
      if (custom.isNotEmpty)
        '<user_behavior_instructions>\n$custom\n</user_behavior_instructions>',
    ],
    runtimeContext.trim(),
  ].where((section) => section.isNotEmpty).join('\n\n');
}
