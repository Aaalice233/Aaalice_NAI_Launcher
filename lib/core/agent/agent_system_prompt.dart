import '../../data/models/agent/agent_settings.dart';

String composeAgentSystemPrompt({
  required String builtInPrompt,
  required String customInstructions,
  required AgentSystemPromptMode mode,
}) {
  final builtIn = builtInPrompt.trim();
  final custom = customInstructions.trim();
  if (mode == AgentSystemPromptMode.override) return custom;
  if (custom.isEmpty) return builtIn;
  return [
    builtIn,
    '',
    '<user_behavior_instructions>',
    custom,
    '</user_behavior_instructions>',
  ].join('\n');
}
