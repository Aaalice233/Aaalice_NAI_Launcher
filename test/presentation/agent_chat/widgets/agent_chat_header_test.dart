import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_session_view.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_header.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_view_data.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';

void main() {
  testWidgets(
    'header stays single-line with 48dp targets across supported widths',
    (tester) async {
      for (final mobile in [false, true]) {
        for (final width in const [320.0, 360.0, 412.0, 600.0]) {
          await tester.pumpWidget(
            _app(width: width, mobile: mobile, textScale: 2),
          );
          await tester.pump();

          final header = find.byKey(
            ValueKey(
              mobile
                  ? 'agent-chat-mobile-header'
                  : width < 420
                  ? 'agent-chat-compact-header'
                  : 'agent-chat-desktop-header',
            ),
          );
          expect(header, findsOneWidget);
          expect(tester.getSize(header).height, 56);
          expect(find.text('当前会话'), findsOneWidget);
          expect(find.text('提示词助手'), findsNothing);
          expect(
            find.byKey(const ValueKey('agent-chat-mobile-settings')),
            findsNothing,
          );

          for (final key in [
            mobile ? 'agent-chat-mobile-close' : 'agent-chat-collapse',
            'agent-chat-session-selector',
            mobile ? 'agent-chat-mobile-new-session' : 'agent-chat-new-session',
            mobile
                ? 'agent-chat-mobile-more'
                : width < 420
                ? 'agent-chat-compact-more'
                : 'agent-chat-desktop-more',
          ]) {
            expect(
              tester.getSize(find.byKey(ValueKey(key))).height,
              greaterThanOrEqualTo(48),
              reason: '$key at width=$width mobile=$mobile',
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('session picker and overflow retain all header actions', (
    tester,
  ) async {
    final selected = <String>[];
    final actions = <AgentChatMoreAction>[];
    var settingsOpened = false;
    await tester.pumpWidget(
      _app(
        width: 600,
        mobile: false,
        onSelect: selected.add,
        onMoreAction: actions.add,
        onOpenSettings: () => settingsOpened = true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-chat-session-selector')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-chat-session-search')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-chat-session-search')),
      '第二',
    );
    await tester.pump();
    expect(find.text('第二个会话'), findsOneWidget);
    await tester.tap(find.text('第二个会话'));
    await tester.pumpAndSettle();
    expect(selected, ['second']);

    await tester.tap(find.byKey(const ValueKey('agent-chat-desktop-more')));
    await tester.pumpAndSettle();
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('压缩上下文'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('在独立窗口中打开'), findsNothing);
    expect(find.text('智能体'), findsOneWidget);
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    expect(actions, [AgentChatMoreAction.rename]);

    await tester.tap(find.byKey(const ValueKey('agent-chat-desktop-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('智能体'));
    await tester.pumpAndSettle();
    expect(settingsOpened, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required double width,
  required bool mobile,
  double textScale = 1,
  void Function(String id)? onSelect,
  void Function(AgentChatMoreAction action)? onMoreAction,
  VoidCallback? onOpenSettings,
}) {
  final state = AgentChatState(
    initialized: true,
    sessions: [
      AgentChatSessionSummary(
        metadata: const SessionMetadata(id: 'current', createdAt: 1),
        name: '当前会话',
        updatedAt: DateTime(2025),
      ),
      AgentChatSessionSummary(
        metadata: const SessionMetadata(id: 'second', createdAt: 2),
        name: '第二个会话',
        updatedAt: DateTime(2025, 1, 2),
      ),
    ],
    activeSessionId: 'current',
  );
  final viewData = AgentChatPanelViewData(
    state: state,
    config: PromptAssistantConfigState.defaults(),
    agentSettings: const AgentSettingsState(),
    webAccess: const WebAccessConfigState(),
    mobile: mobile,
    fullScreen: mobile,
    compactMobile: false,
    width: width,
    height: 720,
    onClose: () {},
    onOpenSettings: onOpenSettings,
    mobileHeaderWrapper: null,
  );
  final commands = AgentChatPanelCommands(
    collapse: () {},
    newSession: () async {},
    selectSession: (id) async => onSelect?.call(id),
    renameSession: (_) async {},
    deleteSession: (_) async {},
    moreAction: (action) async => onMoreAction?.call(action),
    selectModel: (_, _) async {},
    selectThinkingLevel: (_) async {},
    selectPermissionMode: (_) async {},
    setWebAccessEnabled: (_) async {},
    pickImages: () async {},
    attachCurrentCanvas: () async {},
    openReferenceGallery: () async {},
    openResourceLibrary: () async {},
    resolveResourcePreview: (_) async => null,
    send: () async {},
    sendFollowUp: () async {},
    stop: () {},
    dismissError: () {},
    retryLastMessage: () async {},
    resolveApproval: (_, _) => false,
    useSuggestion: (_) {},
    copyUserMessage: (_) async {},
    copyAssistantMessage: (_) async {},
    editQueuedMessage: (_) async {},
    removeQueuedMessage: (_) {},
    clearQueuedMessages: () {},
    addPendingResource: (_) async {},
    removePendingResource: (_) async {},
  );
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 720),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SizedBox(
          width: width,
          height: 720,
          child: Align(
            alignment: Alignment.topCenter,
            child: AgentChatHeader(viewData: viewData, commands: commands),
          ),
        ),
      ),
    ),
  );
}
