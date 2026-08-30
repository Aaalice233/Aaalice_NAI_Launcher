import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_chat_session_picker.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

void main() {
  testWidgets('会话选择器在窗口最小化的极窄约束下不会横向溢出', (tester) async {
    Widget picker({required bool compactTitle}) => SizedBox(
      width: 19,
      child: AgentChatSessionPicker(
        sessions: const [AgentChatSessionOption(id: 'session-1', name: '测试会话')],
        activeSessionId: 'session-1',
        enabled: true,
        compactTitle: compactTitle,
        onSelect: (_) async {},
        onNew: () async {},
        onRename: (_) async {},
        onDelete: (_) async {},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [picker(compactTitle: true), picker(compactTitle: false)],
          ),
        ),
      ),
    );

    expect(find.byType(AgentChatSessionPicker), findsNWidgets(2));
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    expect(find.byIcon(Icons.forum_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
