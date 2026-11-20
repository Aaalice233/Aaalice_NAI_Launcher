import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_reasoning_model_rule.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_model_capability.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';

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
            levels: const [
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
            ],
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
            model: 'google/gemini-3.8-flash',
            levels: const [
              ThinkingLevel.low,
              ThinkingLevel.medium,
              ThinkingLevel.high,
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
            model: 'qwen-3.8-27b',
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

        expect(capability.metadata.thinkingLevels, entry.levels);
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
      (ProviderPreset.cerebras, 'qwen-3.8-27b'),
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
        AgentChatModelCapability.resolve(
          provider,
          entry.$2,
        ).metadata.thinkingLevels,
        isNotEmpty,
        reason: entry.$1.name,
      );
    }
  });

  test('the deepseek-chat alias preserves reasoning when high is selected', () {
    final capability = AgentChatModelCapability.resolve(
      ProviderPreset.deepseek.createConfig(),
      'deepseek-chat',
    );

    expect(
      capability.resolveReasoningRequest('high')?.preserveReasoningContent,
      isTrue,
    );
  });

  test('maps DeepSeek effort and preserves Mistral level aliases', () {
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
      'magistral-medium-latest',
    );

    expect(deepSeek.metadata.thinkingLevels, [
      ThinkingLevel.off,
      ThinkingLevel.low,
      ThinkingLevel.high,
      ThinkingLevel.max,
    ]);
    expect(mistral.metadata.thinkingLevels, [
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
          .having((request) => request.effort, 'effort', 'high'),
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

  test('Gemini 3 uses the hidden minimum only for explicit off', () {
    final provider = ProviderPreset.gemini.createConfig(id: 'google');
    final proCapability = AgentChatModelCapability.resolve(
      provider,
      'gemini-3.1-pro-preview',
    );
    final flashCapability = AgentChatModelCapability.resolve(
      provider,
      'gemini-3.8-flash',
    );

    for (final capability in [proCapability, flashCapability]) {
      final modelDefault = capability.resolveReasoningRequest(null)!;
      expect(modelDefault.enabled, isNull);
      expect(modelDefault.effort, isNull);
      expect(modelDefault.sendWhenDisabled, isFalse);
    }
    final proRequest = proCapability.resolveReasoningRequest('off');
    final flashRequest = flashCapability.resolveReasoningRequest('off');

    expect(proRequest?.enabled, isFalse);
    expect(proRequest?.sendWhenDisabled, isTrue);
    expect(proRequest?.effort, 'LOW');
    expect(flashCapability.metadata.thinkingLevels, [
      ThinkingLevel.low,
      ThinkingLevel.medium,
      ThinkingLevel.high,
    ]);
    expect(flashRequest?.enabled, isFalse);
    expect(flashRequest?.sendWhenDisabled, isTrue);
    expect(flashRequest?.effort, 'LOW');
    expect(flashCapability.resolveReasoningRequest('minimal')?.effort, 'LOW');
  });

  test('OpenRouter Gemini 3.8 uses native reasoning levels', () {
    final capability = AgentChatModelCapability.resolve(
      ProviderPreset.openRouter.createConfig(id: 'openrouter'),
      'google/gemini-3.8-flash',
    );

    expect(capability.model.contextWindow, 1048576);
    expect(capability.model.maxTokens, 65536);
    expect(capability.metadata.thinkingLevels, [
      ThinkingLevel.low,
      ThinkingLevel.medium,
      ThinkingLevel.high,
    ]);
    expect(
      capability.resolveReasoningRequest('low')?.api,
      AgentReasoningApi.openRouter,
    );
    expect(capability.resolveReasoningRequest('low')?.effort, 'low');
    expect(capability.resolveReasoningRequest('high')?.effort, 'high');
  });

  test('omits explicit off on models whose off mapping is null', () {
    final capability = AgentChatModelCapability.resolve(
      ProviderPreset.openaiResponses.createConfig(id: 'openai'),
      'gpt-5',
    );

    final request = capability.resolveReasoningRequest('off');

    expect(request?.enabled, isFalse);
    expect(request?.sendWhenDisabled, isFalse);
    expect(request?.effort, isNull);
  });

  test('Mistral effort keeps model-specific level mappings', () {
    const metadata = AssistantModelMetadata(
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

  test(
    'unknown compatible models offer direct selection without sending an undeclared effort',
    () {
      const provider = ProviderConfig(
        id: 'custom',
        name: 'Custom',
        protocol: ProviderProtocol.openaiChatCompletions,
        baseUrl: 'https://example.test',
        preset: ProviderPreset.openaiCompatibleChat,
      );

      final capability = AgentChatModelCapability.resolve(
        provider,
        'private-v9',
      );

      expect(capability.model.contextWindow, 0);
      expect(capability.model.reasoning, isFalse);
      expect(capability.metadata.thinkingLevels, isEmpty);
      expect(capability.metadata.quickFormat, ModelReasoningFormat.chatEffort);
      expect(capability.metadata.chatThinkingLevels, [
        null,
        ThinkingLevel.low,
        ThinkingLevel.medium,
        ThinkingLevel.high,
      ]);
      expect(capability.resolveReasoningRequest('high'), isNull);
      for (final id in ['', 'default-model']) {
        expect(
          AgentChatModelCapability.resolve(provider, id).metadata.configurable,
          isFalse,
        );
      }
    },
  );

  test(
    'native formats are explicit and declarations cannot override catalog or protocol restrictions',
    () {
      const id = 'gemini-carbon';
      final native = ProviderPreset.gemini.createConfig();
      AssistantModelMetadata forFormat(ModelReasoningFormat? format) =>
          AssistantModelCatalog.resolveProvider(
            provider: native.copyWith(
              modelReasoningFormats: {if (format != null) id: format},
            ),
            model: id,
          );
      expect(forFormat(null).chatThinkingLevels, [null]);
      expect(
        forFormat(
          ModelReasoningFormat.chatEffort,
        ).resolveReasoningRequest('high'),
        isNull,
      );
      final autoBudget = forFormat(ModelReasoningFormat.geminiBudget);
      expect(autoBudget.chatThinkingLevels, [null, ThinkingLevel.high]);
      expect(autoBudget.thinkingIsToggle, isTrue);
      final relay = ProviderPreset.openaiCompatibleChat.createConfig();
      for (final (name, match) in [
        ('gpt-4o', AssistantModelCatalogMatch.nonReasoning),
        ('gemini-2.5-pro', AssistantModelCatalogMatch.incompatibleProtocol),
        ('gpt-5', AssistantModelCatalogMatch.reasoning),
      ]) {
        final metadata = AssistantModelCatalog.resolveProvider(
          provider: relay.copyWith(
            modelReasoningFormats: {name: ModelReasoningFormat.chatEffort},
          ),
          model: name,
        );
        expect(metadata.catalogMatch, match);
        expect(metadata.configurable, isFalse);
        if (match != AssistantModelCatalogMatch.reasoning) {
          expect(metadata.resolveReasoningRequest('high'), isNull);
        }
      }
    },
  );

  test('OpenAI Chat only reserves exact GPT-4.1 catalog IDs on relays', () {
    final relay = ProviderPreset.openaiChat.createConfig().copyWith(
      baseUrl: 'https://relay.example/v1',
    );
    for (final base in ['gpt-4.1', 'gpt-4.1-mini', 'gpt-4.1-nano']) {
      for (final id in [base, '$base-2025-04-14']) {
        final known = AssistantModelCatalog.resolveProvider(
          provider: relay,
          model: id,
        );
        expect(
          known.catalogMatch,
          AssistantModelCatalogMatch.nonReasoning,
          reason: id,
        );
        expect(known.contextWindow, 1047576);
        expect(known.offeredThinkingLevels, isEmpty);
      }
    }
    const id = 'gpt-4.1-private-thinking';
    final private = AssistantModelCatalog.resolveProvider(
      provider: relay,
      model: id,
    );
    expect(private.quickFormat, ModelReasoningFormat.chatEffort);
    expect(private.offeredThinkingLevels, [
      ThinkingLevel.low,
      ThinkingLevel.medium,
      ThinkingLevel.high,
    ]);
    expect(private.chatThinkingLevels, [
      null,
      ...private.offeredThinkingLevels,
    ]);
    final declared = AssistantModelCatalog.resolveProvider(
      provider: relay.copyWith(
        modelReasoningFormats: {id: ModelReasoningFormat.chatEffort},
      ),
      model: id,
    );
    expect(declared.resolveReasoningRequest('high')?.effort, 'high');
  });

  group('unrecognised gateways fall back to the model name', () {
    const relay = ProviderConfig(
      id: 'relay',
      name: 'Relay station',
      protocol: ProviderProtocol.openaiChatCompletions,
      baseUrl: 'https://api.my-relay.test/v1',
      preset: ProviderPreset.openaiCompatibleChat,
    );

    const geminiRelay = ProviderConfig(
      id: 'gemini-relay',
      name: 'Gemini relay station',
      protocol: ProviderProtocol.geminiGenerateContent,
      baseUrl: 'https://relay.example.test/v1beta',
      preset: ProviderPreset.gemini,
    );

    test('keeps Gemini 3.8 reasoning semantics on a custom v1beta host', () {
      final capability = AgentChatModelCapability.resolve(
        geminiRelay,
        'gemini-3.8-flash',
      );

      expect(capability.model.contextWindow, 1048576);
      expect(capability.model.maxTokens, 65536);
      expect(capability.metadata.thinkingLevels, [
        ThinkingLevel.low,
        ThinkingLevel.medium,
        ThinkingLevel.high,
      ]);
      expect(
        capability.resolveReasoningRequest('low')?.api,
        AgentReasoningApi.geminiLevel,
      );
      expect(capability.resolveReasoningRequest('low')?.effort, 'LOW');
    });

    test('borrows the window for a transparently proxied model', () {
      final capability = AgentChatModelCapability.resolve(relay, 'kimi-k2.6');

      expect(capability.model.contextWindow, 262144);
    });

    test('matches case-insensitively like the exact tier does', () {
      expect(
        AgentChatModelCapability.resolve(
          relay,
          'Kimi-K2.6',
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
        expect(capability.metadata.thinkingLevels, isEmpty);
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

      expect(capability.metadata.thinkingLevels, isEmpty);
    },
  );
}
