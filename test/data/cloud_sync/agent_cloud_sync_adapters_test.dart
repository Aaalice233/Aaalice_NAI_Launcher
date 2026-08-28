import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/agent_cloud_sync_adapters.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';

void main() {
  group('Agent system prompt backup', () {
    test(
      'round-trips only the custom prompt and preserves local settings',
      () async {
        final source = _MemoryStorage();
        await source.setSetting(
          StorageKeys.agentSettingsJson,
          const AgentSettings(
            chat: AgentChatConfig(
              customSystemPrompt: 'Backed up instruction',
              webAccessEnabled: true,
            ),
            disabledSkillIds: {'local-skill'},
          ).encode(),
        );
        final record = (await AgentSystemPromptCloudSyncAdapter(
          source,
        ).exportRecords().toList()).single;
        expect(record.data['version'], 1);
        expect(record.data['customSystemPrompt'], 'Backed up instruction');
        expect(record.data, isNot(contains('modelReference')));
        expect(record.data, isNot(contains('webAccessEnabled')));
        expect(record.data.toString(), isNot(contains('local-skill')));

        final target = _MemoryStorage();
        await target.setSetting(
          StorageKeys.agentSettingsJson,
          const AgentSettings(
            chat: AgentChatConfig(
              customSystemPrompt: 'Old instruction',
              webAccessEnabled: false,
            ),
            disabledSkillIds: {'keep-local'},
          ).encode(),
        );
        await AgentSystemPromptCloudSyncAdapter(target).apply([record]);
        final restored = AgentSettings.decode(
          target.values[StorageKeys.agentSettingsJson]! as String,
        );
        expect(restored.chat.customSystemPrompt, 'Backed up instruction');
        expect(restored.chat.webAccessEnabled, isFalse);
        expect(restored.disabledSkillIds, {'keep-local'});
      },
    );

    test(
      'round-trips a versioned append or override field when present',
      () async {
        final source = _MemoryStorage();
        final sourceDocument = const AgentSettings().toJson();
        final sourceChat = Map<String, dynamic>.from(
          sourceDocument['chat']! as Map,
        );
        sourceChat['customSystemPrompt'] = 'Future mode prompt';
        sourceChat['systemPromptMode'] = 'override';
        sourceDocument['chat'] = sourceChat;
        await source.setSetting(
          StorageKeys.agentSettingsJson,
          jsonEncode(sourceDocument),
        );

        final sourceAdapter = AgentSystemPromptCloudSyncAdapter(source);
        final record = (await sourceAdapter.exportRecords().toList()).single;
        await sourceAdapter.preflight([record]);
        expect(record.data['version'], 1);
        expect(record.data['systemPromptMode'], 'override');

        final target = _MemoryStorage();
        final targetDocument = const AgentSettings().toJson();
        final targetChat = Map<String, dynamic>.from(
          targetDocument['chat']! as Map,
        )..['systemPromptMode'] = 'append';
        targetDocument['chat'] = targetChat;
        await target.setSetting(
          StorageKeys.agentSettingsJson,
          jsonEncode(targetDocument),
        );
        final targetAdapter = AgentSystemPromptCloudSyncAdapter(target);
        await targetAdapter.preflight([record]);
        await targetAdapter.apply([record]);

        final restored =
            jsonDecode(target.values[StorageKeys.agentSettingsJson]! as String)
                as Map<String, dynamic>;
        final restoredChat = restored['chat']! as Map<String, dynamic>;
        expect(restoredChat['customSystemPrompt'], 'Future mode prompt');
        expect(restoredChat['systemPromptMode'], 'override');
      },
    );

    test(
      'old snapshots without Agent records leave local settings intact',
      () async {
        final storage = _MemoryStorage();
        await storage.setSetting(
          StorageKeys.agentSettingsJson,
          const AgentSettings(
            chat: AgentChatConfig(customSystemPrompt: 'Keep me'),
          ).encode(),
        );

        await AgentSystemPromptCloudSyncAdapter(storage).apply(const []);

        expect(
          AgentSettings.decode(
            storage.values[StorageKeys.agentSettingsJson]! as String,
          ).chat.customSystemPrompt,
          'Keep me',
        );
      },
    );
  });

  group('Agent Skill backup', () {
    late Directory temp;
    late Directory sourceRoot;
    late Directory restoreRoot;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('agent-skill-sync-');
      sourceRoot = Directory('${temp.path}/source')
        ..createSync(recursive: true);
      restoreRoot = Directory('${temp.path}/restore')
        ..createSync(recursive: true);
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test(
      'archives only selected Skills with complete folder contents',
      () async {
        final first = await _createSkill(
          sourceRoot,
          'first-skill',
          body: 'First body',
          resource: 'script content',
        );
        final second = await _createSkill(
          sourceRoot,
          'second-skill',
          body: 'Second body',
        );
        final adapter = AgentSkillsCloudSyncAdapter(
          roots: [
            SkillRoot(source: SkillSource.workspace, path: sourceRoot.path),
          ],
          localEntries: [first, second],
          selectedSkillIds: {first.backupId},
        );

        final records = await adapter.exportRecords().toList();

        expect(records.map((record) => record.id), [
          'selection',
          'workspace:first-skill',
        ]);
        expect(records.last.data['source'], 'workspace');
        expect(records.last.resource, isNotNull);

        final restoreAdapter = AgentSkillsCloudSyncAdapter(
          roots: [
            SkillRoot(source: SkillSource.workspace, path: restoreRoot.path),
          ],
          localEntries: const [],
          selectedSkillIds: const {},
        );
        await restoreAdapter.preflight(records);
        await restoreAdapter.apply(records);

        expect(
          File('${restoreRoot.path}/first-skill/SKILL.md').readAsStringSync(),
          contains('First body'),
        );
        expect(
          File(
            '${restoreRoot.path}/first-skill/scripts/helper.txt',
          ).readAsStringSync(),
          'script content',
        );
        expect(
          Directory('${restoreRoot.path}/second-skill').existsSync(),
          isFalse,
        );
      },
    );

    test('blocks a non-directory conflict without overwriting', () async {
      final remoteEntry = await _createSkill(
        sourceRoot,
        'shared-skill',
        body: 'Remote body',
      );
      final remoteAdapter = AgentSkillsCloudSyncAdapter(
        roots: [
          SkillRoot(source: SkillSource.workspace, path: sourceRoot.path),
        ],
        localEntries: [remoteEntry],
        selectedSkillIds: {remoteEntry.backupId},
      );
      final records = await remoteAdapter.exportRecords().toList();

      final localFile = File('${restoreRoot.path}/shared-skill');
      await localFile.writeAsString('Local file must survive');
      final restoreAdapter = AgentSkillsCloudSyncAdapter(
        roots: [
          SkillRoot(source: SkillSource.workspace, path: restoreRoot.path),
        ],
        localEntries: const [],
        selectedSkillIds: const {},
      );

      await expectLater(
        restoreAdapter.apply(records),
        throwsA(isA<CloudSyncPreflightException>()),
      );
      expect(localFile.readAsStringSync(), 'Local file must survive');
    });

    test(
      'remote selection replaces a directory through transactional installer',
      () async {
        final remoteEntry = await _createSkill(
          sourceRoot,
          'shared-skill',
          body: 'Remote body wins',
        );
        final remoteAdapter = AgentSkillsCloudSyncAdapter(
          roots: [
            SkillRoot(source: SkillSource.workspace, path: sourceRoot.path),
          ],
          localEntries: [remoteEntry],
          selectedSkillIds: {remoteEntry.backupId},
        );
        final records = await remoteAdapter.exportRecords().toList();
        final localEntry = await _createSkill(
          restoreRoot,
          'shared-skill',
          body: 'Local body',
        );
        final restoreAdapter = AgentSkillsCloudSyncAdapter(
          roots: [
            SkillRoot(source: SkillSource.workspace, path: restoreRoot.path),
          ],
          localEntries: [localEntry],
          selectedSkillIds: const {},
        );

        await restoreAdapter.apply(records);

        expect(
          File('${restoreRoot.path}/shared-skill/SKILL.md').readAsStringSync(),
          contains('Remote body wins'),
        );
      },
    );

    test(
      'preflight never recovers an interrupted install transaction',
      () async {
        final remoteEntry = await _createSkill(
          sourceRoot,
          'pending-skill',
          body: 'Remote body',
        );
        final records = await AgentSkillsCloudSyncAdapter(
          roots: [
            SkillRoot(source: SkillSource.workspace, path: sourceRoot.path),
          ],
          localEntries: [remoteEntry],
          selectedSkillIds: {remoteEntry.backupId},
        ).exportRecords().toList();
        final marker = File(
          '${restoreRoot.path}/.skill-import-pending/marker.txt',
        );
        await marker.parent.create(recursive: true);
        await marker.writeAsString('untouched');
        final restoreAdapter = AgentSkillsCloudSyncAdapter(
          roots: [
            SkillRoot(source: SkillSource.workspace, path: restoreRoot.path),
          ],
          localEntries: const [],
          selectedSkillIds: const {},
        );

        await expectLater(
          restoreAdapter.preflight(records),
          throwsA(isA<CloudSyncPreflightException>()),
        );
        expect(marker.readAsStringSync(), 'untouched');
      },
    );
  });
}

Future<SkillCatalogEntry> _createSkill(
  Directory root,
  String name, {
  required String body,
  String? resource,
}) async {
  final directory = Directory('${root.path}/$name')
    ..createSync(recursive: true);
  final manifest = File('${directory.path}/SKILL.md');
  await manifest.writeAsString(
    '---\nname: $name\ndescription: Test $name\n---\n$body\n',
  );
  if (resource != null) {
    final file = File('${directory.path}/scripts/helper.txt');
    await file.parent.create(recursive: true);
    await file.writeAsString(resource);
  }
  return SkillCatalogEntry(
    id: name,
    skill: HarnessSkill(
      name: name,
      description: 'Test $name',
      content: body,
      filePath: manifest.path,
    ),
    source: SkillSource.workspace,
    safePath: 'workspace:/$name/SKILL.md',
    enabled: true,
  );
}

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
