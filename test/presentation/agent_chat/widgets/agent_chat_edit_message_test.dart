import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('only the last safe user message can enter edit mode', (
    tester,
  ) async {
    final fixture = await _pumpPanel(tester);
    addTearDown(fixture.dispose);
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
    addTearDown(fixture.dispose);
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

  testWidgets(
    'rejected edited send prepares before rewind and restores lane and draft',
    (tester) async {
      final fixture = await _pumpPanel(tester);
      addTearDown(fixture.dispose);
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
    addTearDown(fixture.dispose);
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
}

Future<void> _pressEdit(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('agent-user-message-edit-0'));
  final button = tester.widget<IconButton>(
    find.descendant(of: action, matching: find.byType(IconButton)),
  );
  button.onPressed!();
  await tester.pump();
}

Future<_Fixture> _pumpPanel(WidgetTester tester) async {
  final directory = Directory.systemTemp.createTempSync(
    'agent_chat_edit_widget_',
  );
  late _EditNotifier notifier;
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
      agentChatNotifierProvider.overrideWith((ref) {
        notifier = _EditNotifier(
          ref,
          supportDir: directory,
          workspaceDir: directory,
        );
        return notifier;
      }),
    ],
  );
  await tester.runAsync(() async {
    container.read(agentChatNotifierProvider);
    for (var attempt = 0; attempt < 200; attempt++) {
      if (container.read(agentChatNotifierProvider).initialized) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('AgentChatNotifier did not initialize');
  });
  notifier.makeReady();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 420, height: 720, child: AgentChatPanel()),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Fixture(container, directory, notifier);
}

class _Fixture {
  const _Fixture(this.container, this.directory, this.notifier);

  final ProviderContainer container;
  final Directory directory;
  final _EditNotifier notifier;

  void dispose() {
    container.dispose();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

class _EditNotifier extends AgentChatNotifier {
  _EditNotifier(
    super.ref, {
    required super.supportDir,
    required super.workspaceDir,
  }) : super(presetSkills: const []);

  bool acceptSend = false;
  final List<String> calls = [];
  List<UserContent> sentContent = const [];
  int restoreCount = 0;
  int clearComposerCount = 0;

  void makeReady() {
    state = state.copyWith(initialized: true, routeReady: true);
  }

  void showMessages(List<Message> messages) {
    state = state.copyWith(
      initialized: true,
      routeReady: true,
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
  Future<AgentChatRewindCheckpoint?> beginEditedMessageRewind() async {
    calls.add('rewind');
    state = state.copyWith(messages: const []);
    return AgentChatRewindCheckpoint(
      sessionId: state.activeSessionId,
      originalLeafId: 'old-leaf',
      message: UserMessage.text('old text'),
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
    state = state.copyWith(pendingResources: const []);
    await onAccepted?.call();
    return true;
  }

  @override
  Future<void> clearComposerText() async {
    clearComposerCount++;
    state = state.copyWith(composerText: '');
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
