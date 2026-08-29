import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  test('DeepSeek preset keeps official v4 model IDs', () {
    expect(ProviderPreset.deepseek.defaultModelNames, const [
      'deepseek-v4-flash',
      'deepseek-v4-pro',
    ]);
  });

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
