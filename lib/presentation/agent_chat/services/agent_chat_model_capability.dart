import '../../../core/agent/agent_types.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';

/// Verified metadata used consistently by the Agent runtime, compaction and UI.
class AgentChatModelMetadata {
  const AgentChatModelMetadata({
    required this.contextWindow,
    this.maxOutputTokens = 0,
    this.thinkingLevels = const [],
  });

  final int contextWindow;
  final int maxOutputTokens;
  final List<ThinkingLevel> thinkingLevels;

  bool get reasoning => thinkingLevels.isNotEmpty;
}

/// Catalog of model contracts verified for the provider presets shipped by the
/// app. Unknown IDs intentionally do not inherit limits from their endpoint.
class AgentChatModelCatalog {
  const AgentChatModelCatalog._();

  static const unknown = AgentChatModelMetadata(contextWindow: 0);

  static AgentChatModelMetadata resolve(
    ProviderPreset? preset,
    String modelId,
  ) {
    final id = modelId.trim().toLowerCase();

    if (preset == ProviderPreset.deepseek) {
      switch (id) {
        case 'deepseek-v4-flash':
        case 'deepseek-v4-pro':
        case 'deepseek-v4-flash-vision-exp':
          return const AgentChatModelMetadata(
            contextWindow: 1000000,
            maxOutputTokens: 384000,
            thinkingLevels: [ThinkingLevel.off, ThinkingLevel.high],
          );
        case 'deepseek-chat':
          return const AgentChatModelMetadata(
            contextWindow: 128000,
            thinkingLevels: [ThinkingLevel.off, ThinkingLevel.high],
          );
        case 'deepseek-reasoner':
          return const AgentChatModelMetadata(
            contextWindow: 128000,
            thinkingLevels: [ThinkingLevel.high],
          );
      }
      return unknown;
    }

    if (preset == ProviderPreset.anthropic && id.startsWith('claude-')) {
      final supportsThinking =
          id.contains('3-7') ||
          RegExp(r'claude-(opus|sonnet|haiku)-4').hasMatch(id);
      return AgentChatModelMetadata(
        contextWindow: 200000,
        thinkingLevels: supportsThinking
            ? const [
                ThinkingLevel.off,
                ThinkingLevel.minimal,
                ThinkingLevel.low,
                ThinkingLevel.medium,
                ThinkingLevel.high,
              ]
            : const [],
      );
    }

    if ((preset == ProviderPreset.openaiResponses ||
            preset == ProviderPreset.openaiCompatibleResponses) &&
        (id.startsWith('gpt-5') || RegExp(r'^o[134](?:-|$)').hasMatch(id))) {
      return AgentChatModelMetadata(
        contextWindow: id.startsWith('gpt-5') ? 400000 : 200000,
        thinkingLevels: id.startsWith('gpt-5')
            ? const [
                ThinkingLevel.minimal,
                ThinkingLevel.low,
                ThinkingLevel.medium,
                ThinkingLevel.high,
              ]
            : const [
                ThinkingLevel.low,
                ThinkingLevel.medium,
                ThinkingLevel.high,
              ],
      );
    }

    if (preset == ProviderPreset.openaiChat && id.startsWith('gpt-4.1')) {
      return const AgentChatModelMetadata(contextWindow: 1047576);
    }
    if (preset == ProviderPreset.gemini && id.startsWith('gemini-2.5')) {
      return const AgentChatModelMetadata(contextWindow: 1048576);
    }
    return unknown;
  }
}

class AgentChatModelCapability {
  const AgentChatModelCapability({
    required this.model,
    required this.levels,
    required this.metadata,
  });

  final Model model;
  final List<ThinkingLevel> levels;
  final AgentChatModelMetadata metadata;

  static const unavailable = AgentChatModelCapability(
    model: Model(id: '', name: '', api: '', provider: ''),
    levels: [],
    metadata: AgentChatModelCatalog.unknown,
  );

  static AgentChatModelCapability resolve(
    ProviderConfig provider,
    String modelId,
  ) {
    final metadata = AgentChatModelCatalog.resolve(provider.preset, modelId);
    return AgentChatModelCapability(
      model: Model(
        id: modelId,
        name: modelId,
        api: provider.protocol.name,
        provider: provider.id,
        baseUrl: provider.baseUrl,
        contextWindow: metadata.contextWindow,
        maxTokens: metadata.maxOutputTokens,
        reasoning: metadata.reasoning,
      ),
      levels: metadata.thinkingLevels,
      metadata: metadata,
    );
  }
}
