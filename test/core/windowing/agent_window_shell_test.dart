import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_chat_shared_widgets.dart';
import 'package:nai_launcher/core/windowing/agent_window_protocol.dart';
import 'package:nai_launcher/core/windowing/agent_window_shell.dart';
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

    await tester.tap(find.text('gpt-5'));
    await tester.pumpAndSettle();
    expect(find.text('Reasoning effort'), findsOneWidget);
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

  testWidgets('secondary shell renders user images and survives corrupt data', (
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
    await tester.tap(
      find.byKey(const ValueKey('agent-window-tool-generate_image')),
    );
    await tester.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
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
