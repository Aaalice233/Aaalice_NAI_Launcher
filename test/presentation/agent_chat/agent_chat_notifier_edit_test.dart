import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/llm_types.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/agent_protocol.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('edited message checkpoint restores the persisted main lane', () async {
    final directory = await Directory.systemTemp.createTemp(
      'agent_chat_notifier_edit_',
    );
    final provider = StateNotifierProvider<AgentChatNotifier, AgentChatState>((
      ref,
    ) {
      return AgentChatNotifier(
        ref,
        supportDir: directory,
        workspaceDir: directory,
        presetSkills: const [],
        completeRequest: (_) => Stream<AgentWireEvent>.fromIterable(const [
          AgentWireFinish(stopReason: StopReason.stop),
        ]),
      );
    });
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
        secureStorageServiceProvider.overrideWithValue(_SecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: directory,
            workspaceDirectory: directory,
            environment: const {},
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    container.read(provider);
    await _waitForInitialized(container, provider);
    await _configureRoute(container);

    final notifier = container.read(provider.notifier);
    final repo = JsonlSessionRepo(directory);
    final sessionId = container.read(provider).activeSessionId;
    final metadata = (await repo.list()).single;
    final session = await repo.open(metadata);
    await session.appendMessage(UserMessage.text('original request'));
    await session.appendMessage(
      AssistantMessage(
        content: const [AssistantTextContent('original response')],
        stopReason: StopReason.stop,
      ),
    );

    await notifier.newSession();
    await notifier.switchSession(sessionId);
    expect(await notifier.prepareEditedSend(), isTrue);

    final checkpoint = await notifier.beginEditedMessageRewind();
    expect(checkpoint, isNotNull);
    expect(checkpoint!.message.text, 'original request');
    expect(container.read(provider).messages, isEmpty);

    await notifier.restoreEditedMessageRewind(checkpoint);

    expect(container.read(provider).messages.map((message) => message.role), [
      'user',
      'assistant',
    ]);
    final reopened = await JsonlSessionRepo(directory).open(metadata);
    expect(await reopened.findEntriesOnBranch(), hasLength(2));
  });
}

Future<void> _configureRoute(ProviderContainer container) async {
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
  await Future<void>.delayed(const Duration(milliseconds: 20));
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

class _MemoryStorage extends LocalStorageService {
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

class _SecureStorage extends SecureStorageService {
  @override
  Future<String?> getAgentWebAccessExaApiKey() async => null;
}
