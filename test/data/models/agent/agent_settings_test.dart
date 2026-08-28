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
          systemPromptMode: AgentSystemPromptMode.override,
          permissionMode: AgentPermissionMode.safe,
          webAccessEnabled: false,
        ),
        disabledSkillIds: {'demo'},
      );

      final decoded = AgentSettings.decode(jsonEncode(settings.toJson()));
      expect(decoded.chat.modelReference, settings.chat.modelReference);
      expect(decoded.chat.customSystemPrompt, settings.chat.customSystemPrompt);
      expect(decoded.chat.systemPromptMode, AgentSystemPromptMode.override);
      expect(decoded.disabledSkillIds, settings.disabledSkillIds);
      expect(
        settings.toJson()['schemaVersion'],
        AgentSettings.currentSchemaVersion,
      );
    });

    test('schema 3 settings migrate to append mode', () {
      final raw = const AgentSettings(
        chat: AgentChatConfig(customSystemPrompt: 'Keep this behavior.'),
      ).toJson();
      raw['schemaVersion'] = 3;
      (raw['chat']! as Map<String, dynamic>).remove('systemPromptMode');

      final decoded = AgentSettings.decode(jsonEncode(raw));

      expect(decoded.chat.systemPromptMode, AgentSystemPromptMode.append);
      expect(decoded.chat.customSystemPrompt, 'Keep this behavior.');
    });

    test('override excludes migrated legacy rules from final user content', () {
      const chat = AgentChatConfig(
        systemPromptMode: AgentSystemPromptMode.override,
        customSystemPrompt: 'Only this prompt.',
        migratedChatRules: [
          AgentMigratedChatRule(
            id: 'legacy',
            name: 'Legacy',
            content: 'Old appended rule.',
            enabled: true,
            isDefault: false,
            order: 0,
          ),
        ],
      );

      expect(chat.behaviorInstructions(), 'Only this prompt.');
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
      expect(migrated.chat.customSystemPrompt, isEmpty);
      expect(migrated.chat.systemPromptMode, AgentSystemPromptMode.append);
      expect(migrated.chat.migratedChatRules, hasLength(2));
      expect(
        migrated.chat.migratedChatRules.first,
        isA<AgentMigratedChatRule>()
            .having((rule) => rule.id, 'id', 'chat_default')
            .having((rule) => rule.name, 'name', 'Default')
            .having((rule) => rule.enabled, 'enabled', isTrue)
            .having((rule) => rule.isDefault, 'isDefault', isTrue)
            .having((rule) => rule.order, 'order', 0),
      );
      expect(migrated.chat.behaviorInstructions(), 'Custom behavior');
      expect(migrated.chat.webAccessEnabled, isFalse);
      expect(migrated.toJson().toString(), isNot(contains('example.invalid')));
    });

    test('preserves disabled legacy chat rules and their metadata', () {
      final defaults = PromptAssistantConfigState.defaults();
      final migrated = AgentSettings.migrateLegacy(
        promptAssistant: defaults.copyWith(
          rules: const [
            PromptRuleTemplate(
              id: 'disabled-chat',
              name: 'Disabled rule',
              taskType: AssistantTaskType.chat,
              content: 'Do not activate this.',
              enabled: false,
              order: 42,
            ),
          ],
        ),
        webAccessEnabled: false,
      );

      final rule = migrated.chat.migratedChatRules.single;
      expect(rule.id, 'disabled-chat');
      expect(rule.name, 'Disabled rule');
      expect(rule.enabled, isFalse);
      expect(rule.order, 42);
      expect(migrated.chat.behaviorInstructions(), isEmpty);
      final roundTrip = AgentSettings.decode(migrated.encode());
      expect(roundTrip.chat.migratedChatRules.single.enabled, isFalse);
      expect(roundTrip.chat.migratedChatRules.single.name, 'Disabled rule');
    });
  });
}
