import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/data/models/prompt_assistant/vertex_target.dart';

void main() {
  test(
    'Pi provider presets keep current endpoints, protocols, and defaults',
    () {
      final expected = <ProviderPreset, (String, ProviderProtocol, String)>{
        ProviderPreset.openRouter: (
          'https://openrouter.ai/api/v1',
          ProviderProtocol.openaiChatCompletions,
          'moonshotai/kimi-k2.7-code',
        ),
        ProviderPreset.xai: (
          'https://api.x.ai/v1',
          ProviderProtocol.openaiResponses,
          'grok-4.7',
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
          'MiniMax-M3',
        ),
        ProviderPreset.minimaxCn: (
          'https://api.minimaxi.com/anthropic',
          ProviderProtocol.anthropicMessages,
          'MiniMax-M3',
        ),
        ProviderPreset.kimiCoding: (
          'https://api.kimi.com/coding/v1',
          ProviderProtocol.openaiChatCompletions,
          'kimi-for-coding',
        ),
        ProviderPreset.moonshot: (
          'https://api.moonshot.ai/v1',
          ProviderProtocol.openaiChatCompletions,
          'kimi-k2.7-code',
        ),
        ProviderPreset.moonshotCn: (
          'https://api.moonshot.cn/v1',
          ProviderProtocol.openaiChatCompletions,
          'kimi-k2.7-code',
        ),
        ProviderPreset.qwenTokenPlan: (
          'https://token-plan.maas.qwencloudapi.com/compatible-mode/v1',
          ProviderProtocol.openaiChatCompletions,
          'qwen3.8-max',
        ),
        ProviderPreset.qwenTokenPlanCn: (
          'https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1',
          ProviderProtocol.openaiChatCompletions,
          'qwen3.8-max',
        ),
        ProviderPreset.qwenTokenPlanIndividual: (
          'https://token-plan.maas.qwencloudapi.com/compatible-mode/v1',
          ProviderProtocol.openaiChatCompletions,
          'qwen3.8-max',
        ),
        ProviderPreset.qwenTokenPlanIndividualCn: (
          'https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1',
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
      expect(ProviderPreset.openaiResponses.defaultModelNames, ['gpt-6.2-sol']);
      expect(ProviderPreset.anthropic.defaultModelNames, ['claude-opus-5-5']);
      expect(ProviderPreset.gemini.defaultModelNames, ['gemini-4-argon']);
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
    test('only autopilot waives charges, and it keeps full access', () {
      expect(
        [
          for (final mode in AgentPermissionMode.values)
            if (mode.grantsFullAccess) mode,
        ],
        [AgentPermissionMode.fullAccess, AgentPermissionMode.autopilot],
      );
      expect(
        [
          for (final mode in AgentPermissionMode.values)
            if (mode.autoApprovesCharges) mode,
        ],
        [AgentPermissionMode.autopilot],
      );
    });

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

  group('Google Vertex AI', () {
    test('preset uses Gemini wire protocol and location-derived host', () {
      final config = ProviderPreset.googleVertex.createConfig();
      expect(config.id, 'google-vertex');
      expect(config.protocol, ProviderProtocol.geminiGenerateContent);
      expect(config.baseUrl, isEmpty);
      expect(config.isVertex, isTrue);
      expect(config.vertex, const VertexTarget());
      expect(config.vertexTarget.effectiveLocation, 'global');
      expect(ProviderPreset.googleVertex.requiresApiKey, isTrue);
      expect(ProviderPreset.googleVertex.defaultAllowImageInput, isTrue);
    });

    test('vertex target round-trips through JSON', () {
      final config = ProviderPreset.googleVertex.createConfig().copyWith(
        vertex: const VertexTarget(
          projectId: 'my-project',
          location: 'us-central1',
        ),
      );
      final decoded = ProviderConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.preset, ProviderPreset.googleVertex);
      expect(
        decoded.vertex,
        const VertexTarget(projectId: 'my-project', location: 'us-central1'),
      );
    });

    test('other providers do not persist a vertex key', () {
      final json = ProviderPreset.gemini.createConfig().toJson();
      expect(json.containsKey('vertex'), isFalse);
      expect(ProviderConfig.fromJson(json).vertex, isNull);
    });

    test('vertex preset without stored target decodes defaults', () {
      final json = ProviderPreset.googleVertex.createConfig().toJson()
        ..remove('vertex');
      expect(ProviderConfig.fromJson(json).vertex, const VertexTarget());
    });

    test('unknown preset from a newer client degrades without crashing', () {
      final json = ProviderPreset.googleVertex.createConfig().toJson()
        ..['preset'] = 'futureCloud';
      final decoded = ProviderConfig.fromJson(json);
      expect(decoded.isVertex, isFalse);
      expect(decoded.protocol, ProviderProtocol.geminiGenerateContent);
    });

    test('location validation only accepts region identifiers', () {
      for (final valid in ['global', 'us-central1', 'europe-west4']) {
        expect(VertexTarget.isValidLocation(valid), isTrue, reason: valid);
      }
      for (final invalid in ['', 'US', 'a.b', 'evil.com/x', '1abc']) {
        expect(VertexTarget.isValidLocation(invalid), isFalse, reason: invalid);
      }
    });
  });
}
