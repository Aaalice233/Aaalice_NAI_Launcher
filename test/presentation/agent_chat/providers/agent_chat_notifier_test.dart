import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/agent_types.dart' show ThinkingLevel;
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart';
import 'package:nai_launcher/core/agent/llm_types.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/services/android_foreground_task_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/data/models/interaction/user_question.dart';
import '../../../fixtures/user_questions.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_compaction_outcome.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';

const _testSkill = HarnessSkill(
  name: 'test-skill',
  description: 'A skill used by the slash command tests',
  content: 'SKILL BODY',
  filePath: '/skills/test-skill/SKILL.md',
);

const _mixedCaseSkill = HarnessSkill(
  name: 'Mixed-Case',
  description: 'A skill whose directory name carries capitals',
  content: 'MIXED BODY',
  filePath: '/skills/Mixed-Case/SKILL.md',
);

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
    late JsonlSessionRepo sessionRepo;
    late List<AgentChatRequest> requests;
    late AgentWireCompletion wireCompletion;
    late List<String> foregroundCalls;
    const foregroundChannel = MethodChannel('test/agent-foreground');

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'agent_chat_notifier_test_',
      );
      storage = _MemoryLocalStorage();
      sessionRepo = JsonlSessionRepo(tempDir);
      requests = [];
      foregroundCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(foregroundChannel, (call) async {
            foregroundCalls.add(call.method);
            return null;
          });
      wireCompletion = (request) {
        requests.add(request);
        return Stream<AgentWireEvent>.fromIterable(const [
          AgentWireTextDelta('done'),
          AgentWireFinish(stopReason: StopReason.stop),
        ]);
      };
      provider = StateNotifierProvider<AgentChatNotifier, AgentChatState>((
        ref,
      ) {
        return AgentChatNotifier(
          ref,
          supportDir: tempDir,
          workspaceDir: tempDir,
          presetSkills: const [_testSkill, _mixedCaseSkill],
          sessionRepo: sessionRepo,
          completeRequest: (request) => wireCompletion(request),
        );
      });
      container = ProviderContainer(
        overrides: [
          androidForegroundTaskServiceProvider.overrideWithValue(
            AndroidForegroundTaskService(
              supported: true,
              channel: foregroundChannel,
              requestNotificationPermission: () async {},
            ),
          ),
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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(foregroundChannel, null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (final resolution in ['submit', 'abort', 'dispose']) {
      test(
        'registered question tool settles correctly on $resolution',
        () async {
          final config = container.read(promptAssistantConfigProvider.notifier);
          await config.upsertProvider(ProviderPreset.deepseek.createConfig());
          await config.upsertModel(
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
          var calls = 0;
          wireCompletion = (request) async* {
            requests.add(request);
            calls++;
            if (calls == 1) {
              yield AgentWireToolCallDone(
                id: 'ask-directions',
                name: 'ask_user_question',
                arguments: {
                  'questions': [questionJson('appearance')],
                },
              );
              yield const AgentWireFinish(stopReason: StopReason.toolUse);
            } else {
              yield const AgentWireTextDelta('采用经典造型');
              yield const AgentWireFinish(stopReason: StopReason.stop);
            }
          };
          final questionReady = Completer<void>();
          final subscription = container.listen(provider, (_, next) {
            if (next.questionRequest != null && !questionReady.isCompleted) {
              questionReady.complete();
            }
          });
          addTearDown(subscription.close);
          final notifier = container.read(provider.notifier);
          final run = notifier.send('帮我选择角色造型');
          await questionReady.future.timeout(const Duration(seconds: 5));
          expect(calls, 1);
          expect(container.read(provider).approvalRequest, isNull);
          if (resolution == 'abort') {
            await notifier.abort();
            await run;
            expect(calls, 1);
            expect(container.read(provider).questionRequest, isNull);
            return;
          }
          if (resolution == 'dispose') {
            subscription.close();
            container.invalidate(provider);
            await run;
            expect(calls, 1);
            return;
          }

          expect(
            notifier.resolveUserQuestions('stale', [
              const UserQuestionAnswer.option('classic'),
            ]),
            isFalse,
          );
          expect(
            notifier.resolveUserQuestions('ask-directions', [
              const UserQuestionAnswer.option('classic'),
            ]),
            isTrue,
          );
          await run;
          expect(calls, 2);
          expect(container.read(provider).questionRequest, isNull);
          expect(container.read(provider).status, AgentChatRunStatus.idle);
        },
      );
    }

    for (final outcome in ['success', 'error', 'cancelled', 'start_failure']) {
      test(
        'Agent holds foreground execution until response settles: $outcome',
        () async {
          final config = container.read(promptAssistantConfigProvider.notifier);
          await config.upsertProvider(ProviderPreset.deepseek.createConfig());
          await config.upsertModel(
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
          if (outcome == 'start_failure') {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(foregroundChannel, (call) async {
                  foregroundCalls.add(call.method);
                  throw PlatformException(code: 'foreground_start_failed');
                });
            await container.read(provider.notifier).send('start task');
            expect(foregroundCalls, ['start']);
            expect(requests, isEmpty);
            expect(
              container.read(provider).error,
              contains('foreground_start_failed'),
            );
            expect(container.read(provider).status, AgentChatRunStatus.idle);
            return;
          }
          final entered = Completer<void>();
          final response = Completer<void>();
          wireCompletion = (request) async* {
            expect(foregroundCalls, ['start']);
            entered.complete();
            await response.future;
            if (outcome == 'error') throw StateError('test network failure');
            yield const AgentWireTextDelta('background response');
            yield const AgentWireFinish(stopReason: StopReason.stop);
          };
          final send = container
              .read(provider.notifier)
              .send('continue in background');
          await entered.future;
          expect(foregroundCalls, ['start']);
          final cancellation = outcome == 'cancelled'
              ? container.read(provider.notifier).abort()
              : null;
          response.complete();
          await cancellation;
          await send;
          expect(foregroundCalls, ['start', 'stop']);
          final messages = container
              .read(provider)
              .messages
              .whereType<AssistantMessage>();
          if (outcome == 'error') {
            expect(
              container.read(provider).error,
              contains('test network failure'),
            );
          } else if (outcome == 'success') {
            expect(
              messages.last.content
                  .whereType<AssistantTextContent>()
                  .single
                  .text,
              'background response',
            );
          }
          expect(container.read(provider).status, AgentChatRunStatus.idle);
        },
      );
    }

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
      'resolves the selected Pi reasoning contract before dispatch',
      () async {
        final configNotifier = container.read(
          promptAssistantConfigProvider.notifier,
        );
        await configNotifier.upsertProvider(
          ProviderPreset.deepseek.createConfig(),
        );
        await configNotifier.upsertModel(
          const ModelConfig(
            providerId: 'deepseek',
            name: 'deepseek-v4-pro',
            displayName: 'DeepSeek V4 Pro',
            forTask: AssistantTaskType.chat,
          ),
        );
        await container
            .read(agentSettingsProvider.notifier)
            .setModelReference(
              const AgentModelReference(
                providerId: 'deepseek',
                model: 'deepseek-v4-pro',
              ),
            );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final notifier = container.read(provider.notifier);
        await notifier.setThinkingLevel(ThinkingLevel.high);
        await notifier.send('reason');

        expect(requests, hasLength(1));
        expect(requests.single.reasoning, 'high');
        expect(
          requests.single.reasoningRequest?.api,
          AgentReasoningApi.deepSeek,
        );
        expect(requests.single.reasoningRequest?.enabled, isTrue);
        expect(requests.single.reasoningRequest?.effort, 'high');
        expect(requests.single.maxOutputTokens, 384000);
        expect(requests.single.modelMaxOutputTokens, 384000);
        expect(
          requests.single.reasoningRequest?.preserveReasoningContent,
          isTrue,
        );
      },
    );

    test('temporary route loss preserves the session thinking level', () async {
      final configNotifier = container.read(
        promptAssistantConfigProvider.notifier,
      );
      await configNotifier.upsertProvider(
        ProviderPreset.deepseek.createConfig(),
      );
      await configNotifier.upsertModel(
        const ModelConfig(
          providerId: 'deepseek',
          name: 'deepseek-v4-pro',
          displayName: 'DeepSeek V4 Pro',
          forTask: AssistantTaskType.chat,
        ),
      );
      await container
          .read(agentSettingsProvider.notifier)
          .setModelReference(
            const AgentModelReference(
              providerId: 'deepseek',
              model: 'deepseek-v4-pro',
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final notifier = container.read(provider.notifier);
      await notifier.setThinkingLevel(ThinkingLevel.high);
      final deepSeek = container
          .read(promptAssistantConfigProvider)
          .providers
          .firstWhere((item) => item.id == 'deepseek');

      await configNotifier.upsertProvider(deepSeek.copyWith(enabled: false));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(provider).routeReady, isFalse);
      expect(container.read(provider).thinkingLevel, ThinkingLevel.high);

      await configNotifier.upsertProvider(deepSeek.copyWith(enabled: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(provider).routeReady, isTrue);
      expect(container.read(provider).thinkingLevel, ThinkingLevel.high);

      await notifier.send('still reason');
      expect(requests.single.reasoning, 'high');
    });

    test(
      'switching models refreshes supported thinking levels and corrects state',
      () async {
        final configNotifier = container.read(
          promptAssistantConfigProvider.notifier,
        );
        await configNotifier.upsertProvider(
          ProviderPreset.deepseek.createConfig(),
        );
        await configNotifier.upsertModel(
          const ModelConfig(
            providerId: 'deepseek',
            name: 'deepseek-v4-pro',
            displayName: 'DeepSeek V4 Pro',
            forTask: AssistantTaskType.chat,
          ),
        );
        await configNotifier.upsertProvider(
          ProviderPreset.gemini.createConfig(),
        );
        await configNotifier.upsertModel(
          const ModelConfig(
            providerId: 'gemini',
            name: 'gemini-1.5-pro',
            displayName: 'Gemini 1.5 Pro',
            forTask: AssistantTaskType.chat,
          ),
        );
        await container
            .read(agentSettingsProvider.notifier)
            .setModelReference(
              const AgentModelReference(
                providerId: 'deepseek',
                model: 'deepseek-v4-pro',
              ),
            );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final notifier = container.read(provider.notifier);
        await notifier.setThinkingLevel(ThinkingLevel.high);
        expect(container.read(provider).thinkingLevel, ThinkingLevel.high);

        await notifier.selectChatModel('gemini', 'gemini-1.5-pro');

        final state = container.read(provider);
        expect(state.routeReady, isTrue);
        expect(state.availableThinkingLevels, isEmpty);
        expect(state.thinkingLevel, ThinkingLevel.off);
        expect(
          container.read(agentSettingsProvider).settings.chat.modelReference,
          const AgentModelReference(
            providerId: 'gemini',
            model: 'gemini-1.5-pro',
          ),
        );
      },
    );

    test(
      'new sessions inherit and persist the current thinking level',
      () async {
        final configNotifier = container.read(
          promptAssistantConfigProvider.notifier,
        );
        await configNotifier.upsertProvider(
          ProviderPreset.deepseek.createConfig(),
        );
        await configNotifier.upsertModel(
          const ModelConfig(
            providerId: 'deepseek',
            name: 'deepseek-v4-pro',
            displayName: 'DeepSeek V4 Pro',
            forTask: AssistantTaskType.chat,
          ),
        );
        await container
            .read(agentSettingsProvider.notifier)
            .setModelReference(
              const AgentModelReference(
                providerId: 'deepseek',
                model: 'deepseek-v4-pro',
              ),
            );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final notifier = container.read(provider.notifier);
        await notifier.setThinkingLevel(ThinkingLevel.high);
        final previousSessionId = container.read(provider).activeSessionId;

        await notifier.newSession();

        final nextState = container.read(provider);
        expect(nextState.activeSessionId, isNot(previousSessionId));
        expect(nextState.thinkingLevel, ThinkingLevel.high);
        final metadata = (await sessionRepo.list()).firstWhere(
          (item) => item.id == nextState.activeSessionId,
        );
        final session = await sessionRepo.open(metadata);
        final entries = await session.findEntriesOnBranch(
          const EntryQuery(order: EntryOrder.oldestFirst),
        );
        expect(
          entries.whereType<ThinkingLevelEntry>().last.thinkingLevel,
          'high',
        );
      },
    );

    test('resumes a suspended operation instead of starting another', () async {
      final configNotifier = container.read(
        promptAssistantConfigProvider.notifier,
      );
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

      final notifier = container.read(provider.notifier);
      final suspendedSessionId = container.read(provider).activeSessionId;
      await notifier.newSession();
      final metadata = (await sessionRepo.list()).firstWhere(
        (item) => item.id == suspendedSessionId,
      );
      final suspendedSession = await sessionRepo.open(metadata);
      const suspendedRunId = 'suspended-run';
      await suspendedSession.appendRecord(
        OperationStartedRecord(
          id: suspendedRunId,
          lane: 'main',
          sourceLeafId: null,
          intent: const RunIntent(kind: RunIntentKind.run),
        ),
      );
      await suspendedSession.appendMessage(UserMessage.text('original task'));
      await suspendedSession.appendMessage(
        AssistantMessage(
          content: const [AssistantTextContent('partial answer')],
          stopReason: StopReason.stop,
        ),
      );

      await notifier.switchSession(suspendedSessionId);
      expect(container.read(provider).turns.single.status.name, 'interrupted');

      await notifier.send('continue the task');

      expect(container.read(provider).error, isEmpty);
      expect(requests, hasLength(1));
      expect(
        requests.single.messages.whereType<UserMessage>().map(
          (message) => message.text,
        ),
        ['original task', 'continue the task'],
      );
      final reopened = await sessionRepo.open(metadata);
      expect(await reopened.findOpenOperations('main'), isEmpty);
      expect(
        (await reopened.findRecords()).whereType<OperationStartedRecord>(),
        hasLength(1),
      );
    });

    test('publishes provider text deltas before the stream finishes', () async {
      await _selectChatModel(container);
      final stream = StreamController<AgentWireEvent>();
      wireCompletion = (request) {
        requests.add(request);
        return stream.stream;
      };
      final notifier = container.read(provider.notifier);
      final send = notifier.send('stream this');
      await _waitForCondition(
        () => requests.isNotEmpty,
        'Agent run did not reach the provider',
      );

      stream.add(const AgentWireTextDelta('first'));
      await _waitForCondition(
        () => container.read(provider).streamingMessage?.text == 'first',
        'First provider delta was not published',
      );
      expect(container.read(provider).workPhase, AgentChatWorkPhase.responding);

      stream
        ..add(const AgentWireTextDelta(' second'))
        ..add(const AgentWireFinish(stopReason: StopReason.stop));
      await stream.close();
      await send;

      expect(container.read(provider).streamingMessage, isNull);
      expect(
        container
            .read(provider)
            .messages
            .whereType<AssistantMessage>()
            .last
            .text,
        'first second',
      );
    });

    test('persists steering and follow-up input before delivery', () async {
      final configNotifier = container.read(
        promptAssistantConfigProvider.notifier,
      );
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

      final stream = StreamController<AgentWireEvent>();
      wireCompletion = (request) {
        requests.add(request);
        if (requests.length == 1) return stream.stream;
        return Stream<AgentWireEvent>.value(
          const AgentWireFinish(stopReason: StopReason.stop),
        );
      };
      final notifier = container.read(provider.notifier);
      final firstSend = notifier.send('start');
      await _waitForCondition(
        () => requests.isNotEmpty,
        'Agent run did not reach the provider',
      );

      await notifier.send('steer now');
      expect(
        await notifier.sendContent(const [
          UserTextContent('follow later'),
        ], followUp: true),
        isTrue,
      );

      final activeSessionId = container.read(provider).activeSessionId;
      final metadata = (await sessionRepo.list()).firstWhere(
        (item) => item.id == activeSessionId,
      );
      final activeSession = await sessionRepo.open(metadata);
      final queueRecords = (await activeSession.findRecords(
        const RecordQuery(
          type: 'queue_enqueued',
          order: EntryOrder.oldestFirst,
        ),
      )).whereType<QueueEnqueuedRecord>().toList();
      expect(queueRecords.map((record) => record.queue), [
        QueueKind.steer,
        QueueKind.followUp,
      ]);
      expect(await activeSession.getEntry(queueRecords[0].target.id), isNull);
      expect(await activeSession.getEntry(queueRecords[1].target.id), isNull);

      stream.add(const AgentWireFinish(stopReason: StopReason.stop));
      await stream.close();
      await firstSend;

      expect(requests, hasLength(3));
      final completedSession = await sessionRepo.open(metadata);
      final completedRecords = await completedSession.findRecords();
      expect(
        completedRecords.whereType<OperationStartedRecord>(),
        hasLength(1),
      );
      expect(
        completedRecords.whereType<OperationFinishedRecord>(),
        hasLength(1),
      );
      expect(
        (await completedSession.getEntry(queueRecords[0].target.id))?.id,
        queueRecords[0].target.id,
      );
      expect(
        (await completedSession.getEntry(queueRecords[1].target.id))?.id,
        queueRecords[1].target.id,
      );
    });

    test(
      'override preserves custom body and runtime context across sessions',
      () async {
        final configNotifier = container.read(
          promptAssistantConfigProvider.notifier,
        );
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
        await container
            .read(agentSettingsProvider.notifier)
            .saveCustomSystemPrompt(
              mode: AgentSystemPromptMode.override,
              value: 'EXACT_OVERRIDE',
            );

        final notifier = container.read(provider.notifier);
        final firstSessionId = container.read(provider).activeSessionId;
        await notifier.send('first');
        await notifier.newSession();
        await notifier.send('new session');
        await notifier.switchSession(firstSessionId);
        await notifier.send('restored session');

        expect(requests, hasLength(3));
        for (final request in requests) {
          expect(
            request.systemPrompt,
            startsWith('EXACT_OVERRIDE\n\n<aaalice_runtime_context>'),
          );
          expect(request.systemPrompt, contains(tempDir.path));
          expect(request.systemPrompt, contains('Web access is disabled.'));
          expect(
            request.systemPrompt,
            isNot(contains('You are the AI agent inside Aaalice')),
          );
          expect(request.systemPrompt, isNot(contains('<skills>')));
          expect(request.tools, isNotEmpty);
        }
      },
    );

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

    test(
      'edited resend forks before the old user message in main context',
      () async {
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
        expect(
          container.read(provider).messages.map((message) => message.role),
          ['user', 'assistant'],
        );
        expect(container.read(provider).sessionTransitioning, isFalse);

        final reopenedRepo = JsonlSessionRepo(tempDir);
        final reopenedMetadata = (await reopenedRepo.list()).firstWhere(
          (metadata) => metadata.id == firstId,
        );
        final reopened = await reopenedRepo.open(reopenedMetadata);
        await reopened.appendMessage(UserMessage.text('corrected request'));
        final mainBranch = await reopened.findEntriesOnBranch();
        final allEntries = await reopened.findEntries();
        final mainContextMessages = mainBranch
            .whereType<MessageEntry>()
            .map((entry) => entry.message)
            .toList(growable: false);
        expect(
          mainContextMessages.whereType<UserMessage>().map(
            (message) => message.text,
          ),
          ['corrected request', 'first request'],
        );
        expect(
          mainContextMessages.whereType<UserMessage>().map(
            (message) => message.text,
          ),
          isNot(contains('second request')),
        );
        expect(mainBranch.whereType<MessageEntry>(), hasLength(3));
        expect(allEntries.whereType<MessageEntry>(), hasLength(5));
      },
    );

    test('failed edited send can restore the original main lane', () async {
      final notifier = container.read(provider.notifier);
      final repo = JsonlSessionRepo(tempDir);
      final sessionId = container.read(provider).activeSessionId;
      final metadata = (await repo.list()).single;
      final session = await repo.open(metadata);
      await session.appendMessage(UserMessage.text('keep this request'));
      await session.appendMessage(_assistant(const Usage()));

      await notifier.newSession();
      await notifier.switchSession(sessionId);
      final checkpoint = await notifier.beginEditedMessageRewind();
      expect(checkpoint, isNotNull);
      final rewind = checkpoint!;
      expect(rewind.resources, isEmpty);
      expect(container.read(provider).messages, isEmpty);

      await notifier.restoreEditedMessageRewind(rewind);

      expect(container.read(provider).messages.map((message) => message.role), [
        'user',
        'assistant',
      ]);
      final reopened = await JsonlSessionRepo(tempDir).open(metadata);
      expect(reopened.findEntriesOnBranch(), completion(hasLength(2)));
    });

    test('a leading skill command injects the skill instructions', () async {
      final notifier = container.read(provider.notifier);
      await _selectChatModel(container);

      await notifier.send('/test-skill draw a cat');

      // The skill body leads and the typed text closes the message, so the
      // model reads the instructions before the request.
      final sent = requests.single.messages.whereType<UserMessage>().single;
      expect(sent.text, contains('<skill name="test-skill"'));
      expect(sent.text, contains('SKILL BODY'));
      expect(sent.text, endsWith('/test-skill draw a cat'));
    });

    test('a bare skill command still carries the instructions', () async {
      final notifier = container.read(provider.notifier);
      await _selectChatModel(container);

      await notifier.send('/test-skill');

      final sent = requests.single.messages.whereType<UserMessage>().single;
      expect(sent.text, contains('SKILL BODY'));
      expect(sent.text, endsWith('/test-skill'));
    });

    test('a skill command ignores the case of the directory name', () async {
      final notifier = container.read(provider.notifier);
      await _selectChatModel(container);

      await notifier.send('/mixed-case draw a cat');

      final sent = requests.single.messages.whereType<UserMessage>().single;
      expect(sent.text, contains('<skill name="Mixed-Case"'));
      expect(sent.text, contains('MIXED BODY'));
    });

    test('an unknown command is sent as plain text', () async {
      final notifier = container.read(provider.notifier);
      await _selectChatModel(container);

      await notifier.send('/not-a-skill hello');

      final sent = requests.single.messages.whereType<UserMessage>().single;
      expect(sent.text, '/not-a-skill hello');
      expect(sent.text, isNot(contains('SKILL BODY')));
    });

    test(
      'manual compaction reports that a short session has nothing to fold',
      () async {
        final notifier = container.read(provider.notifier);
        await _selectChatModel(container);
        await notifier.send('draw a cat');
        requests.clear();

        final outcome = await notifier.compactNow();

        expect(outcome, isA<AgentChatCompactionSkipped>());
        expect(
          (outcome as AgentChatCompactionSkipped).reason,
          AgentChatCompactionSkipReason.nothingToCompact,
        );
        // The whole point of the guard: summarizing an empty history would burn a
        // request and then overwrite the context with the result.
        expect(requests, isEmpty);
        expect(container.read(provider).compacting, isFalse);
      },
    );

    test('a manual context window unlocks an unplaceable model', () async {
      final notifier = container.read(provider.notifier);
      final configNotifier = container.read(
        promptAssistantConfigProvider.notifier,
      );
      await configNotifier.upsertProvider(
        const ProviderConfig(
          id: 'relay',
          name: 'Relay station',
          protocol: ProviderProtocol.openaiChatCompletions,
          baseUrl: 'https://api.my-relay.test/v1',
        ),
      );
      await configNotifier.upsertModel(
        const ModelConfig(
          providerId: 'relay',
          name: 'private-v9',
          displayName: 'Private v9',
          forTask: AssistantTaskType.chat,
        ),
      );
      final settings = container.read(agentSettingsProvider.notifier);
      await settings.setModelReference(
        const AgentModelReference(providerId: 'relay', model: 'private-v9'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Neither the host nor the model name is in the catalog, so nothing can
      // infer a window and compaction has to refuse.
      expect(container.read(provider).contextUsage.available, isFalse);
      final refused = await notifier.compactNow();
      expect(
        (refused as AgentChatCompactionSkipped).reason,
        AgentChatCompactionSkipReason.unavailable,
      );

      await settings.setContextWindowOverride(
        providerId: 'relay',
        model: 'private-v9',
        window: 64000,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final usage = container.read(provider).contextUsage;
      expect(usage.contextWindow, 64000);
      expect(usage.available, isTrue);
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

Future<void> _selectChatModel(ProviderContainer container) async {
  final configNotifier = container.read(promptAssistantConfigProvider.notifier);
  await configNotifier.upsertProvider(ProviderPreset.deepseek.createConfig());
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

// Chat can report initialized while agent settings are still loading, and
// settings reject every write until their own load finishes.
Future<void> _waitForInitialized(
  ProviderContainer container,
  StateNotifierProvider<AgentChatNotifier, AgentChatState> provider,
) async {
  await _waitForProviderState<AgentChatState>(
    container,
    provider,
    (state) => state.initialized,
    'AgentChatNotifier did not initialize',
  );
  await _waitForProviderState<AgentSettingsState>(
    container,
    agentSettingsProvider,
    (state) => state.initialized,
    'AgentSettingsNotifier did not initialize',
  );
  expect(container.read(agentSettingsProvider).error, isEmpty);
}

Future<void> _waitForProviderState<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
  bool Function(T state) isReady,
  String failureMessage,
) async {
  final ready = Completer<void>();
  final subscription = container.listen<T>(provider, (_, next) {
    if (isReady(next) && !ready.isCompleted) ready.complete();
  }, fireImmediately: true);
  try {
    await ready.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail(failureMessage),
    );
  } finally {
    subscription.close();
  }
}

Future<void> _waitForCondition(
  bool Function() condition,
  String failureMessage,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail(failureMessage);
}

Future<void> _waitForSkill(
  ProviderContainer container,
  StateNotifierProvider<AgentChatNotifier, AgentChatState> provider,
  String name,
) => _waitForProviderState<AgentChatState>(
  container,
  provider,
  (state) => state.skills.any((skill) => skill.name == name),
  'AgentChatNotifier did not inject enabled Skill $name',
);

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
