import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_prompt_envelope.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('only the last safe user message can enter edit mode', (
    tester,
  ) async {
    final fixture = await _pumpPanel(tester);
    fixture.notifier.showMessages([
      UserMessage.text('older'),
      AssistantMessage(
        content: const [AssistantTextContent('older answer')],
        stopReason: StopReason.stop,
      ),
      UserMessage.text('latest'),
    ]);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('agent-user-message-edit-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-user-message-edit-2')),
      findsOneWidget,
    );

    fixture.notifier.setUnsafe(running: true);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-user-message-edit-2')),
      findsNothing,
    );
  });

  testWidgets('edit restores text, inline images, and resource references', (
    tester,
  ) async {
    final fixture = await _pumpPanel(tester);
    fixture.notifier.showMessages([_resourceMessage]);
    await tester.pump();

    await _pressEdit(tester);

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('agent-chat-input')),
    );
    expect(input.controller!.text, 'before [image1] after');
    expect(
      find.byKey(const ValueKey('agent-chat-pending-image-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-chat-pending-resource-card')),
      findsOneWidget,
    );
    expect(fixture.notifier.state.pendingResources, [_reference]);
    expect(
      find.byKey(const ValueKey('agent-chat-message-edit-header')),
      findsOneWidget,
    );
  });

  testWidgets('a stale edit action cannot bind to a replacement entry', (
    tester,
  ) async {
    final fixture = await _pumpPanel(tester);
    fixture.notifier.showMessages([UserMessage.text('original request')]);
    await tester.pump();
    final edit = _editButton(tester).onPressed!;

    fixture.notifier.showMessages([UserMessage.text('replacement request')]);
    edit();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('agent-chat-message-edit-header')),
      findsNothing,
    );
    await _pressEdit(tester);
    final input = find.byKey(const ValueKey('agent-chat-input'));
    expect(
      tester.widget<TextField>(input).controller!.text,
      'replacement request',
    );
  });

  testWidgets(
    'rejected edited send prepares before rewind and restores lane and draft',
    (tester) async {
      final fixture = await _pumpPanel(tester);
      fixture.notifier
        ..showMessages([_resourceMessage])
        ..acceptSend = false;
      await tester.pump();
      await _pressEdit(tester);
      await tester.enterText(
        find.byKey(const ValueKey('agent-chat-input')),
        'corrected [image1]',
      );

      await tester.tap(find.byKey(const ValueKey('agent-chat-send')));
      await tester.pump();

      expect(fixture.notifier.calls, ['prepare', 'rewind', 'send', 'restore']);
      expect(fixture.notifier.restoreCount, 1);
      expect(fixture.notifier.state.messages, [_resourceMessage]);
      expect(fixture.notifier.state.pendingResources, [_reference]);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-chat-input')))
            .controller!
            .text,
        'corrected [image1]',
      );
      expect(
        find.byKey(const ValueKey('agent-chat-message-edit-header')),
        findsOneWidget,
      );
      expect(fixture.notifier.clearComposerCount, 0);
    },
  );

  testWidgets('accepted edited send uses the reconstructed content', (
    tester,
  ) async {
    final fixture = await _pumpPanel(tester);
    fixture.notifier
      ..showMessages([_resourceMessage])
      ..acceptSend = true;
    await tester.pump();
    await _pressEdit(tester);
    await tester.enterText(
      find.byKey(const ValueKey('agent-chat-input')),
      'corrected [image1]',
    );

    await tester.tap(find.byKey(const ValueKey('agent-chat-send')));
    await tester.pump();

    expect(fixture.notifier.calls, ['prepare', 'rewind', 'send']);
    expect(fixture.notifier.restoreCount, 0);
    expect(fixture.notifier.sentContent, hasLength(2));
    expect(fixture.notifier.sentContent.first, isA<UserTextContent>());
    expect(
      (fixture.notifier.sentContent.first as UserTextContent).text.trim(),
      'corrected',
    );
    expect(fixture.notifier.sentContent.last, isA<UserImageContent>());
    expect(fixture.notifier.clearComposerCount, 1);
    expect(
      find.byKey(const ValueKey('agent-chat-message-edit-header')),
      findsNothing,
    );
  });

  testWidgets(
    'sending after a muted session switch appends to the newest turn',
    (tester) async {
      final fixture = await _pumpPanel(tester);
      final notifier = fixture.notifier..acceptSend = true;
      final original = UserMessage.text('original request');
      final originalReply = AssistantMessage(
        content: const [AssistantTextContent('original response')],
        stopReason: StopReason.stop,
      );
      final newer = UserMessage.text('request from floating panel');
      final newerReply = AssistantMessage(
        content: const [AssistantTextContent('response from floating panel')],
        stopReason: StopReason.stop,
      );
      notifier.showMessages([original, originalReply], sessionId: 'a');
      await tester.pump();
      await _pressEdit(tester);
      final editHeader = find.byKey(
        const ValueKey('agent-chat-message-edit-header'),
      );
      expect(editHeader, findsOneWidget);

      fixture.tickerEnabled.value = false;
      await tester.pump();
      notifier.showMessages([
        UserMessage.text('other session'),
      ], sessionId: 'b');
      await tester.pump();
      notifier.showMessages([original, originalReply], sessionId: 'a');
      await tester.pump();
      notifier.showMessages([original, originalReply, newer, newerReply]);
      await tester.pump();
      fixture.tickerEnabled.value = true;
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('agent-chat-input')),
        'next request',
      );
      await tester.tap(find.byKey(const ValueKey('agent-chat-send')));
      await tester.pump();

      expect(notifier.calls, ['send']);
      expect(notifier.state.messages, [
        original,
        originalReply,
        newer,
        newerReply,
        isA<UserMessage>().having(
          (message) => message.text,
          'text',
          'next request',
        ),
      ]);
      expect(editHeader, findsNothing);
    },
  );

  testWidgets(
    'an attachment whose reference was deleted from the text is still sent',
    (tester) async {
      final fixture = await _pumpPanel(tester);
      fixture.notifier
        ..showMessages([_resourceMessage])
        ..acceptSend = true;
      await tester.pump();
      await _pressEdit(tester);
      await tester.enterText(
        find.byKey(const ValueKey('agent-chat-input')),
        'only text now',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('agent-chat-pending-image-card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('agent-chat-send')));
      await tester.pump();

      expect(fixture.notifier.sentContent, hasLength(2));
      expect(
        (fixture.notifier.sentContent.first as UserTextContent).text,
        'only text now',
      );
      final image = fixture.notifier.sentContent.last as UserImageContent;
      expect(image.image.source.bytes, _pngBytes);
    },
  );
}

IconButton _editButton(WidgetTester tester) {
  final action = find.byKey(const ValueKey('agent-user-message-edit-0'));
  return tester.widget<IconButton>(
    find.descendant(of: action, matching: find.byType(IconButton)),
  );
}

Future<void> _pressEdit(WidgetTester tester) async {
  _editButton(tester).onPressed!();
  await tester.pump();
}

Future<({_EditNotifier notifier, ValueNotifier<bool> tickerEnabled})>
_pumpPanel(WidgetTester tester) async {
  final notifier = _EditNotifier();
  final tickerEnabled = ValueNotifier(true);
  addTearDown(tickerEnabled.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
        agentChatNotifierProvider.overrideWith(() => notifier),
        agentSettingsProvider.overrideWith(_AgentSettings.new),
        promptAssistantConfigProvider.overrideWith(_AssistantConfig.new),
        webAccessConfigProvider.overrideWith(_WebAccessConfig.new),
        imageGenerationNotifierProvider.overrideWith(_IdleGeneration.new),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: tickerEnabled,
            builder: (context, enabled, panel) =>
                TickerMode(enabled: enabled, child: panel!),
            child: const SizedBox(
              width: 420,
              height: 720,
              child: AgentChatPanel(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (notifier: notifier, tickerEnabled: tickerEnabled);
}

class _EditNotifier extends AgentChatNotifier {
  bool acceptSend = false;
  final List<String> calls = [];
  final _entryIds = Map<Message, String>.identity();
  List<UserContent> sentContent = const [];
  int restoreCount = 0;
  int clearComposerCount = 0;

  @override
  AgentChatState build() =>
      const AgentChatState(initialized: true, routeReady: true);

  @override
  Future<void> ensureInitialized() async {}

  @override
  MessageEntry? get lastVisibleUserEntry {
    final message = state.messages.reversed
        .where(isVisualUserMessage)
        .firstOrNull;
    if (message == null) return null;
    return MessageEntry(
      id: _entryIds.putIfAbsent(message, () => 'entry-${_entryIds.length}'),
      message: message,
    );
  }

  void showMessages(List<Message> messages, {String? sessionId}) {
    state = state.copyWith(
      activeSessionId: sessionId,
      messages: messages,
      status: AgentChatRunStatus.idle,
      pendingResources: const [],
      queuedMessages: const [],
    );
  }

  void setUnsafe({required bool running}) {
    state = state.copyWith(
      status: running ? AgentChatRunStatus.running : AgentChatRunStatus.idle,
    );
  }

  @override
  Future<void> addPendingResource(AgentChatResourceReference reference) async {
    state = state.copyWith(
      pendingResources: [...state.pendingResources, reference],
    );
  }

  @override
  Future<bool> validatePendingResourcesForSend() async => true;

  @override
  Future<ResolvedAgentResource?> resolveResourcePreview(
    AgentChatResourceReference reference,
  ) async => ResolvedAgentResource(
    reference: reference,
    label: reference.display['name'] ?? reference.resourceId,
    bytes: _pngBytes,
  );

  @override
  Future<bool> prepareEditedSend() async {
    calls.add('prepare');
    return true;
  }

  @override
  Future<AgentChatRewindCheckpoint?> beginEditedMessageRewind(
    String entryId,
  ) async {
    calls.add('rewind');
    final index = state.messages.lastIndexWhere(isVisualUserMessage);
    final message = visibleUserMessage(state.messages[index])!;
    state = state.copyWith(messages: state.messages.take(index).toList());
    return AgentChatRewindCheckpoint(
      sessionId: state.activeSessionId,
      originalLeafId: 'old-leaf',
      message: message,
      resources: const [],
    );
  }

  @override
  Future<void> restoreEditedMessageRewind(
    AgentChatRewindCheckpoint checkpoint,
  ) async {
    calls.add('restore');
    restoreCount++;
    state = state.copyWith(
      messages: [_resourceMessage],
      pendingResources: [_reference],
    );
  }

  @override
  Future<bool> sendContent(
    List<UserContent> content, {
    bool followUp = false,
    Future<void> Function()? onAccepted,
  }) async {
    calls.add('send');
    sentContent = List.of(content);
    if (!acceptSend) return false;
    state = state.copyWith(
      messages: [
        ...state.messages,
        UserMessage(content: content),
      ],
      pendingResources: const [],
    );
    await onAccepted?.call();
    return true;
  }

  @override
  Future<void> clearComposerText() async {
    clearComposerCount++;
    state = state.copyWith(composerText: '');
  }
}

class _AgentSettings extends AgentSettingsNotifier {
  @override
  AgentSettingsState build() => const AgentSettingsState(initialized: true);
}

class _AssistantConfig extends PromptAssistantConfigNotifier {
  @override
  PromptAssistantConfigState build() => PromptAssistantConfigState.defaults();
}

class _WebAccessConfig extends WebAccessConfigNotifier {
  @override
  WebAccessConfigState build() => const WebAccessConfigState(initialized: true);
}

class _IdleGeneration extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
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

final _reference = AgentChatResourceReference(
  kind: AgentChatResourceKind.generatedImage,
  source: 'generation_history',
  resourceId: 'image-166',
  display: const {'name': 'Issue 166 image'},
);

final _resourceMessage = HarnessCustomMessage(
  customType: 'agentResourcePrompt',
  display: true,
  timestamp: 166,
  blockContent: [
    const UserTextContent(
      '<agent-resource-references>internal</agent-resource-references>',
    ),
    const UserTextContent('before'),
    UserImageContent(
      ImageContent(
        source: ImageSource.base64(
          mimeType: 'image/png',
          base64Data: base64Encode(_pngBytes),
        ),
      ),
    ),
    const UserTextContent(' after'),
  ],
  details: {
    'visibleContentOffset': 1,
    'references': [AgentChatResourceReferenceCodec.encodeJsonMap(_reference)],
  },
);

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=',
);
