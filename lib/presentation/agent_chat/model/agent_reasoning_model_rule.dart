import '../../../core/agent/agent_types.dart';
import '../../prompt_assistant/models/agent_protocol.dart';

/// Pi model-registry reasoning metadata distilled from the installed pi-ai
/// package. Missing map entries use the API's default level name; explicit null
/// entries disable that level.
class AgentReasoningModelRule {
  const AgentReasoningModelRule({
    required this.api,
    required this.levels,
    required this.contextWindow,
    required this.maxOutputTokens,
    this.levelMap = const {},
    this.supportsReasoningEffort = true,
    this.requiresReasoningContent = false,
    this.allowEmptySignature = false,
    this.alwaysIncludeEncryptedReasoning = false,
    this.thinkingBudgets = const {},
    this.disabledEffort,
  });

  final AgentReasoningApi api;
  final List<ThinkingLevel> levels;
  final Map<ThinkingLevel, String?> levelMap;
  final bool supportsReasoningEffort;
  final bool requiresReasoningContent;
  final bool allowEmptySignature;
  final bool alwaysIncludeEncryptedReasoning;
  final Map<ThinkingLevel, int> thinkingBudgets;
  final String? disabledEffort;
  final int contextWindow;
  final int maxOutputTokens;

  bool explicitlyDisables(ThinkingLevel level) =>
      levelMap.containsKey(level) && levelMap[level] == null;

  String mappedLevel(ThinkingLevel level) => levelMap[level] ?? level.name;
}
