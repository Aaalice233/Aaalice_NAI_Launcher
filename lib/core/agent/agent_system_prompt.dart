String composeAgentSystemPrompt({
  required String builtInPrompt,
  required String customInstructions,
}) {
  final builtIn = builtInPrompt.trim();
  final custom = customInstructions.trim();
  if (custom.isEmpty) return builtIn;
  return [
    builtIn,
    '',
    '<user_behavior_instructions>',
    custom,
    '</user_behavior_instructions>',
  ].join('\n');
}
