import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.tap(find.byIcon(Icons.send));
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
    await tester.tap(find.byIcon(Icons.send));
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
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(bridge.commands.where((entry) => entry.$1 == 'sendText'), isEmpty);
  });
}

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
