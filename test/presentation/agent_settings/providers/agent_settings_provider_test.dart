import 'dart:async';
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
    Set<String> disabledSkillIds = const {},
  }) {
    scanCount++;
    if (scanCount == 1) return Future.value(snapshot);
    return secondScan.future;
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
    'reloadSkills rebases a stale scan on the latest disabled IDs',
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
        container.read(agentSettingsProvider).settings.disabledSkillIds,
        contains('test-skill'),
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
