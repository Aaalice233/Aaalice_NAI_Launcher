import '../../../core/agent/agent_types.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';

/// Verified chat-model capabilities used by the Agent runtime and UI.
///
/// Unknown models intentionally stay at a zero context window with no effort
/// selector. That is safer than inferring contracts from a provider endpoint,
/// where compatible servers can expose models with unrelated limits.
class AgentChatModelCapability {
  const AgentChatModelCapability({required this.model, required this.levels});

  final Model model;
  final List<ThinkingLevel> levels;

  static const unavailable = AgentChatModelCapability(
    model: Model(id: '', name: '', api: '', provider: ''),
    levels: [],
  );

  static AgentChatModelCapability resolve(
    ProviderConfig provider,
    String modelId,
  ) {
    final normalized = modelId.toLowerCase();
    var contextWindow = 0;
    var levels = const <ThinkingLevel>[];
    if (provider.preset == ProviderPreset.anthropic &&
        normalized.startsWith('claude-')) {
      contextWindow = 200000;
      if (normalized.contains('3-7') ||
          RegExp(r'claude-(opus|sonnet|haiku)-4').hasMatch(normalized)) {
        levels = const [
          ThinkingLevel.off,
          ThinkingLevel.minimal,
          ThinkingLevel.low,
          ThinkingLevel.medium,
          ThinkingLevel.high,
        ];
      }
    } else if (provider.preset == ProviderPreset.deepseek &&
        (normalized == 'deepseek-chat' || normalized == 'deepseek-reasoner')) {
      contextWindow = 128000;
      levels = normalized == 'deepseek-reasoner'
          ? const [ThinkingLevel.high]
          : const [ThinkingLevel.off, ThinkingLevel.high];
    } else if ((provider.preset == ProviderPreset.openaiResponses ||
            provider.preset == ProviderPreset.openaiCompatibleResponses) &&
        (normalized.startsWith('gpt-5') ||
            RegExp(r'^o[134](?:-|$)').hasMatch(normalized))) {
      contextWindow = normalized.startsWith('gpt-5') ? 400000 : 200000;
      levels = normalized.startsWith('gpt-5')
          ? const [
              ThinkingLevel.minimal,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
            ]
          : const [ThinkingLevel.low, ThinkingLevel.medium, ThinkingLevel.high];
    } else if (provider.preset == ProviderPreset.openaiChat &&
        normalized.startsWith('gpt-4.1')) {
      contextWindow = 1047576;
    } else if (provider.preset == ProviderPreset.gemini &&
        normalized.startsWith('gemini-2.5')) {
      contextWindow = 1048576;
    }
    return AgentChatModelCapability(
      model: Model(
        id: modelId,
        name: modelId,
        api: provider.protocol.name,
        provider: provider.id,
        baseUrl: provider.baseUrl,
        contextWindow: contextWindow,
        reasoning: levels.isNotEmpty,
      ),
      levels: levels,
    );
  }
}
