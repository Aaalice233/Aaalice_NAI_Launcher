import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  test(
    'Pi provider presets keep current endpoints, protocols, and defaults',
    () {
      final expected = <ProviderPreset, (String, ProviderProtocol, String)>{
        ProviderPreset.openRouter: (
          'https://openrouter.ai/api/v1',
          ProviderProtocol.openaiChatCompletions,
          'moonshotai/kimi-k2.6',
        ),
        ProviderPreset.xai: (
          'https://api.x.ai/v1',
          ProviderProtocol.openaiResponses,
          'grok-4.6',
        ),
        ProviderPreset.mistral: (
          'https://api.mistral.ai',
          ProviderProtocol.openaiChatCompletions,
          'devstral-medium-latest',
        ),
        ProviderPreset.groq: (
          'https://api.groq.com/openai/v1',
          ProviderProtocol.openaiChatCompletions,
          'openai/gpt-oss-120b',
        ),
        ProviderPreset.cerebras: (
          'https://api.cerebras.ai/v1',
          ProviderProtocol.openaiChatCompletions,
          'gpt-oss-120b',
        ),
        ProviderPreset.minimax: (
          'https://api.minimax.io/anthropic',
          ProviderProtocol.anthropicMessages,
          'MiniMax-M2.7',
        ),
        ProviderPreset.minimaxCn: (
          'https://api.minimaxi.com/anthropic',
          ProviderProtocol.anthropicMessages,
          'MiniMax-M2.7',
        ),
        ProviderPreset.kimiCoding: (
          'https://api.kimi.com/coding',
          ProviderProtocol.anthropicMessages,
          'kimi-for-coding',
        ),
        ProviderPreset.moonshot: (
          'https://api.moonshot.ai/v1',
          ProviderProtocol.openaiChatCompletions,
          'kimi-k2.6',
        ),
        ProviderPreset.moonshotCn: (
          'https://api.moonshot.cn/v1',
          ProviderProtocol.openaiChatCompletions,
          'kimi-k2.6',
        ),
        ProviderPreset.qwenTokenPlan: (
          'https://token-plan.ap-southeast-1.maas.aliyuncs.com/'
              'compatible-mode/v1',
          ProviderProtocol.openaiChatCompletions,
          'qwen3.7-max',
        ),
        ProviderPreset.qwenTokenPlanCn: (
          'https://token-plan.cn-beijing.maas.aliyuncs.com/'
              'compatible-mode/v1',
          ProviderProtocol.openaiChatCompletions,
          'qwen3.7-max',
        ),
        ProviderPreset.qwenTokenPlanIndividual: (
          'https://token-plan.ap-southeast-1.maas.aliyuncs.com/'
              'compatible-mode/v1',
          ProviderProtocol.openaiChatCompletions,
          'qwen3.8-max',
        ),
      };

      for (final entry in expected.entries) {
        expect(entry.key.defaultBaseUrl, entry.value.$1);
        expect(entry.key.defaultProtocol, entry.value.$2);
        expect(entry.key.defaultModelNames, [entry.value.$3]);
      }
      expect(ProviderPreset.deepseek.defaultModelNames, ['deepseek-v4-pro']);
      expect(ProviderPreset.openaiResponses.defaultModelNames, ['gpt-5.5']);
      expect(ProviderPreset.anthropic.defaultModelNames, ['claude-opus-4-8']);
      expect(ProviderPreset.gemini.defaultModelNames, [
        'gemini-3.1-pro-preview',
      ]);
    },
  );

  group('Agent chat isolation', () {
    test('defaults and default merge do not recreate chat rules', () {
      final defaults = PromptAssistantConfigState.defaults();
      final decoded = PromptAssistantConfigState.decode(
        '{"schemaVersion":2,"rules":[],"routing":{}}',
      );

      expect(
        defaults.rules.where((rule) => rule.taskType == AssistantTaskType.chat),
        isEmpty,
      );
      expect(
        decoded.rules.where((rule) => rule.taskType == AssistantTaskType.chat),
        isEmpty,
      );
    });

    test('normal decode does not fall back chat routing to llm', () {
      final raw = jsonEncode({
        'schemaVersion': 2,
        'providers': [
          const ProviderConfig(
            id: 'provider-a',
            name: 'Provider A',
            baseUrl: 'https://example.test',
          ).toJson(),
        ],
        'models': [
          const ModelConfig(
            providerId: 'provider-a',
            name: 'model-a',
            displayName: 'Model A',
            forTask: AssistantTaskType.llm,
          ).toJson(),
        ],
        'routing': {'llmProviderId': 'provider-a', 'llmModel': 'model-a'},
      });

      final decoded = PromptAssistantConfigState.decode(raw);
      final migration = PromptAssistantConfigState.decode(
        raw,
        migrateLegacyChatRouting: true,
      );

      expect(decoded.routing.chatProviderId, isEmpty);
      expect(decoded.routing.chatModel, isEmpty);
      expect(migration.routing.chatProviderId, 'provider-a');
      expect(migration.routing.chatModel, 'model-a');
    });
  });

  group('AgentPermissionMode persistence', () {
    for (final mode in AgentPermissionMode.values) {
      test('round-trips ${mode.name}', () {
        final encoded = PromptAssistantConfigState.defaults()
            .copyWith(agentPermissionMode: mode)
            .encode();

        final decoded = PromptAssistantConfigState.decode(encoded);

        expect(decoded.agentPermissionMode, mode);
      });
    }

    test('defaults missing or unknown values to confirmation mode', () {
      expect(
        AgentPermissionMode.fromName(null),
        AgentPermissionMode.askBeforeSensitiveActions,
      );
      expect(
        AgentPermissionMode.fromName('future-mode'),
        AgentPermissionMode.askBeforeSensitiveActions,
      );
    });
  });
}
