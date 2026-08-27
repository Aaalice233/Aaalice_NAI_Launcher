import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart';
import 'package:nai_launcher/core/agent/llm_types.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';

void main() {
  group('agent tool permission policy', () {
    test('confirmation mode asks only for sensitive actions', () {
      const mode = AgentPermissionMode.askBeforeSensitiveActions;

      for (final tool in [
        'set_positive_prompt',
        'set_negative_prompt',
        'get_recent_images',
        'get_generation_status',
        'add_character',
      ]) {
        expect(
          agentToolPermissionPolicyFor(mode, tool),
          AgentToolPermissionPolicy.allow,
          reason: tool,
        );
      }
      expect(
        agentToolPermissionPolicyFor(mode, 'remove_character'),
        AgentToolPermissionPolicy.ask,
      );
    });

    test('safe blocks and full access allows sensitive actions', () {
      expect(
        agentToolPermissionPolicyFor(AgentPermissionMode.safe, 'read'),
        AgentToolPermissionPolicy.block,
      );
      expect(
        agentToolPermissionPolicyFor(
          AgentPermissionMode.fullAccess,
          'remove_character',
        ),
        AgentToolPermissionPolicy.allow,
      );
    });
  });

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
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
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
