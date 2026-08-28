import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  group('AgentSettings', () {
    test('round-trips the versioned schema', () {
      const settings = AgentSettings(
        chat: AgentChatConfig(
          modelReference: AgentModelReference(
            providerId: 'openai',
            model: 'gpt-test',
          ),
          customSystemPrompt: 'Be concise.',
          permissionMode: AgentPermissionMode.safe,
          webAccessEnabled: false,
        ),
        disabledSkillIds: {'demo'},
      );

      final decoded = AgentSettings.decode(jsonEncode(settings.toJson()));
      expect(decoded.chat.modelReference, settings.chat.modelReference);
      expect(decoded.chat.customSystemPrompt, settings.chat.customSystemPrompt);
      expect(decoded.disabledSkillIds, settings.disabledSkillIds);
      expect(
        settings.toJson()['schemaVersion'],
        AgentSettings.currentSchemaVersion,
      );
    });

    test('rejects unsupported schemas and unknown fields', () {
      expect(
        () => AgentSettings.decode(
          jsonEncode(const {
            'schemaVersion': 99,
            'chat': <String, Object?>{},
            'disabledSkillIds': <String>[],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => AgentSettings.decode(
          jsonEncode(const {
            'schemaVersion': 2,
            'chat': <String, Object?>{},
            'disabledSkillIds': <String>[],
            'unexpected': true,
          }),
        ),
        throwsFormatException,
      );
    });

    test('migrates chat_default without copying provider credentials', () {
      final defaults = PromptAssistantConfigState.defaults();
      final legacy = defaults.copyWith(
        routing: defaults.routing.copyWith(
          chatProviderId: 'provider-a',
          chatModel: 'model-a',
        ),
        rules: const [
          PromptRuleTemplate(
            id: 'chat_default',
            name: 'Default',
            taskType: AssistantTaskType.chat,
            content: legacyDefaultAgentChatPrompt,
            isDefault: true,
          ),
          PromptRuleTemplate(
            id: 'chat_custom',
            name: 'Custom',
            taskType: AssistantTaskType.chat,
            content: 'Custom behavior',
            order: 1,
          ),
        ],
      );

      final migrated = AgentSettings.migrateLegacy(
        promptAssistant: legacy,
        webAccessEnabled: false,
      );

      expect(migrated.chat.modelReference.providerId, 'provider-a');
      expect(migrated.chat.modelReference.model, 'model-a');
      expect(migrated.chat.customSystemPrompt, 'Custom behavior');
      expect(migrated.chat.webAccessEnabled, isFalse);
      expect(migrated.toJson().toString(), isNot(contains('example.invalid')));
    });
  });
}
