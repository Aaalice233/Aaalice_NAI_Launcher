import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_chat_shared_widgets.dart';
import 'package:nai_launcher/core/windowing/agent_window_protocol.dart';
import 'package:nai_launcher/core/windowing/agent_window_shell.dart';
import 'package:nai_launcher/core/windowing/agent_window_shell_widgets.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

void main() {
  testWidgets('secondary shell sends composer and session commands', (
    tester,
  ) async {
    final bridge = _FakeBridge();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).last, 'hello');
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      bridge.commands.any(
        (entry) => entry.$1 == 'updateComposer' && entry.$2?['text'] == 'hello',
      ),
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(
      bridge.commands.any(
        (entry) => entry.$1 == 'sendText' && entry.$2?['text'] == 'hello',
      ),
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
    expect(bridge.commands.any((entry) => entry.$1 == 'newSession'), isTrue);
  });

  testWidgets('secondary shell restores composer after send failure', (
    tester,
  ) async {
    final bridge = _FakeBridge()..failSend = true;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).last, 'keep me');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('keep me'), findsOneWidget);
    expect(find.textContaining('send failed'), findsOneWidget);
  });

  testWidgets('secondary session picker searches and switches sessions', (
    tester,
  ) async {
    final bridge = _FakeBridge()
      ..snapshot = const AgentWindowSnapshot(
        revision: 6,
        payload: {
          'ready': true,
          'initialized': true,
          'routeReady': true,
          'activeSessionId': 'first',
          'sessions': [
            {'id': 'first', 'name': 'First chat'},
            {'id': 'target', 'name': 'Reference planning'},
          ],
          'messages': [],
          'activities': [],
          'resources': [],
          'composerText': '',
          'routeLabel': 'Default',
          'permissionMode': 'safe',
          'webAccessEnabled': false,
        },
      );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-window-session-picker')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agent-chat-session-search')),
      'reference',
    );
    await tester.pump();
    // The active title remains in the header; the filtered menu row is gone.
    expect(find.text('First chat'), findsOneWidget);
    final target = find.text('Reference planning');
    expect(target, findsOneWidget);
    await tester.tap(target);
    await tester.pump();

    expect(
      bridge.commands.any(
        (entry) => entry.$1 == 'switchSession' && entry.$2?['id'] == 'target',
      ),
      isTrue,
    );
  });

  testWidgets('secondary renames and deletes the active session', (
    tester,
  ) async {
    final bridge = _FakeBridge();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-window-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Renamed session');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(
      bridge.commands.any(
        (entry) =>
            entry.$1 == 'renameSession' &&
            entry.$2?['id'] == 'session-a' &&
            entry.$2?['name'] == 'Renamed session',
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('agent-window-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(
      bridge.commands.any(
        (entry) =>
            entry.$1 == 'deleteSession' && entry.$2?['id'] == 'session-a',
      ),
      isTrue,
    );
  });

  testWidgets('secondary shell blocks sending unavailable resources', (
    tester,
  ) async {
    final bridge = _FakeBridge()
      ..snapshot = const AgentWindowSnapshot(
        revision: 2,
        payload: {
          'ready': true,
          'initialized': true,
          'routeReady': true,
          'sessions': [],
          'messages': [],
          'activities': [],
          'resources': [
            {
              'encoded': '{}',
              'label': 'missing image',
              'kind': 'local_image',
              'unavailable': true,
            },
          ],
          'composerText': '',
          'routeLabel': 'Default',
          'permissionMode': 'safe',
          'webAccessEnabled': false,
        },
      );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).last, 'do not send');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(bridge.commands.where((entry) => entry.$1 == 'sendText'), isEmpty);
  });

  testWidgets(
    'secondary shell locks session and send controls while switching',
    (tester) async {
      final bridge = _FakeBridge()
        ..snapshot = const AgentWindowSnapshot(
          revision: 7,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'sessionTransitioning': true,
            'sessionContentLoading': true,
            'activeSessionId': 'session-a',
            'sessions': [
              {'id': 'session-a', 'name': 'Session A'},
            ],
            'messages': [],
            'activities': [],
            'resources': [],
            'composerText': 'wait',
            'routeLabel': 'Default',
            'activeProviderId': 'openai',
            'activeModel': 'gpt-5',
            'modelOptions': [],
            'permissionMode': 'safe',
            'webAccessEnabled': false,
          },
        );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => buildAgentWindowBridgeShell(context, bridge),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('agent-window-session-loading')),
        findsOneWidget,
      );
      final send = tester.widget<IconButton>(
        find.byKey(const ValueKey('agent-window-send')),
      );
      expect(send.onPressed, isNull);
      await tester.tap(find.byIcon(Icons.add_comment_outlined));
      await tester.pump();
      expect(
        bridge.commands.where((entry) => entry.$1 == 'newSession'),
        isEmpty,
      );
    },
  );

  testWidgets('secondary shell exposes model and reasoning selection', (
    tester,
  ) async {
    final bridge = _FakeBridge();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-window-thinking')));
    await tester.pumpAndSettle();
    expect(find.text('High'), findsOneWidget);
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();

    expect(
      bridge.commands.any(
        (entry) =>
            entry.$1 == 'setThinkingLevel' && entry.$2?['value'] == 'high',
      ),
      isTrue,
    );
  });

  testWidgets(
    'secondary shell reserves session header and folds structured tool details',
    (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final bridge = _FakeBridge()
        ..snapshot = const AgentWindowSnapshot(
          revision: 4,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'sessions': [
              {'id': 'session-a', 'name': 'Session A'},
            ],
            'activeSessionId': 'session-a',
            'messages': [
              {'role': 'user', 'text': 'first visible message'},
              {
                'role': 'tool',
                'toolCallId': 'tool-a',
                'toolName': 'web_search',
                'text':
                    '{"ok":true,"message":"Found two useful pages","items":[1,2]}',
                'details': {'query': 'cats', 'page': 1},
              },
              {'role': 'assistant', 'text': 'final answer'},
            ],
            'activities': [],
            'resources': [],
            'composerText': '',
            'routeLabel': 'Default',
            'activeProviderId': 'openai',
            'activeModel': 'gpt-5',
            'modelOptions': [],
            'permissionMode': 'safe',
            'webAccessEnabled': false,
          },
        );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => buildAgentWindowBridgeShell(context, bridge),
          ),
        ),
      );
      await tester.pump();

      final selector = find.byKey(
        const ValueKey('agent-window-session-picker'),
      );
      final firstMessage = find.text('first visible message');
      expect(selector, findsOneWidget);
      expect(firstMessage, findsOneWidget);
      expect(
        tester.getTopLeft(firstMessage).dy,
        greaterThan(tester.getBottomLeft(selector).dy),
      );
      expect(find.text('Found two useful pages'), findsOneWidget);
      expect(find.textContaining('"items"'), findsNothing);
      expect(find.byKey(const ValueKey('agent-window-send')), findsOneWidget);
      final retry = find.byKey(
        const ValueKey('agent-window-retry-last-message'),
      );
      expect(retry, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(retry);
      expect(
        bridge.commands.any((entry) => entry.$1 == 'retryLastMessage'),
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('agent-window-tool-tool-a')));
      await tester.pumpAndSettle();
      expect(find.textContaining('"items"'), findsOneWidget);
      expect(find.textContaining('"query"'), findsOneWidget);
      final detailCopy = find.descendant(
        of: find.byKey(const ValueKey('agent-window-tool-tool-a')),
        matching: find.byKey(const ValueKey('agent-tool-detail-copy')),
      );
      await tester.ensureVisible(detailCopy);
      await tester.pump();
      await tester.tap(detailCopy);
      await tester.pump();
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'secondary follows initial history and hides retry while running at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(300, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _FakeBridge()
        ..snapshot = AgentWindowSnapshot(
          revision: 8,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'running': true,
            'sessions': const [
              {'id': 'session-a', 'name': 'Session A'},
            ],
            'activeSessionId': 'session-a',
            'messages': [
              for (var index = 0; index < 30; index++) ...[
                {'role': 'user', 'text': 'question $index'},
                {'role': 'assistant', 'text': 'answer $index'},
              ],
            ],
            'activities': const [
              {
                'toolCallId': 'running-search',
                'toolName': 'web_search',
                'status': 'running',
                'content': '{"message":"Searching now"}',
                'args': {'query': 'cats', 'limit': 20},
              },
              {
                'toolCallId': 'completed-search',
                'toolName': 'web_search',
                'status': 'completed',
                'content': '{"message":"Done"}',
                'args': <String, Object?>{},
              },
            ],
            'resources': const [],
            'composerText': '',
            'routeLabel': 'Default',
            'activeProviderId': 'openai',
            'activeModel': 'provider/model-with-a-very-long-name',
            'modelOptions': const [],
            'permissionMode': 'safe',
            'webAccessEnabled': false,
          },
        );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(300, 700),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Builder(
              builder: (context) =>
                  buildAgentWindowBridgeShell(context, bridge),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('answer 29'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-window-retry-last-message')),
        findsNothing,
      );
      final activity = find.byKey(
        const ValueKey('agent-window-tool-activity-running-search'),
      );
      expect(activity, findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('agent-window-tool-activity-completed-search'),
        ),
        findsNothing,
      );
      await tester.tap(activity);
      await tester.pump();
      expect(find.textContaining('"query"'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'secondary keeps streaming queue approval resources and context usable at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _FakeBridge()
        ..snapshot = const AgentWindowSnapshot(
          revision: 10,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'running': true,
            'workPhase': 'awaitingApproval',
            'sessions': [
              {'id': 'session-a', 'name': 'Production planning session'},
            ],
            'activeSessionId': 'session-a',
            'messages': [
              {
                'role': 'assistant',
                'text': 'I am preparing the requested operation.',
                'timestamp': 1710000000000,
                'live': true,
              },
            ],
            'activities': [],
            'resources': [
              {
                'encoded': '{"kind":"file"}',
                'resourceId': 'reference-1',
                'display': {'name': 'reference-image.png'},
              },
            ],
            'queue': [
              {
                'kind': 'followUp',
                'id': 'queued-1',
                'text': 'Explain the result when it is ready.',
                'editable': true,
              },
            ],
            'approval': {
              'toolCallId': 'approval-1',
              'toolName': 'submit_generation',
              'estimatedAnlas': 12,
            },
            'contextUsage': {'totalTokens': 43500},
            'contextWindow': 128000,
            'composerText': 'queued instruction',
            'activeProviderId': 'openai',
            'activeModel': 'deepseek-v4-flash-vision-exp',
            'modelOptions': [],
            'permissionMode': 'askBeforeSensitiveActions',
            'webAccessEnabled': true,
          },
        );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 820),
              textScaler: TextScaler.linear(1.2),
            ),
            child: Builder(
              builder: (context) =>
                  buildAgentWindowBridgeShell(context, bridge),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AI'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-chat-approval-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-window-resource-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-window-queue-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-chat-context-indicator')),
        findsOneWidget,
      );
      expect(find.text('DeepSeek v4 flash'), findsOneWidget);
      expect(find.textContaining('deeps...'), findsNothing);
      final actions = tester.getRect(
        find.byKey(const ValueKey('agent-window-composer-actions')),
      );
      final settings = tester.getRect(
        find.byKey(const ValueKey('agent-window-composer-settings')),
      );
      final send = tester.getRect(
        find.byKey(const ValueKey('agent-window-send')),
      );
      expect(actions.bottom, lessThanOrEqualTo(settings.top));
      expect(send.right, closeTo(actions.right, 1));
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.queue_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      expect(bridge.commands.any((entry) => entry.$1 == 'stop'), isTrue);
    },
  );

  testWidgets(
    'secondary composer expands and preserves text selection and focus',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(520, 900);
      final bridge = _FakeBridge();
      bridge.snapshot = AgentWindowSnapshot(
        revision: 2,
        payload: {...bridge.snapshot.payload, 'running': true},
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => buildAgentWindowBridgeShell(context, bridge),
          ),
        ),
      );
      await tester.pump();

      final input = find.byKey(const ValueKey('agent-window-composer-input'));
      final editor = find.byKey(const ValueKey('agent-window-composer-editor'));
      final expand = find.byKey(const ValueKey('agent-window-composer-expand'));
      expect(
        tester.widget<TextField>(input).minLines,
        AgentChatComposerLayout.defaultMinLines,
      );
      await tester.enterText(input, 'detached draft');
      final controller = tester.widget<TextField>(input).controller!;
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 8,
      );
      final collapsedHeight = tester.getSize(editor).height;
      final stop = find.byIcon(Icons.stop_rounded);
      expect(stop, findsOneWidget);
      expect(tester.getRect(stop).overlaps(tester.getRect(expand)), isFalse);

      await tester.tap(expand);
      await tester.pump();

      expect(tester.widget<TextField>(input).expands, isTrue);
      expect(tester.getSize(editor).height, greaterThan(collapsedHeight));
      expect(controller.text, 'detached draft');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 8),
      );
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      expect(find.bySemanticsLabel(RegExp('^Collapse')), findsOneWidget);

      await tester.tap(expand);
      await tester.pump();
      expect(tester.widget<TextField>(input).expands, isFalse);
      expect(controller.text, 'detached draft');
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('secondary expanded composer fits 320/520 widths with IME', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final bridge = _FakeBridge();

    for (final width in const [320.0, 520.0]) {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              viewInsets: const EdgeInsets.only(bottom: 260),
            ),
            child: Builder(
              builder: (context) =>
                  buildAgentWindowBridgeShell(context, bridge),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('agent-window-composer-expand')),
      );
      await tester.pump();

      final actions = find.byKey(
        const ValueKey('agent-window-composer-actions'),
      );
      expect(actions, findsOneWidget);
      expect(find.byKey(const ValueKey('agent-window-send')), findsOneWidget);
      expect(
        tester.getBottomRight(actions).dy,
        lessThanOrEqualTo(440),
        reason: 'toolbar hidden by IME at width=$width',
      );
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('secondary header and composer remain overflow-free by width', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final bridge = _FakeBridge();

    for (final width in const [480.0, 600.0, 840.0, 1180.0, 1600.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(2),
            ),
            child: Builder(
              builder: (context) =>
                  buildAgentWindowBridgeShell(context, bridge),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('agent-window-session-picker')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('agent-window-send')), findsOneWidget);
      if (width >= 1320) {
        expect(find.text('New chat'), findsOneWidget);
        expect(find.text('More actions'), findsOneWidget);
        expect(find.text('Always on top'), findsOneWidget);
        expect(find.text('Dock back to the main window'), findsOneWidget);
      }
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets(
    'secondary reserves a turn gutter and prioritizes header actions at 520 and 800',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final now = DateTime.now().millisecondsSinceEpoch;
      final bridge = _FakeBridge()
        ..snapshot = AgentWindowSnapshot(
          revision: 30,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'sessions': const [
              {'id': 'session-a', 'name': 'A long production session title'},
            ],
            'activeSessionId': 'session-a',
            'timeline': [
              {
                'id': 'turn-a',
                'status': 'completed',
                'startedAt': now - 2000,
                'completedAt': now - 1000,
                'durationMs': 1000,
              },
              {
                'id': 'turn-b',
                'status': 'completed',
                'startedAt': now - 1000,
                'completedAt': now,
                'durationMs': 1000,
              },
            ],
            'messages': const [
              {'role': 'user', 'text': 'first turn', 'turnId': 'turn-a'},
              {'role': 'assistant', 'text': 'first answer', 'turnId': 'turn-a'},
              {'role': 'user', 'text': 'second turn', 'turnId': 'turn-b'},
              {
                'role': 'assistant',
                'text': 'second answer',
                'turnId': 'turn-b',
              },
            ],
            'activities': const [],
            'resources': const [],
            'composerText': '',
            'permissionMode': 'safe',
            'webAccessEnabled': false,
          },
        );

      for (final width in const [520.0, 800.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) =>
                  buildAgentWindowBridgeShell(context, bridge),
            ),
          ),
        );
        await tester.pump();

        final rail = tester.getRect(
          find.byKey(const ValueKey('agent-window-turn-gutter-turn-a')),
        );
        final message = tester.getRect(find.text('first turn'));
        expect(rail.right, lessThan(message.left), reason: 'width $width');
        final picker = tester.getRect(
          find.byKey(const ValueKey('agent-window-session-picker')),
        );
        final dock = tester.getRect(find.byIcon(Icons.call_received));
        expect(picker.right, lessThanOrEqualTo(dock.left));
        expect(
          find.byKey(const ValueKey('agent-window-more-actions')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }

      tester.view.physicalSize = const Size(520, 900);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-window-more-actions')));
      await tester.pumpAndSettle();
      expect(find.text('New chat'), findsOneWidget);
      expect(find.text('Always on top'), findsOneWidget);
    },
  );

  testWidgets(
    'secondary deduplicates work trails, allows manual collapse, and hides raw failure summaries',
    (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final bridge = _FakeBridge()
        ..snapshot = AgentWindowSnapshot(
          revision: 31,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'running': true,
            'sessions': const [],
            'timeline': [
              {'id': 'live-turn', 'status': 'running', 'startedAt': now - 4000},
              {'id': 'live-turn', 'status': 'running', 'startedAt': now - 4000},
            ],
            'messages': const [
              {
                'role': 'user',
                'text': 'generate safely',
                'turnId': 'live-turn',
              },
              {
                'role': 'tool',
                'toolCallId': 'generation-failure',
                'toolName': 'submit_generation',
                'text':
                    'API_ERROR RequestOptions validateStatus provider failed with HTTP 400 private body',
                'isError': true,
                'turnId': 'live-turn',
              },
            ],
            'activities': const [],
            'resources': const [],
            'composerText': '',
            'permissionMode': 'safe',
            'webAccessEnabled': false,
          },
        );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => buildAgentWindowBridgeShell(context, bridge),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Working for'), findsOneWidget);
      expect(find.textContaining('RequestOptions'), findsNothing);
      expect(find.textContaining('HTTP 400'), findsOneWidget);
      final header = find.byKey(
        const ValueKey('agent-window-turn-work-header-live-turn'),
      );
      await tester.tap(header);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('agent-window-tool-generation-failure')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('secondary uses canonical ask permission mode value', (
    tester,
  ) async {
    final commands = <(String, Map<String, Object?>)>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentWindowPermissionModeButton(
            payload: const {'permissionMode': 'askBeforeSensitiveActions'},
            sendCommand: (name, payload) async {
              commands.add((name, payload));
              return null;
            },
          ),
        ),
      ),
    );

    expect(find.text('Ask'), findsOneWidget);
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask').last);
    await tester.pumpAndSettle();

    expect(commands, hasLength(1));
    expect(commands.single.$1, 'setPermissionMode');
    expect(commands.single.$2, {'value': 'askBeforeSensitiveActions'});
  });

  testWidgets('secondary approval response carries its tool call id', (
    tester,
  ) async {
    final bridge = _FakeBridge()
      ..snapshot = const AgentWindowSnapshot(
        revision: 4,
        payload: {
          'ready': true,
          'initialized': true,
          'routeReady': true,
          'sessions': [],
          'messages': [],
          'activities': [],
          'resources': [],
          'composerText': '',
          'routeLabel': 'Default',
          'permissionMode': 'fullAccess',
          'webAccessEnabled': false,
          'approval': {
            'toolCallId': 'charge-1',
            'toolName': 'submit_generation',
            'estimatedAnlas': 3,
            'args': {'prompt': 'restricted approval payload', 'count': 1},
          },
        },
      );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-chat-approval-details')));
    await tester.pumpAndSettle();
    expect(find.textContaining('restricted approval payload'), findsOneWidget);
    await tester.tap(find.text('Allow once'));
    await tester.pump();

    final approval = bridge.commands.singleWhere(
      (entry) => entry.$1 == 'resolveApproval',
    );
    expect(approval.$2, {'toolCallId': 'charge-1', 'value': true});
  });

  testWidgets('secondary failed tool exposes details and retry', (
    tester,
  ) async {
    final bridge = _FakeBridge()
      ..snapshot = const AgentWindowSnapshot(
        revision: 11,
        payload: {
          'ready': true,
          'initialized': true,
          'routeReady': true,
          'sessions': [],
          'messages': [
            {'role': 'user', 'text': 'try the operation'},
            {
              'role': 'tool',
              'toolCallId': 'failed-tool',
              'toolName': 'submit_generation',
              'text': 'network response interrupted',
              'isError': true,
              'details': {'phase': 'read_response'},
            },
          ],
          'activities': [],
          'resources': [],
          'composerText': '',
          'permissionMode': 'safe',
          'webAccessEnabled': false,
        },
      );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('agent-window-tool-failed-tool')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('read_response'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('agent-window-tool-retry-failed-tool')),
    );
    await tester.pump();
    expect(
      bridge.commands.any((entry) => entry.$1 == 'retryLastMessage'),
      isTrue,
    );
  });

  testWidgets('secondary renders IPC image assets and survives corrupt data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bridge = _FakeBridge()
      ..snapshot = const AgentWindowSnapshot(
        revision: 3,
        payload: {
          'ready': true,
          'initialized': true,
          'routeReady': true,
          'sessions': [],
          'imageAssets': {
            'image-1': {'base64': _oneByOnePngBase64},
          },
          'messages': [
            {
              'role': 'user',
              'text': 'look',
              'images': [
                {'assetId': 'image-1'},
              ],
            },
            {
              'role': 'assistant',
              'text':
                  'preview ![dot](data:image/png;base64,$_oneByOnePngBase64)',
            },
            {
              'role': 'tool',
              'toolName': 'generate_image',
              'text': 'broken preview',
              'images': [
                {'assetId': 'image-1'},
                {'base64': '***'},
              ],
            },
          ],
          'activities': [],
          'resources': [],
          'composerText': '',
          'routeLabel': 'Default',
          'permissionMode': 'safe',
          'webAccessEnabled': false,
        },
      );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('look'), findsOneWidget);
    expect(find.byType(AgentChatMarkdownImage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    final imageCard = find.ancestor(
      of: find.byType(Image).first,
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(imageCard.first);
    await tester.pumpAndSettle();
    await tester.tap(imageCard.first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final imageCountBeforeToolExpansion = tester
        .widgetList<Image>(find.byType(Image))
        .length;
    await tester.tap(
      find.byKey(const ValueKey('agent-window-tool-generate_image')),
    );
    await tester.pump();
    expect(
      tester.widgetList<Image>(find.byType(Image)).length,
      greaterThan(imageCountBeforeToolExpansion),
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets(
    'secondary projects timeline turns and pages retained history without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now().millisecondsSinceEpoch;
      final bridge = _FakeBridge()
        ..snapshot = AgentWindowSnapshot(
          revision: 20,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'running': true,
            'sessions': const [],
            'timeline': [
              for (var index = 0; index < 7; index++)
                {
                  'id': 'turn-$index',
                  'status': 'completed',
                  'firstSeq': index * 2,
                  'lastSeq': index * 2 + 1,
                  'startedAt': now - 5000,
                  'completedAt': now - 4000,
                  'durationMs': 1000,
                  'items': const [],
                },
              {
                'id': 'turn-live',
                'status': 'running',
                'firstSeq': 20,
                'lastSeq': 22,
                'startedAt': now - 3000,
                'items': const [],
              },
            ],
            'history': const {'hasEarlier': true},
            'messages': [
              for (var index = 0; index < 7; index++) ...[
                {
                  'role': 'user',
                  'text': 'question $index',
                  'turnId': 'turn-$index',
                },
                {
                  'role': 'assistant',
                  'text': 'answer $index',
                  'turnId': 'turn-$index',
                },
              ],
              const {
                'role': 'user',
                'text': 'live question',
                'turnId': 'turn-live',
              },
              const {
                'role': 'assistant',
                'text': 'Checking the repository',
                'thinking': 'Inspecting relevant files',
                'stopReason': 'toolUse',
                'turnId': 'turn-live',
                'toolCalls': [
                  {
                    'id': 'call-1',
                    'name': 'read',
                    'args': {'path': 'safe/path.dart'},
                  },
                ],
              },
              const {
                'role': 'tool',
                'toolCallId': 'call-1',
                'toolName': 'read',
                'text': 'A very long persisted result that stays summarized',
                'details': {'lines': 120},
                'turnId': 'turn-live',
              },
              const {
                'role': 'assistant',
                'text': 'Final streaming answer',
                'live': true,
              },
            ],
            'activities': const [
              {
                'toolCallId': 'call-1',
                'toolName': 'read',
                'status': 'running',
                'content': 'duplicate transient activity',
                'turnId': 'turn-live',
              },
            ],
            'resources': const [],
            'composerText': '',
            'routeLabel': 'Default',
            'permissionMode': 'safe',
            'webAccessEnabled': false,
          },
        );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => buildAgentWindowBridgeShell(context, bridge),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('question 0'), findsNothing);
      expect(find.textContaining('Working for'), findsOneWidget);
      expect(find.text('Inspecting relevant files'), findsOneWidget);
      expect(find.text('Checking the repository'), findsOneWidget);
      expect(find.text('Reasoning'), findsOneWidget);
      expect(find.text('Final streaming answer'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-window-tool-call-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-window-tool-activity-call-1')),
        findsNothing,
      );
      expect(find.textContaining('safe/path.dart'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
      await tester.pump();
      expect(find.text('question 2'), findsOneWidget);
      final anchorBefore = tester.getTopLeft(find.text('question 2')).dy;
      await tester.tap(
        find.byKey(const ValueKey('agent-window-earlier-messages')),
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('question 2')).dy,
        closeTo(anchorBefore, 16),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
      await tester.pump();
      expect(find.text('question 0'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-window-earlier-messages')),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-window-earlier-messages')),
      );
      await tester.pump();
      expect(
        bridge.commands.any((entry) => entry.$1 == 'loadEarlierHistory'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('secondary keeps tool media outside collapsed work details', (
    tester,
  ) async {
    final bridge = _FakeBridge()
      ..snapshot = const AgentWindowSnapshot(
        revision: 31,
        payload: {
          'ready': true,
          'initialized': true,
          'routeReady': true,
          'sessions': [],
          'timeline': [
            {'id': 'turn-media', 'status': 'completed'},
          ],
          'messages': [
            {'role': 'user', 'text': 'Show it', 'turnId': 'turn-media'},
            {
              'role': 'assistant',
              'text': '',
              'stopReason': 'toolUse',
              'turnId': 'turn-media',
              'toolCalls': [
                {'id': 'recent-1', 'name': 'get_recent_images', 'args': {}},
              ],
            },
            {
              'role': 'tool',
              'toolCallId': 'recent-1',
              'toolName': 'get_recent_images',
              'text': 'one image',
              'turnId': 'turn-media',
              'images': [
                {'base64': _oneByOnePngBase64},
              ],
            },
            {
              'role': 'assistant',
              'text': 'Here it is.',
              'turnId': 'turn-media',
            },
          ],
          'activities': [],
          'resources': [],
          'composerText': '',
          'permissionMode': 'safe',
          'webAccessEnabled': false,
        },
      );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('agent-window-tool-media-recent-1')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Here it is.'), findsOneWidget);

    final workHeader = find.byKey(
      const ValueKey('agent-window-turn-work-header-turn-media'),
    );
    await tester.ensureVisible(workHeader);
    await tester.pump();
    await tester.tap(workHeader);
    await tester.pump();
    final tool = find.byKey(const ValueKey('agent-window-tool-recent-1'));
    await tester.ensureVisible(tool);
    await tester.pump();
    await tester.tap(tool);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
    'secondary keeps tool narration outside reasoning when thinking is absent',
    (tester) async {
      final bridge = _FakeBridge()
        ..snapshot = const AgentWindowSnapshot(
          revision: 32,
          payload: {
            'ready': true,
            'initialized': true,
            'routeReady': true,
            'sessions': [],
            'timeline': [
              {'id': 'turn-narration', 'status': 'completed'},
            ],
            'messages': [
              {
                'role': 'user',
                'text': 'Inspect it',
                'turnId': 'turn-narration',
              },
              {
                'role': 'assistant',
                'text': 'I will inspect the repository.',
                'stopReason': 'toolUse',
                'turnId': 'turn-narration',
                'toolCalls': [
                  {'id': 'read-1', 'name': 'read', 'args': {}},
                ],
              },
              {
                'role': 'tool',
                'toolCallId': 'read-1',
                'toolName': 'read',
                'text': 'done',
                'turnId': 'turn-narration',
              },
            ],
            'activities': [],
            'resources': [],
            'composerText': '',
            'permissionMode': 'safe',
            'webAccessEnabled': false,
          },
        );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => buildAgentWindowBridgeShell(context, bridge),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('I will inspect the repository.'), findsNothing);
      await tester.tap(
        find.byKey(
          const ValueKey('agent-window-turn-work-header-turn-narration'),
        ),
      );
      await tester.pump();
      expect(find.text('I will inspect the repository.'), findsOneWidget);
      expect(find.text('Reasoning'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completed and failed work fold tool details by default', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final bridge = _FakeBridge()
      ..snapshot = AgentWindowSnapshot(
        revision: 21,
        payload: {
          'ready': true,
          'initialized': true,
          'routeReady': true,
          'sessions': const [],
          'timeline': [
            {
              'id': 'completed',
              'status': 'completed',
              'firstSeq': 1,
              'lastSeq': 2,
              'startedAt': now - 2000,
              'completedAt': now - 1000,
              'durationMs': 1000,
              'items': const [],
            },
            {
              'id': 'failed',
              'status': 'failed',
              'firstSeq': 3,
              'lastSeq': 4,
              'startedAt': now - 1000,
              'completedAt': now,
              'durationMs': 1000,
              'items': const [],
            },
          ],
          'history': const {'hasEarlier': false},
          'messages': const [
            {
              'role': 'assistant',
              'text': '',
              'stopReason': 'toolUse',
              'turnId': 'completed',
              'toolCalls': [
                {'id': 'done', 'name': 'read', 'args': {}},
              ],
            },
            {
              'role': 'tool',
              'toolCallId': 'done',
              'toolName': 'read',
              'text': 'done detail',
              'turnId': 'completed',
            },
            {
              'role': 'tool',
              'toolCallId': 'failed-call',
              'toolName': 'write',
              'text': '{"error":"Write failed","debug":"private failure body"}',
              'details': {
                'arguments': {'path': 'private/path'},
              },
              'isError': true,
              'turnId': 'failed',
            },
          ],
          'activities': const [],
          'resources': const [],
          'composerText': '',
          'permissionMode': 'safe',
          'webAccessEnabled': false,
        },
      );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => buildAgentWindowBridgeShell(context, bridge),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Worked for 1s'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('agent-window-tool-done')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-window-tool-failed-call')),
      findsNothing,
    );
    expect(find.textContaining('private failure body'), findsNothing);
    expect(find.textContaining('private/path'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('agent-window-turn-work-header-completed')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-window-tool-done')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('agent-window-turn-work-header-failed')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-window-tool-failed-call')),
      findsOneWidget,
    );
    expect(find.text('Error'), findsOneWidget);
    expect(find.textContaining('Write failed'), findsNothing);
    expect(find.textContaining('private failure body'), findsNothing);
    expect(find.textContaining('private/path'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';

final class _FakeBridge extends ChangeNotifier
    implements AgentWindowShellBridge {
  @override
  AgentWindowSnapshot snapshot = const AgentWindowSnapshot(
    revision: 1,
    payload: {
      'ready': true,
      'initialized': true,
      'routeReady': true,
      'sessions': [
        {'id': 'session-a', 'name': 'Session A'},
      ],
      'activeSessionId': 'session-a',
      'messages': [],
      'activities': [],
      'resources': [],
      'composerText': '',
      'routeLabel': 'Default',
      'activeProviderId': 'openai',
      'activeModel': 'gpt-5',
      'modelOptions': [
        {
          'providerId': 'openai',
          'providerName': 'OpenAI',
          'model': 'gpt-5',
          'displayName': 'gpt-5',
        },
      ],
      'thinkingLevel': 'medium',
      'thinkingLevels': ['minimal', 'low', 'medium', 'high'],
      'permissionMode': 'safe',
      'webAccessEnabled': false,
    },
  );

  @override
  bool alwaysOnTop = false;

  final List<(String, Map<String, Object?>?)> commands = [];
  bool failSend = false;

  @override
  Future<void> dock() async {}

  @override
  Future<Object?> sendCommand(
    String command, [
    Map<String, Object?> arguments = const {},
  ]) async {
    commands.add((command, arguments));
    if (command == 'sendText' && failSend) {
      throw StateError('send failed');
    }
    return null;
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async => alwaysOnTop = value;
}
