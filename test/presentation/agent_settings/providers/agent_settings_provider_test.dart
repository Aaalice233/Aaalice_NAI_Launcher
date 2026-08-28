import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/network/web_access/web_access_models.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};
  bool failPromptAssistantWrite = false;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (failPromptAssistantWrite &&
        key == StorageKeys.promptAssistantConfigJson) {
      throw StateError('prompt cleanup failed');
    }
    values[key] = value;
  }
}

class _ControlledSkillCatalogService extends SkillCatalogService {
  final secondScan = Completer<SkillCatalogSnapshot>();
  var scanCount = 0;

  static const snapshot = SkillCatalogSnapshot(
    entries: [
      SkillCatalogEntry(
        id: 'test-skill',
        skill: HarnessSkill(
          name: 'test-skill',
          description: 'test',
          content: 'test',
          filePath: 'test/SKILL.md',
        ),
        source: SkillSource.workspace,
        safePath: 'workspace:/test/SKILL.md',
        enabled: true,
      ),
    ],
  );

  @override
  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Map<String, bool> skillEnabledOverrides = const {},
  }) {
    scanCount++;
    if (scanCount == 1) return Future.value(snapshot);
    return secondScan.future;
  }
}

class _QueuedSkillCatalogService extends SkillCatalogService {
  var scanCount = 0;
  final pendingScans = <Completer<SkillCatalogSnapshot>>[];

  @override
  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Map<String, bool> skillEnabledOverrides = const {},
  }) {
    scanCount++;
    if (scanCount == 1) {
      return Future.value(_skillSnapshot('initial-project'));
    }
    final pending = Completer<SkillCatalogSnapshot>();
    pendingScans.add(pending);
    return pending.future;
  }
}

class _AllQueuedSkillCatalogService extends SkillCatalogService {
  final pendingScans = <Completer<SkillCatalogSnapshot>>[];

  @override
  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Map<String, bool> skillEnabledOverrides = const {},
  }) {
    final pending = Completer<SkillCatalogSnapshot>();
    pendingScans.add(pending);
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('agent_settings_provider_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'migrates chat_default once and preserves unrelated prompt rules',
    () async {
      final storage = _MemoryStorage();
      final defaults = PromptAssistantConfigState.defaults();
      final legacy = defaults.copyWith(
        providers: [ProviderPreset.deepseek.createConfig()],
        models: const [
          ModelConfig(
            providerId: 'deepseek',
            name: 'deepseek-chat',
            displayName: 'DeepSeek Chat',
            forTask: AssistantTaskType.chat,
          ),
        ],
        routing: defaults.routing.copyWith(
          chatProviderId: 'deepseek',
          chatModel: 'deepseek-chat',
        ),
        rules: [
          ...defaults.rules,
          const PromptRuleTemplate(
            id: 'legacy-chat',
            name: 'Legacy chat',
            taskType: AssistantTaskType.chat,
            content: 'Keep replies concise.',
            order: 50,
          ),
          const PromptRuleTemplate(
            id: 'keep-translate',
            name: 'Keep translation',
            taskType: AssistantTaskType.translate,
            content: 'Preserve terminology.',
            order: 51,
          ),
        ],
      );
      storage.values[StorageKeys.promptAssistantConfigJson] = legacy.encode();
      storage.values[StorageKeys.agentWebAccessConfigJson] =
          const WebAccessConfig(enabled: true).encode();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              workspaceDirectory: temp,
              environment: const {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _waitUntilInitialized(container);
      final settings = container.read(agentSettingsProvider).settings;
      expect(settings.chat.modelReference.providerId, 'deepseek');
      expect(settings.chat.modelReference.model, 'deepseek-chat');
      expect(settings.chat.webAccessEnabled, isTrue);
      expect(
        settings.chat.behaviorInstructions(),
        contains('Keep replies concise.'),
      );
      expect(
        settings.chat.migratedChatRules.any(
          (rule) => rule.id == 'legacy-chat' && rule.name == 'Legacy chat',
        ),
        isTrue,
      );
      expect(storage.values[StorageKeys.agentSettingsJson], isA<String>());

      final remaining = PromptAssistantConfigState.decode(
        storage.values[StorageKeys.promptAssistantConfigJson]! as String,
      );
      expect(remaining.rules.any((rule) => rule.id == 'legacy-chat'), isFalse);
      expect(
        remaining.rules.any((rule) => rule.id == 'keep-translate'),
        isTrue,
      );
    },
  );

  test('persists legacy Agent settings as the current schema', () async {
    final storage = _MemoryStorage();
    storage.values[StorageKeys.agentSettingsJson] = jsonEncode({
      'schemaVersion': 3,
      'chat': const AgentChatConfig().toJson(),
      'disabledSkillIds': ['project-off'],
    });
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: temp,
            workspaceDirectory: temp,
            environment: const {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitUntilInitialized(container);

    final persisted =
        jsonDecode(storage.values[StorageKeys.agentSettingsJson]! as String)
            as Map<String, dynamic>;
    expect(persisted['schemaVersion'], AgentSettings.currentSchemaVersion);
    expect(persisted, isNot(contains('disabledSkillIds')));
    expect(persisted['skillEnabledOverrides'], {'project-off': false});
  });

  test(
    'legacy cleanup failure is visible and retryable without data loss',
    () async {
      final storage = _MemoryStorage();
      final legacy = PromptAssistantConfigState.defaults().copyWith(
        routing: PromptAssistantConfigState.defaults().routing.copyWith(
          chatProviderId: 'provider-a',
          chatModel: 'model-a',
        ),
        rules: const [
          PromptRuleTemplate(
            id: 'legacy-chat',
            name: 'Legacy chat',
            taskType: AssistantTaskType.chat,
            content: 'Preserve this instruction.',
          ),
        ],
      );
      final legacyRaw = legacy.encode();
      storage.values[StorageKeys.promptAssistantConfigJson] = legacyRaw;
      storage.failPromptAssistantWrite = true;
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              workspaceDirectory: temp,
              environment: const {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _waitUntilInitialized(container);
      expect(
        container.read(agentSettingsProvider).error,
        contains('cleanup failed'),
      );
      expect(storage.values[StorageKeys.agentSettingsJson], isA<String>());
      expect(storage.values[StorageKeys.promptAssistantConfigJson], legacyRaw);

      storage.failPromptAssistantWrite = false;
      await container
          .read(agentSettingsProvider.notifier)
          .retryInitialization();
      expect(container.read(agentSettingsProvider).error, isEmpty);
      final cleaned =
          storage.values[StorageKeys.promptAssistantConfigJson] as String;
      expect(cleaned, isNot(contains('legacy-chat')));
      final migrated = container.read(agentSettingsProvider).settings;
      expect(
        migrated.chat.behaviorInstructions(),
        'Preserve this instruction.',
      );
    },
  );

  test(
    'reloadSkills rebases a stale scan on the latest Skill overrides',
    () async {
      final storage = _MemoryStorage();
      storage.values[StorageKeys.agentSettingsJson] = const AgentSettings()
          .encode();
      final catalog = _ControlledSkillCatalogService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              workspaceDirectory: temp,
              environment: const {},
              skillCatalogService: catalog,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      final reload = container
          .read(agentSettingsProvider.notifier)
          .reloadSkills();
      await Future<void>.delayed(Duration.zero);
      await container
          .read(agentSettingsProvider.notifier)
          .setSkillEnabled('test-skill', false);
      catalog.secondScan.complete(_ControlledSkillCatalogService.snapshot);
      await reload;

      expect(
        container.read(agentSettingsProvider).skills.entries.single.enabled,
        isFalse,
      );
      expect(
        container
            .read(agentSettingsProvider)
            .settings
            .skillEnabledOverrides['test-skill'],
        isFalse,
      );
    },
  );

  test(
    'defaults, explicit choices, new Skills, restart, and project switch persist',
    () async {
      final storage = _MemoryStorage();
      storage.values[StorageKeys.agentSettingsJson] = const AgentSettings()
          .encode();
      final projectA = Directory('${temp.path}/project-a');
      final projectB = Directory('${temp.path}/project-b');
      final home = Directory('${temp.path}/home');
      var currentProject = projectA;
      await _writeSkill(Directory('${projectA.path}/.pi/skills'), 'project-a');
      await _writeSkill(Directory('${projectB.path}/.pi/skills'), 'project-b');
      await _writeSkill(
        Directory('${home.path}/.pi/agent/skills'),
        'pi-user-skill',
      );
      await _writeSkill(
        Directory('${home.path}/.agents/skills'),
        'global-skill',
      );

      ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              environment: {'HOME': home.path},
              workspaceDirectoryResolver: () async => currentProject,
            ),
          ),
        ],
      );

      var container = createContainer();
      await _waitUntilInitialized(container);
      expect(_skillStates(container), {
        'project-a': true,
        'pi-user-skill': false,
        'global-skill': false,
      });

      final notifier = container.read(agentSettingsProvider.notifier);
      await notifier.setSkillEnabled('project-a', false);
      await notifier.setSkillEnabled('global-skill', true);
      container.dispose();

      container = createContainer();
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);
      expect(_skillStates(container), {
        'project-a': false,
        'pi-user-skill': false,
        'global-skill': true,
      });

      await _writeSkill(
        Directory('${projectA.path}/.pi/skills'),
        'new-project',
      );
      await _writeSkill(Directory('${home.path}/.agents/skills'), 'new-global');
      await container.read(agentSettingsProvider.notifier).reloadSkills();
      expect(_skillStates(container), {
        'project-a': false,
        'new-project': true,
        'pi-user-skill': false,
        'global-skill': true,
        'new-global': false,
      });

      currentProject = projectB;
      await container
          .read(agentSettingsProvider.notifier)
          .handleImageProjectChanged();
      expect(_skillStates(container), {
        'project-b': true,
        'pi-user-skill': false,
        'global-skill': true,
        'new-global': false,
      });
    },
  );

  test(
    'latest image project wins when Skill scans finish out of order',
    () async {
      final storage = _MemoryStorage();
      storage.values[StorageKeys.agentSettingsJson] = const AgentSettings()
          .encode();
      final catalog = _QueuedSkillCatalogService();
      var currentProject = Directory('${temp.path}/initial');
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              environment: const {},
              skillCatalogService: catalog,
              workspaceDirectoryResolver: () => Future.value(currentProject),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      currentProject = Directory('${temp.path}/project-a');
      final projectARefresh = container
          .read(agentSettingsProvider.notifier)
          .handleImageProjectChanged();
      await _waitForPendingScans(catalog, 1);
      currentProject = Directory('${temp.path}/project-b');
      final projectBRefresh = container
          .read(agentSettingsProvider.notifier)
          .handleImageProjectChanged();
      await _waitForPendingScans(catalog, 2);

      catalog.pendingScans[1].complete(_skillSnapshot('project-b'));
      await projectBRefresh;
      catalog.pendingScans[0].complete(_skillSnapshot('project-a'));
      await projectARefresh;

      expect(_skillStates(container), {'project-b': true});
      expect(container.read(agentSettingsProvider).refreshingSkills, isFalse);
    },
  );

  test(
    'image project changes during initialization trigger a final rescan',
    () async {
      final storage = _MemoryStorage();
      storage.values[StorageKeys.agentSettingsJson] = const AgentSettings()
          .encode();
      final catalog = _AllQueuedSkillCatalogService();
      var currentProject = Directory('${temp.path}/project-a');
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              environment: const {},
              skillCatalogService: catalog,
              workspaceDirectoryResolver: () => Future.value(currentProject),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(agentSettingsProvider);
      await _waitForAllQueuedScans(catalog, 1);

      currentProject = Directory('${temp.path}/project-b');
      await container
          .read(agentSettingsProvider.notifier)
          .handleImageProjectChanged();
      catalog.pendingScans[0].complete(_skillSnapshot('project-a'));
      await _waitForAllQueuedScans(catalog, 2);
      catalog.pendingScans[1].complete(_skillSnapshot('project-b'));

      await _waitForSkillStates(container, {'project-b': true});
      expect(container.read(agentSettingsProvider).initialized, isTrue);
    },
  );

  test(
    'profile import cannot restore Skills from an old image project',
    () async {
      final storage = _MemoryStorage();
      storage.values[StorageKeys.agentSettingsJson] = const AgentSettings()
          .encode();
      final catalog = _QueuedSkillCatalogService();
      var currentProject = Directory('${temp.path}/project-a');
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              environment: const {},
              skillCatalogService: catalog,
              workspaceDirectoryResolver: () => Future.value(currentProject),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      final replacement = container
          .read(agentSettingsProvider.notifier)
          .replaceSettings(const AgentSettings());
      await _waitForPendingScans(catalog, 1);
      currentProject = Directory('${temp.path}/project-b');
      final projectRefresh = container
          .read(agentSettingsProvider.notifier)
          .handleImageProjectChanged();
      await _waitForPendingScans(catalog, 2);
      catalog.pendingScans[1].complete(_skillSnapshot('project-b'));
      await projectRefresh;
      catalog.pendingScans[0].complete(_skillSnapshot('project-a'));
      await _waitForPendingScans(catalog, 3);
      catalog.pendingScans[2].complete(_skillSnapshot('project-b'));
      await replacement;

      expect(_skillStates(container), {'project-b': true});
    },
  );

  test(
    'image project refresh consumes scan errors after exposing them',
    () async {
      final storage = _MemoryStorage();
      storage.values[StorageKeys.agentSettingsJson] = const AgentSettings()
          .encode();
      final catalog = _ControlledSkillCatalogService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              workspaceDirectory: temp,
              environment: const {},
              skillCatalogService: catalog,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      final refresh = container
          .read(agentSettingsProvider.notifier)
          .handleImageProjectChanged();
      await _waitForScanCount(catalog, 2);
      catalog.secondScan.completeError(StateError('scan failed'));

      await expectLater(refresh, completes);
      expect(
        container.read(agentSettingsProvider).error,
        contains('scan failed'),
      );
    },
  );

  test('does not overwrite a damaged independent Agent document', () async {
    final storage = _MemoryStorage();
    storage.values[StorageKeys.agentSettingsJson] = '{damaged';
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: temp,
            workspaceDirectory: temp,
            environment: const {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitUntilInitialized(container);
    expect(container.read(agentSettingsProvider).error, isNotEmpty);
    expect(storage.values[StorageKeys.agentSettingsJson], '{damaged');
    await expectLater(
      container.read(agentSettingsProvider.notifier).setWebAccessEnabled(true),
      throwsStateError,
    );
    expect(storage.values[StorageKeys.agentSettingsJson], '{damaged');
  });

  test('treats an empty stored Agent document as damaged', () async {
    final storage = _MemoryStorage();
    storage.values[StorageKeys.agentSettingsJson] = '';
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: temp,
            workspaceDirectory: temp,
            environment: const {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitUntilInitialized(container);
    expect(container.read(agentSettingsProvider).error, isNotEmpty);
    expect(storage.values[StorageKeys.agentSettingsJson], '');
  });

  test(
    'preserves malformed legacy web access state for explicit recovery',
    () async {
      final storage = _MemoryStorage();
      storage.values[StorageKeys.agentWebAccessConfigJson] = '{damaged';
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              workspaceDirectory: temp,
              environment: const {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _waitUntilInitialized(container);

      expect(
        container.read(agentSettingsProvider).error,
        contains('Cannot migrate'),
      );
      expect(storage.values[StorageKeys.agentWebAccessConfigJson], '{damaged');
      expect(
        storage.values.containsKey(StorageKeys.agentSettingsJson),
        isFalse,
      );
    },
  );

  test(
    'profile replacement rolls back storage and state when scan fails',
    () async {
      final storage = _MemoryStorage();
      const original = AgentSettings();
      storage.values[StorageKeys.agentSettingsJson] = original.encode();
      final catalog = _ControlledSkillCatalogService();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              workspaceDirectory: temp,
              environment: const {},
              skillCatalogService: catalog,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await _waitUntilInitialized(container);

      const imported = AgentSettings(
        chat: AgentChatConfig(customSystemPrompt: 'Imported'),
      );
      final replacement = container
          .read(agentSettingsProvider.notifier)
          .replaceSettings(imported);
      while (catalog.scanCount < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      catalog.secondScan.completeError(StateError('scan failed'));

      await expectLater(replacement, throwsStateError);
      expect(
        container.read(agentSettingsProvider).settings.chat.customSystemPrompt,
        isEmpty,
      );
      expect(
        AgentSettings.decode(
          storage.values[StorageKeys.agentSettingsJson]! as String,
        ).chat.customSystemPrompt,
        isEmpty,
      );
    },
  );

  test(
    'oversized legacy instructions are preserved instead of half migrated',
    () async {
      final storage = _MemoryStorage();
      final defaults = PromptAssistantConfigState.defaults();
      final legacy = defaults.copyWith(
        rules: [
          ...defaults.rules,
          PromptRuleTemplate(
            id: 'oversized-chat',
            name: 'Oversized',
            taskType: AssistantTaskType.chat,
            content: List.filled(50001, 'x').join(),
            order: 50,
          ),
        ],
      );
      final legacyRaw = legacy.encode();
      storage.values[StorageKeys.promptAssistantConfigJson] = legacyRaw;
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: temp,
              workspaceDirectory: temp,
              environment: const {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _waitUntilInitialized(container);
      expect(container.read(agentSettingsProvider).error, isNotEmpty);
      expect(storage.values[StorageKeys.agentSettingsJson], isNull);
      expect(storage.values[StorageKeys.promptAssistantConfigJson], legacyRaw);
    },
  );
}

Map<String, bool> _skillStates(ProviderContainer container) => {
  for (final entry
      in container.read(agentSettingsProvider).skills.effectiveEntries)
    entry.id: entry.enabled,
};

Future<void> _writeSkill(Directory root, String name) async {
  final directory = Directory('${root.path}${Platform.pathSeparator}$name');
  await directory.create(recursive: true);
  await File(
    '${directory.path}${Platform.pathSeparator}SKILL.md',
  ).writeAsString('''---
name: $name
description: $name test Skill
---
$name instructions.
''');
}

class _MemorySecureStorage extends SecureStorageService {
  @override
  Future<String?> getAgentWebAccessExaApiKey() async => null;
}

Future<void> _waitUntilInitialized(ProviderContainer container) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (container.read(agentSettingsProvider).initialized) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Agent settings did not initialize.');
}

Future<void> _waitForPendingScans(
  _QueuedSkillCatalogService catalog,
  int count,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (catalog.pendingScans.length >= count) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected $count pending Skill scans.');
}

Future<void> _waitForScanCount(
  _ControlledSkillCatalogService catalog,
  int count,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (catalog.scanCount >= count) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected $count Skill scans.');
}

Future<void> _waitForAllQueuedScans(
  _AllQueuedSkillCatalogService catalog,
  int count,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (catalog.pendingScans.length >= count) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected $count queued Skill scans.');
}

Future<void> _waitForSkillStates(
  ProviderContainer container,
  Map<String, bool> expected,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (_mapsEqual(_skillStates(container), expected)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected Skill states $expected, got ${_skillStates(container)}.');
}

bool _mapsEqual(Map<String, bool> left, Map<String, bool> right) {
  if (left.length != right.length) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}

SkillCatalogSnapshot _skillSnapshot(String id) => SkillCatalogSnapshot(
  entries: [
    SkillCatalogEntry(
      id: id,
      skill: HarnessSkill(
        name: id,
        description: '$id description',
        content: '$id instructions',
        filePath: '$id/SKILL.md',
      ),
      source: SkillSource.workspace,
      safePath: 'workspace:/$id/SKILL.md',
      enabled: true,
    ),
  ],
);
