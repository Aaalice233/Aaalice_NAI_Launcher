import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/l10n/app_localizations_en.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_slash_command.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_view_data.dart';

HarnessSkill _skill(String name, String description) => HarnessSkill(
  name: name,
  description: description,
  content: 'body',
  filePath: '/skills/$name/SKILL.md',
);

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  group('buildSlashCommands', () {
    test('sorts skills by name and appends session commands', () {
      final commands = buildSlashCommands(
        skills: [_skill('zebra', 'last'), _skill('alpha', 'first')],
        l10n: l10n,
        sessionActionsEnabled: true,
      );
      expect(
        commands.map((command) => command.name).toList(),
        ['alpha', 'zebra', 'new', 'compact', 'rename', 'delete'],
      );
      expect(commands.first.kind, AgentChatSlashCommandKind.skill);
      expect(commands.last.sessionAction, AgentChatMoreAction.delete);
    });

    test('drops session commands while a run owns the session', () {
      final commands = buildSlashCommands(
        skills: [_skill('alpha', 'first')],
        l10n: l10n,
        sessionActionsEnabled: false,
      );
      expect(commands.map((command) => command.name), ['alpha']);
    });

    test('lists a skill the model may not invoke on its own', () {
      const manual = HarnessSkill(
        name: 'manual-only',
        description: 'explicit',
        content: 'body',
        filePath: '/skills/manual-only/SKILL.md',
        disableModelInvocation: true,
      );
      final commands = buildSlashCommands(
        skills: [manual],
        l10n: l10n,
        sessionActionsEnabled: false,
      );
      expect(commands.single.name, 'manual-only');
    });
  });

  group('filterSlashCommands', () {
    final commands = buildSlashCommands(
      skills: [
        _skill('art-prompt', 'Draw with Danbooru tags'),
        _skill('paperbanana', 'Academic art figures'),
      ],
      l10n: l10n,
      sessionActionsEnabled: true,
    );

    test('returns everything for an empty query', () {
      expect(filterSlashCommands(commands, '').length, commands.length);
    });

    test('ranks name prefixes above name and description matches', () {
      final matches = filterSlashCommands(commands, 'art');
      expect(matches.first.name, 'art-prompt');
      // "Academic art figures" only matches on the description.
      expect(matches.last.name, 'paperbanana');
    });

    test('matches case-insensitively', () {
      expect(filterSlashCommands(commands, 'ART').first.name, 'art-prompt');
    });

    test('returns nothing when the name matches no command', () {
      expect(filterSlashCommands(commands, 'nonexistent'), isEmpty);
    });
  });

  group('resolveSessionCommand', () {
    test('maps a bare session command', () {
      expect(resolveSessionCommand('/new'), AgentChatMoreAction.newSession);
      expect(resolveSessionCommand('/COMPACT'), AgentChatMoreAction.compact);
    });

    test('ignores a command that carries a message', () {
      expect(resolveSessionCommand('/new draft a prompt'), isNull);
    });

    test('ignores skills and plain text', () {
      expect(resolveSessionCommand('/art-prompt'), isNull);
      expect(resolveSessionCommand('hello'), isNull);
    });
  });
}
