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

  testWidgets('桌面会话菜单使用紧凑尺寸和密度', (tester) async {
    tester.view.physicalSize = const Size(600, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: AgentChatSessionPicker(
                sessions: [
                  for (var index = 0; index < 4; index++)
                    AgentChatSessionOption(
                      id: 'session-$index',
                      name: '测试会话 $index',
                      updatedAt: DateTime(2026, 9, 3, 20, index),
                    ),
                ],
                activeSessionId: 'session-0',
                enabled: true,
                onSelect: (_) async {},
                onNew: () async {},
                onRename: (_) async {},
                onDelete: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('测试会话 0'));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('agent-chat-session-menu'));
    expect(tester.getSize(menu), const Size(340, 336));
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('agent-chat-session-material-session-0')),
          )
          .height,
      lessThan(64),
    );
    expect(tester.getSize(find.byType(FilledButton)).height, 40);
    expect(tester.takeException(), isNull);
  });
}
