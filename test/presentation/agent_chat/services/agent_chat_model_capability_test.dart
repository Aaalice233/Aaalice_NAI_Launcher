import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_model_capability.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  test('exposes verified Claude context and reasoning levels', () {
    const provider = ProviderConfig(
      id: 'anthropic',
      name: 'Anthropic',
      protocol: ProviderProtocol.anthropicMessages,
      baseUrl: 'https://api.anthropic.com',
      preset: ProviderPreset.anthropic,
    );

    final capability = AgentChatModelCapability.resolve(
      provider,
      'claude-sonnet-4-20250514',
    );

    expect(capability.model.contextWindow, 200000);
    expect(capability.model.reasoning, isTrue);
    expect(
      capability.levels,
      containsAll([ThinkingLevel.off, ThinkingLevel.high]),
    );
  });

  test('keeps unknown compatible models explicitly unavailable', () {
    const provider = ProviderConfig(
      id: 'custom',
      name: 'Custom',
      protocol: ProviderProtocol.openaiChatCompletions,
      baseUrl: 'https://example.test',
      preset: ProviderPreset.openaiCompatibleChat,
    );

    final capability = AgentChatModelCapability.resolve(provider, 'private-v9');

    expect(capability.model.contextWindow, 0);
    expect(capability.model.reasoning, isFalse);
    expect(capability.levels, isEmpty);
  });

  test('mandatory reasoning models do not advertise a false off mode', () {
    const deepSeek = ProviderConfig(
      id: 'deepseek',
      name: 'DeepSeek',
      protocol: ProviderProtocol.openaiChatCompletions,
      baseUrl: 'https://api.deepseek.com',
      preset: ProviderPreset.deepseek,
    );
    const openAi = ProviderConfig(
      id: 'openai',
      name: 'OpenAI',
      protocol: ProviderProtocol.openaiResponses,
      baseUrl: 'https://api.openai.com/v1',
      preset: ProviderPreset.openaiResponses,
    );

    expect(
      AgentChatModelCapability.resolve(deepSeek, 'deepseek-reasoner').levels,
      isNot(contains(ThinkingLevel.off)),
    );
    expect(
      AgentChatModelCapability.resolve(openAi, 'gpt-5').levels,
      isNot(contains(ThinkingLevel.off)),
    );
  });

  test('legacy o-series models do not advertise minimal effort', () {
    final capability = AgentChatModelCapability.resolve(
      const ProviderConfig(
        id: 'openai',
        name: 'OpenAI',
        protocol: ProviderProtocol.openaiResponses,
        preset: ProviderPreset.openaiResponses,
        baseUrl: 'https://api.openai.com/v1',
      ),
      'o1',
    );

    expect(capability.levels, const [
      ThinkingLevel.low,
      ThinkingLevel.medium,
      ThinkingLevel.high,
    ]);
  });
}
