import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/model/agent_reasoning_model_rule.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_model_capability.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  group('Pi reasoning capability matrix', () {
    final cases =
        <
          ({
            String provider,
            ProviderProtocol protocol,
            String baseUrl,
            String model,
            List<ThinkingLevel> levels,
          })
        >[
          (
            provider: 'openai',
            protocol: ProviderProtocol.openaiResponses,
            baseUrl: 'https://api.openai.com/v1',
            model: 'gpt-5.2',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
              ThinkingLevel.xhigh,
            ],
          ),
          (
            provider: 'anthropic',
            protocol: ProviderProtocol.anthropicMessages,
            baseUrl: 'https://api.anthropic.com',
            model: 'claude-opus-4-8',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.minimal,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
              ThinkingLevel.xhigh,
              ThinkingLevel.max,
            ],
          ),
          (
            provider: 'google',
            protocol: ProviderProtocol.geminiGenerateContent,
            baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
            model: 'gemini-3.1-pro-preview',
            levels: const [ThinkingLevel.low, ThinkingLevel.high],
          ),
          (
            provider: 'deepseek',
            protocol: ProviderProtocol.openaiChatCompletions,
            baseUrl: 'https://api.deepseek.com',
            model: 'deepseek-v4-flash',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.low,
              ThinkingLevel.high,
              ThinkingLevel.max,
            ],
          ),
          (
            provider: 'openrouter',
            protocol: ProviderProtocol.openaiChatCompletions,
            baseUrl: 'https://openrouter.ai/api/v1',
            model: 'openai/gpt-5.2',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
              ThinkingLevel.xhigh,
            ],
          ),
          (
            provider: 'xai',
            protocol: ProviderProtocol.openaiResponses,
            baseUrl: 'https://api.x.ai/v1',
            model: 'grok-4.6',
            levels: const [
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
              ThinkingLevel.xhigh,
            ],
          ),
          (
            provider: 'mistral',
            protocol: ProviderProtocol.openaiChatCompletions,
            baseUrl: 'https://api.mistral.ai',
            model: 'magistral-medium-latest',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.minimal,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
            ],
          ),
          (
            provider: 'groq',
            protocol: ProviderProtocol.openaiChatCompletions,
            baseUrl: 'https://api.groq.com/openai/v1',
            model: 'openai/gpt-oss-120b',
            levels: const [
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
            ],
          ),
          (
            provider: 'cerebras',
            protocol: ProviderProtocol.openaiChatCompletions,
            baseUrl: 'https://api.cerebras.ai/v1',
            model: 'gemma-4-31b',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
            ],
          ),
          (
            provider: 'minimax',
            protocol: ProviderProtocol.anthropicMessages,
            baseUrl: 'https://api.minimax.io/anthropic',
            model: 'MiniMax-M3',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.minimal,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
            ],
          ),
          (
            provider: 'moonshotai',
            protocol: ProviderProtocol.openaiChatCompletions,
            baseUrl: 'https://api.moonshot.ai/v1',
            model: 'kimi-k3',
            levels: const [
              ThinkingLevel.low,
              ThinkingLevel.high,
              ThinkingLevel.max,
            ],
          ),
          (
            provider: 'qwen-token-plan',
            protocol: ProviderProtocol.openaiChatCompletions,
            baseUrl:
                'https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1',
            model: 'qwen3.8-max',
            levels: const [
              ThinkingLevel.off,
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.xhigh,
            ],
          ),
        ];

    for (final entry in cases) {
      test('${entry.provider}/${entry.model}', () {
        final capability = AgentChatModelCapability.resolve(
          ProviderConfig(
            id: entry.provider,
            name: entry.provider,
            protocol: entry.protocol,
            baseUrl: entry.baseUrl,
          ),
          entry.model,
        );

        expect(capability.levels, entry.levels);
        expect(capability.model.reasoning, isTrue);
        expect(capability.model.contextWindow, greaterThan(0));
      });
    }
  });

  test('named presets keep Pi semantics behind custom base URLs', () {
    final cases = <(ProviderPreset, String)>[
      (ProviderPreset.openRouter, 'openai/gpt-5.2'),
      (ProviderPreset.xai, 'grok-4.6'),
      (ProviderPreset.mistral, 'magistral-medium-latest'),
      (ProviderPreset.groq, 'openai/gpt-oss-120b'),
      (ProviderPreset.cerebras, 'gemma-4-31b'),
      (ProviderPreset.minimax, 'MiniMax-M3'),
      (ProviderPreset.minimaxCn, 'MiniMax-M3'),
      (ProviderPreset.kimiCoding, 'kimi-for-coding'),
      (ProviderPreset.moonshot, 'kimi-k3'),
      (ProviderPreset.moonshotCn, 'kimi-k3'),
      (ProviderPreset.qwenTokenPlan, 'qwen3.8-max'),
      (ProviderPreset.qwenTokenPlanCn, 'qwen3.8-max'),
      (ProviderPreset.qwenTokenPlanIndividual, 'qwen3.8-max'),
    ];

    for (final entry in cases) {
      final provider = entry.$1.createConfig().copyWith(
        baseUrl: 'https://proxy.example/v1',
      );
      expect(
        AgentChatModelCapability.resolve(provider, entry.$2).levels,
        isNotEmpty,
        reason: entry.$1.name,
      );
    }
  });

  test('preserves Pi aliases even when native requests are equal', () {
    final deepSeek = AgentChatModelCapability.resolve(
      const ProviderConfig(
        id: 'deepseek',
        name: 'DeepSeek',
        protocol: ProviderProtocol.openaiChatCompletions,
        baseUrl: 'https://api.deepseek.com',
        preset: ProviderPreset.deepseek,
      ),
      'deepseek-v4-flash',
    );
    final mistral = AgentChatModelCapability.resolve(
      const ProviderConfig(
        id: 'mistral',
        name: 'Mistral',
        protocol: ProviderProtocol.openaiChatCompletions,
        baseUrl: 'https://api.mistral.ai',
      ),
      'magistral-small',
    );

    expect(deepSeek.levels, [
      ThinkingLevel.off,
      ThinkingLevel.low,
      ThinkingLevel.high,
      ThinkingLevel.max,
    ]);
    expect(mistral.levels, [
      ThinkingLevel.off,
      ThinkingLevel.minimal,
      ThinkingLevel.low,
      ThinkingLevel.medium,
      ThinkingLevel.high,
    ]);
    expect(
      deepSeek.resolveReasoningRequest('high'),
      isA<AgentReasoningRequest>()
          .having((request) => request.api, 'api', AgentReasoningApi.deepSeek)
          .having((request) => request.effort, 'effort', isNull),
    );
  });

  test('uses Pi model-specific Gemini thinking budgets', () {
    final provider = ProviderPreset.gemini.createConfig(id: 'google');

    expect(
      AgentChatModelCapability.resolve(
        provider,
        'gemini-2.5-pro',
      ).resolveReasoningRequest('high')?.budgetTokens,
      32768,
    );
    expect(
      AgentChatModelCapability.resolve(
        provider,
        'gemini-2.5-flash',
      ).resolveReasoningRequest('high')?.budgetTokens,
      24576,
    );
    expect(
      AgentChatModelCapability.resolve(
        provider,
        'gemini-2.5-flash-lite',
      ).resolveReasoningRequest('minimal')?.budgetTokens,
      512,
    );
  });

  test('Gemini 3 missing reasoning uses its supported hidden minimum', () {
    final provider = ProviderPreset.gemini.createConfig(id: 'google');
    final proCapability = AgentChatModelCapability.resolve(
      provider,
      'gemini-3.1-pro-preview',
    );
    final flashCapability = AgentChatModelCapability.resolve(
      provider,
      'gemini-3.7-flash',
    );

    final proRequest = proCapability.resolveReasoningRequest(null);
    final flashRequest = flashCapability.resolveReasoningRequest(null);

    expect(proRequest?.enabled, isFalse);
    expect(proRequest?.sendWhenDisabled, isTrue);
    expect(proRequest?.effort, 'LOW');
    expect(flashCapability.levels, [
      ThinkingLevel.low,
      ThinkingLevel.medium,
      ThinkingLevel.high,
    ]);
    expect(flashRequest?.enabled, isFalse);
    expect(flashRequest?.sendWhenDisabled, isTrue);
    expect(flashRequest?.effort, 'LOW');
    expect(flashCapability.resolveReasoningRequest('minimal')?.effort, 'LOW');
  });

  test('omits missing reasoning on models whose off mapping is null', () {
    final capability = AgentChatModelCapability.resolve(
      ProviderPreset.openaiResponses.createConfig(id: 'openai'),
      'gpt-5',
    );

    final request = capability.resolveReasoningRequest(null);

    expect(request?.enabled, isFalse);
    expect(request?.sendWhenDisabled, isFalse);
    expect(request?.effort, isNull);
  });

  test('Mistral effort keeps model-specific level mappings', () {
    const metadata = AgentChatModelMetadata(
      contextWindow: 1,
      maxOutputTokens: 1,
      thinkingLevels: [ThinkingLevel.off, ThinkingLevel.low],
      reasoningRule: AgentReasoningModelRule(
        api: AgentReasoningApi.mistralEffort,
        levels: [ThinkingLevel.off, ThinkingLevel.low],
        levelMap: {ThinkingLevel.low: 'custom-low'},
        contextWindow: 1,
        maxOutputTokens: 1,
      ),
    );

    expect(metadata.resolveReasoningRequest('low')?.effort, 'custom-low');
  });

  test('keeps unknown custom endpoints explicitly unavailable', () {
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

  group('unrecognised gateways fall back to the model name', () {
    const relay = ProviderConfig(
      id: 'relay',
      name: 'Relay station',
      protocol: ProviderProtocol.openaiChatCompletions,
      baseUrl: 'https://api.my-relay.test/v1',
      preset: ProviderPreset.openaiCompatibleChat,
    );

    test('borrows the window for a transparently proxied model', () {
      final capability = AgentChatModelCapability.resolve(
        relay,
        'kimi-k2-thinking',
      );

      expect(capability.model.contextWindow, 262144);
    });

    test('matches case-insensitively like the exact tier does', () {
      expect(
        AgentChatModelCapability.resolve(
          relay,
          'Kimi-K2-Thinking',
        ).model.contextWindow,
        262144,
      );
    });

    test('takes the smallest window when providers disagree', () {
      // qwen/qwen3.6-27b is 262144 on openrouter and 131072 on groq.
      // Underestimating only compacts early; overestimating overflows.
      expect(
        AgentChatModelCapability.resolve(
          relay,
          'qwen/qwen3.6-27b',
        ).model.contextWindow,
        131072,
      );
    });

    test(
      'borrows the window but not the reasoning config across protocols',
      () {
        final capability = AgentChatModelCapability.resolve(
          relay,
          'claude-opus-4-8',
        );

        expect(capability.model.contextWindow, greaterThan(0));
        expect(capability.levels, isEmpty);
        expect(capability.model.reasoning, isFalse);
      },
    );

    test('stays unavailable when the name is not in the catalog', () {
      expect(
        AgentChatModelCapability.resolve(
          relay,
          'private-v9',
        ).model.contextWindow,
        0,
      );
    });

    test('a manual window rescues a model the catalog cannot place', () {
      final capability = AgentChatModelCapability.resolve(
        relay,
        'private-v9',
        contextWindowOverride: 65536,
      );

      expect(capability.model.contextWindow, 65536);
    });

    test('a manual window outranks the catalog', () {
      final capability = AgentChatModelCapability.resolve(
        relay,
        'kimi-k2-thinking',
        contextWindowOverride: 32000,
      );

      expect(capability.model.contextWindow, 32000);
    });
  });

  test(
    'rejects a catalog model when the configured protocol is incompatible',
    () {
      final capability = AgentChatModelCapability.resolve(
        const ProviderConfig(
          id: 'anthropic',
          name: 'Anthropic through wrong protocol',
          protocol: ProviderProtocol.openaiChatCompletions,
          baseUrl: 'https://api.anthropic.com',
        ),
        'claude-opus-4-8',
      );

      expect(capability.levels, isEmpty);
    },
  );
}
