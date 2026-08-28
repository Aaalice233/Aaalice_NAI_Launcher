import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart';
import 'package:nai_launcher/core/agent/llm_types.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('session controls lock while running or transitioning', () {
    expect(canManageAgentChatSessions(const AgentChatState()), isTrue);
    expect(
      canManageAgentChatSessions(
        const AgentChatState(status: AgentChatRunStatus.running),
      ),
      isFalse,
    );
    expect(
      canManageAgentChatSessions(
        const AgentChatState(sessionTransitioning: true),
      ),
      isFalse,
    );
  });

  test('session usage includes responses and compaction calls', () {
    final usage = calculateAgentChatSessionUsage([
      MessageEntry(
        id: 'message',
        message: _assistant(const Usage(input: 10, output: 4, totalTokens: 14)),
      ),
      CompactionEntry(
        id: 'compaction',
        summary: 'summary',
        retainedTail: const [],
        tokensBefore: 100,
        usage: const Usage(input: 8, output: 2, totalTokens: 10),
      ),
      BranchSummaryEntry(
        id: 'branch-summary',
        fromId: 'message',
        summary: 'summary',
        usage: const Usage(input: 3, output: 1, totalTokens: 4),
      ),
    ]);

    expect(usage.input, 21);
    expect(usage.output, 7);
    expect(usage.totalTokens, 28);
  });

  test('old notifier import still exposes AgentApiClient', () {
    AgentApiClient? client;
    expect(client, isNull);
  });

  test('draft APIs remain safe during async initialization', () async {
    final root = await Directory.systemTemp.createTemp(
      'agent_chat_initializing_draft_',
    );
    addTearDown(() => root.delete(recursive: true));
    final provider = StateNotifierProvider<AgentChatNotifier, AgentChatState>((
      ref,
    ) {
      return AgentChatNotifier(
        ref,
        supportDir: root,
        workspaceDir: root,
        presetSkills: const [],
      );
    });
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: root,
            workspaceDirectory: root,
            environment: const {},
          ),
        ),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(provider.notifier);
    expect(() => notifier.setComposerText('draft'), returnsNormally);
    expect(container.read(provider).composerText, 'draft');
    await expectLater(notifier.removePendingResource(0), completes);
    await expectLater(notifier.clearPendingResources(), completes);
    await expectLater(notifier.refreshPendingResourceAvailability(), completes);
    expect(await notifier.validatePendingResourcesForSend(), isTrue);
    await expectLater(notifier.clearComposerText(), completes);
    expect(container.read(provider).composerText, isEmpty);

    await _waitForInitialized(container, provider);
  });

  test('loads workspace skills and ignores the legacy app directory', () async {
    final root = await Directory.systemTemp.createTemp(
      'agent_chat_skill_sources_',
    );
    addTearDown(() => root.delete(recursive: true));
    final supportDir = Directory(
      '${root.path}${Platform.pathSeparator}support',
    );
    final workspaceDir = Directory(
      '${root.path}${Platform.pathSeparator}workspace',
    );
    final workspaceSkillDir = Directory(
      '${workspaceDir.path}${Platform.pathSeparator}.pi'
      '${Platform.pathSeparator}skills${Platform.pathSeparator}workspace-only',
    );
    final legacyAppSkillDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}agent'
      '${Platform.pathSeparator}skills${Platform.pathSeparator}app-only',
    );
    final piUserSkillDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}pi-user'
      '${Platform.pathSeparator}skills${Platform.pathSeparator}user-only',
    );
    await workspaceSkillDir.create(recursive: true);
    await legacyAppSkillDir.create(recursive: true);
    await piUserSkillDir.create(recursive: true);
    await File(
      '${workspaceSkillDir.path}${Platform.pathSeparator}SKILL.md',
    ).writeAsString('''---
name: workspace-only
description: Loaded from the image workspace.
---
Workspace instructions.
''');
    await File(
      '${legacyAppSkillDir.path}${Platform.pathSeparator}SKILL.md',
    ).writeAsString('''---
name: app-only
description: Must not load from the legacy app directory.
---
Legacy instructions.
''');
    await File(
      '${piUserSkillDir.path}${Platform.pathSeparator}SKILL.md',
    ).writeAsString('''---
name: user-only
description: Available globally but disabled by default.
---
User instructions.
''');

    final storage = _MemoryLocalStorage();
    final provider = StateNotifierProvider<AgentChatNotifier, AgentChatState>((
      ref,
    ) {
      return AgentChatNotifier(
        ref,
        supportDir: supportDir,
        workspaceDir: workspaceDir,
        skillEnvironment: const {},
      );
    });
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: supportDir,
            workspaceDirectory: workspaceDir,
            environment: const {},
          ),
        ),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
      ],
    );
    addTearDown(container.dispose);
    container.read(provider);
    await _waitForInitialized(container, provider);

    final names = container.read(provider).skills.map((skill) => skill.name);
    expect(names, contains('workspace-only'));
    expect(names, isNot(contains('user-only')));
    expect(names, isNot(contains('app-only')));

    await container
        .read(agentSettingsProvider.notifier)
        .setSkillEnabled('user-only', true);
    await _waitForSkill(container, provider, 'user-only');
    expect(
      container.read(provider).skills.map((skill) => skill.name),
      contains('user-only'),
    );
  });

  test(
    'replaces injected Skills when the current image project changes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'agent_chat_project_switch_',
      );
      addTearDown(() => root.delete(recursive: true));
      final supportDir = Directory('${root.path}/support');
      final projectA = Directory('${root.path}/project-a');
      final projectB = Directory('${root.path}/project-b');
      await _writeProjectSkill(projectA, 'project-a-skill');
      await _writeProjectSkill(projectB, 'project-b-skill');
      var currentProject = projectA;
      final storage = _MemoryLocalStorage();
      final provider = StateNotifierProvider<AgentChatNotifier, AgentChatState>(
        (ref) {
          return AgentChatNotifier(
            ref,
            supportDir: supportDir,
            skillEnvironment: const {},
            imageProjectDirectoryResolver: () => Future.value(currentProject),
          );
        },
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: supportDir,
              environment: const {},
              workspaceDirectoryResolver: () => Future.value(currentProject),
            ),
          ),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(provider);
      await _waitForInitialized(container, provider);
      await _waitForSkill(container, provider, 'project-a-skill');

      currentProject = projectB;
      await container
          .read(agentSettingsProvider.notifier)
          .handleImageProjectChanged();
      await _waitForSkill(container, provider, 'project-b-skill');

      final names = container.read(provider).skills.map((skill) => skill.name);
      expect(names, contains('project-b-skill'));
      expect(names, isNot(contains('project-a-skill')));
    },
  );

  group('AgentChatNotifier sessions', () {
    late Directory tempDir;
    late _MemoryLocalStorage storage;
    late ProviderContainer container;
    late StateNotifierProvider<AgentChatNotifier, AgentChatState> provider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'agent_chat_notifier_test_',
      );
      storage = _MemoryLocalStorage();
      provider = StateNotifierProvider<AgentChatNotifier, AgentChatState>((
        ref,
      ) {
        return AgentChatNotifier(
          ref,
          supportDir: tempDir,
          workspaceDir: tempDir,
          presetSkills: const [],
        );
      });
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentSettingsProvider.overrideWith(
            (ref) => AgentSettingsNotifier(
              ref,
              supportDirectory: tempDir,
              workspaceDirectory: tempDir,
              environment: const {},
            ),
          ),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
        ],
      );
      container.read(provider);
      await _waitForInitialized(container, provider);
    });

    tearDown(() async {
      container.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('配置新增服务商后立即刷新聊天路由', () async {
      final configNotifier = container.read(
        promptAssistantConfigProvider.notifier,
      );
      for (final item in [
        ...container.read(promptAssistantConfigProvider).providers,
      ]) {
        await configNotifier.upsertProvider(item.copyWith(enabled: false));
      }
      expect(container.read(provider).routeReady, isFalse);

      await configNotifier.upsertProvider(
        ProviderPreset.deepseek.createConfig(),
      );
      await configNotifier.upsertModel(
        const ModelConfig(
          providerId: 'deepseek',
          name: 'deepseek-chat',
          displayName: 'DeepSeek Chat',
          forTask: AssistantTaskType.chat,
        ),
      );
      await container
          .read(agentSettingsProvider.notifier)
          .setModelReference(
            const AgentModelReference(
              providerId: 'deepseek',
              model: 'deepseek-chat',
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(provider);
      expect(state.routeReady, isTrue);
      expect(state.routeLabel, contains('DeepSeek'));
    });

    test(
      'restores usage per session and clears it for a new session',
      () async {
        final notifier = container.read(provider.notifier);
        final repo = JsonlSessionRepo(tempDir);
        final firstId = container.read(provider).activeSessionId;
        final firstMetadata = (await repo.list()).single;
        final firstSession = await repo.open(firstMetadata);
        await firstSession.appendMessage(
          _assistant(const Usage(input: 12, output: 5, totalTokens: 17)),
        );

        await notifier.newSession();
        final secondId = container.read(provider).activeSessionId;
        expect(secondId, isNot(firstId));
        expect(container.read(provider).totalUsage?.totalTokens, 0);

        await notifier.switchSession(firstId);
        expect(container.read(provider).totalUsage?.totalTokens, 17);

        await notifier.switchSession(secondId);
        expect(container.read(provider).totalUsage?.totalTokens, 0);
      },
    );

    test('restores legacy read image paths when switching sessions', () async {
      final notifier = container.read(provider.notifier);
      final repo = JsonlSessionRepo(tempDir);
      final firstId = container.read(provider).activeSessionId;
      final firstMetadata = (await repo.list()).single;
      final firstSession = await repo.open(firstMetadata);
      final image = File(
        '${tempDir.path}${Platform.pathSeparator}legacy-result.png',
      );
      await image.writeAsBytes(const [0x89, 0x50, 0x4e, 0x47]);
      await firstSession.appendMessage(
        AssistantMessage(
          content: const [
            ToolCallContent(
              id: 'legacy-read',
              name: 'read',
              arguments: {'path': 'legacy-result.png'},
            ),
          ],
          stopReason: StopReason.toolUse,
        ),
      );
      await firstSession.appendMessage(
        ToolResultMessage(
          toolCallId: 'legacy-read',
          toolName: 'read',
          content: const [ToolResultTextContent('Read image file [image/png]')],
        ),
      );

      await notifier.newSession();
      await notifier.switchSession(firstId);

      final result = container
          .read(provider)
          .messages
          .whereType<ToolResultMessage>()
          .single;
      expect(result.details, {
        'files': [image.path],
      });
    });

    test('rewinds the main lane before the latest user message', () async {
      final notifier = container.read(provider.notifier);
      final repo = JsonlSessionRepo(tempDir);
      final firstId = container.read(provider).activeSessionId;
      final firstMetadata = (await repo.list()).single;
      final firstSession = await repo.open(firstMetadata);
      await firstSession.appendMessage(UserMessage.text('first request'));
      await firstSession.appendMessage(_assistant(const Usage()));
      await firstSession.appendMessage(UserMessage.text('second request'));
      await firstSession.appendMessage(_assistant(const Usage()));

      await notifier.newSession();
      await notifier.switchSession(firstId);
      expect(container.read(provider).messages, hasLength(4));

      final rewound = await notifier.rewindLastUserMessage();

      expect(rewound?.text, 'second request');
      expect(container.read(provider).messages.map((message) => message.role), [
        'user',
        'assistant',
      ]);
      expect(container.read(provider).sessionTransitioning, isFalse);

      final reopenedRepo = JsonlSessionRepo(tempDir);
      final reopenedMetadata = (await reopenedRepo.list()).firstWhere(
        (metadata) => metadata.id == firstId,
      );
      final reopened = await reopenedRepo.open(reopenedMetadata);
      final mainBranch = await reopened.findEntriesOnBranch();
      final allEntries = await reopened.findEntries();
      expect(mainBranch.whereType<MessageEntry>(), hasLength(2));
      expect(allEntries.whereType<MessageEntry>(), hasLength(4));
    });

    test('serializes concurrent session creation', () async {
      final notifier = container.read(provider.notifier);
      final before = container.read(provider).sessions.length;

      await Future.wait([notifier.newSession(), notifier.newSession()]);

      expect(container.read(provider).sessions.length, before + 1);
      expect(container.read(provider).sessionTransitioning, isFalse);
    });

    test('deleting the active session creates a valid replacement', () async {
      final notifier = container.read(provider.notifier);
      final deletedId = container.read(provider).activeSessionId;

      await notifier.deleteSession(deletedId);

      final state = container.read(provider);
      expect(state.activeSessionId, isNot(deletedId));
      final repo = JsonlSessionRepo(tempDir);
      final metadata = (await repo.list()).single;
      expect(metadata.id, state.activeSessionId);
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}agent_chat'
        '${Platform.pathSeparator}sessions${Platform.pathSeparator}'
        '${metadata.id}.jsonl',
      );
      expect(await file.readAsLines(), isNotEmpty);
      expect((await file.readAsLines()).first, contains('"op":"header"'));
    });
  });
}

Future<void> _writeProjectSkill(Directory project, String name) async {
  final skillDirectory = Directory(
    '${project.path}${Platform.pathSeparator}.pi'
    '${Platform.pathSeparator}skills${Platform.pathSeparator}$name',
  );
  await skillDirectory.create(recursive: true);
  await File(
    '${skillDirectory.path}${Platform.pathSeparator}SKILL.md',
  ).writeAsString('''---
name: $name
description: $name description
---
$name instructions.
''');
}

class _MemorySecureStorage extends SecureStorageService {
  @override
  Future<String?> getAgentWebAccessExaApiKey() async => null;
}

AssistantMessage _assistant(Usage usage) {
  return AssistantMessage(
    content: const [AssistantTextContent('done')],
    stopReason: StopReason.stop,
    usage: usage,
    provider: 'test',
    model: 'test',
  );
}

Future<void> _waitForInitialized(
  ProviderContainer container,
  StateNotifierProvider<AgentChatNotifier, AgentChatState> provider,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (container.read(provider).initialized) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('AgentChatNotifier did not initialize');
}

Future<void> _waitForSkill(
  ProviderContainer container,
  StateNotifierProvider<AgentChatNotifier, AgentChatState> provider,
  String name,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (container.read(provider).skills.any((skill) => skill.name == name)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('AgentChatNotifier did not inject enabled Skill $name');
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }
}
