import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_profile_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';

void main() {
  const service = AgentProfileService();
  const settings = AgentSettings(
    chat: AgentChatConfig(
      modelReference: AgentModelReference(
        providerId: 'provider-a',
        model: 'model-a',
      ),
      customSystemPrompt: 'Be concise.',
    ),
    disabledSkillIds: {'demo'},
  );

  test('profile export contains portable preferences', () {
    final text = service.exportProfile(settings);

    expect(text, contains('provider-a'));
    expect(text, contains('model-a'));
    expect(text, contains('demo'));
    expect(text, contains('Be concise.'));
    expect(text, isNot(contains('apiKey')));
    expect(text, isNot(contains('chatHistory')));
  });

  test('refuses to export secrets or absolute paths embedded in prompts', () {
    for (final prompt in [
      'token=secret',
      'C:/private/path',
      '/root/private/config.json',
      '/srv/app/secrets',
      '/usr/local/bin/tool',
      '/workspace/project/private.json',
      r'\\server\share\private.json',
      '//server/share/private.json',
      'file:///home/alice/private.json',
      'file://server/share/private.json',
      'password=hunter2',
      'use Bearer sk-secret-value',
      'use pst-1234567890abcdef',
      'use sk-1234567890abcdefghijklmnop',
      'use ghp_1234567890abcdefghijklmnop',
      'use eyJabcdefghijk.abcdefghijk.abcdefghijk',
    ]) {
      expect(
        () => service.exportProfile(
          settings.copyWith(
            chat: settings.chat.copyWith(customSystemPrompt: prompt),
          ),
        ),
        throwsFormatException,
      );
    }
  });

  test('does not reject ordinary URLs, commands, or token-like prose', () {
    for (final prompt in [
      'See https://example.com/docs/path.',
      'Run /help and then choose image/edit.',
      'The token budget is 2000.',
      'Use sketch-style rendering.',
      'Reference assets/skills/demo.md.',
    ]) {
      expect(
        () => service.exportProfile(
          settings.copyWith(
            chat: settings.chat.copyWith(customSystemPrompt: prompt),
          ),
        ),
        returnsNormally,
      );
    }
  });

  test('refuses to import private data embedded in a profile', () {
    final payload = {
      'format': 'aaalice-agent-profile',
      'schemaVersion': 1,
      'settings': settings
          .copyWith(
            chat: settings.chat.copyWith(customSystemPrompt: 'token=secret'),
          )
          .toJson(),
    };

    expect(
      () => service.previewImport(
        raw: jsonEncode(payload),
        current: const AgentSettings(),
      ),
      throwsFormatException,
    );
  });

  test('preview preserves unresolved model and skill preferences', () {
    final raw = service.exportProfile(settings);
    final preview = service.previewImport(
      raw: raw,
      current: const AgentSettings(),
      availableModelReferences: const {},
      availableSkillIds: const {},
    );

    expect(preview.warnings, contains('unmatchedModel:provider-a/model-a'));
    expect(preview.warnings, contains('unmatchedSkill:demo'));
    expect(preview.settings.disabledSkillIds, {'demo'});
  });

  test('export and import round-trip every portable setting', () {
    final preview = service.previewImport(
      raw: service.exportProfile(settings),
      current: const AgentSettings(),
      availableModelReferences: const {'provider-a/model-a'},
      availableSkillIds: const {'demo'},
    );
    final roundTripped = service.previewImport(
      raw: service.exportProfile(preview.settings),
      current: const AgentSettings(),
      availableModelReferences: const {'provider-a/model-a'},
      availableSkillIds: const {'demo'},
    );

    expect(roundTripped.settings.toJson(), settings.toJson());
    expect(roundTripped.warnings, isEmpty);
  });

  test('rejects unknown profile fields and unsupported schema', () {
    for (final payload in [
      {
        'format': 'aaalice-agent-profile',
        'schemaVersion': 1,
        'settings': <String, Object?>{},
        'extra': true,
      },
      {
        'format': 'aaalice-agent-profile',
        'schemaVersion': 99,
        'settings': <String, Object?>{},
      },
    ]) {
      expect(
        () => service.previewImport(
          raw: const JsonEncoder().convert(payload),
          current: const AgentSettings(),
          availableModelReferences: const {},
          availableSkillIds: const {},
        ),
        throwsFormatException,
      );
    }
  });
}
