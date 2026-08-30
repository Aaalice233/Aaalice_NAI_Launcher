import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_messages.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_view_data.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';

void main() {
  const widths = [320.0, 360.0, 412.0, 600.0, 840.0, 1180.0];

  for (final width in widths) {
    testWidgets(
      'empty state follows the messages layout at ${width.toInt()} and 2x text',
      (tester) async {
        final controller = AgentChatPanelController();
        addTearDown(controller.dispose);

        await _pumpMessages(
          tester,
          width: width,
          controller: controller,
          state: const AgentChatState(initialized: true, routeReady: true),
        );

        expect(find.text('What would you like to do today?'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-chat-suggestion-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-chat-suggestion-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-chat-suggestion-2')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('message flow stays bounded at ${width.toInt()} and 2x text', (
      tester,
    ) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final state = AgentChatState(
        initialized: true,
        routeReady: true,
        messages: [
          UserMessage.text(
            'Please review these character settings before generation.',
            timestamp: DateTime(2025, 5, 16, 10, 41).millisecondsSinceEpoch,
          ),
          AssistantMessage(
            content: const [
              AssistantTextContent(
                'I reviewed the settings.\n\n- The character tags are consistent.\n- The prompt is ready to generate.',
              ),
            ],
            stopReason: StopReason.stop,
            timestamp: DateTime(2025, 5, 16, 10, 42).millisecondsSinceEpoch,
          ),
        ],
      );

      await _pumpMessages(
        tester,
        width: width,
        controller: controller,
        state: state,
      );

      expect(
        find.byKey(const ValueKey('agent-assistant-message-time-1')),
        findsOneWidget,
      );
      for (final action in ['copy', 'retry']) {
        final finder = find.byKey(
          ValueKey('agent-assistant-message-$action-1'),
        );
        expect(finder, findsOneWidget);
        expect(tester.getSize(finder), const Size(48, 48));
      }
      for (final removedAction in ['helpful', 'not-helpful', 'share']) {
        expect(
          find.byKey(ValueKey('agent-assistant-message-$removedAction-1')),
          findsNothing,
        );
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('agent-user-message-bubble-0')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('agent-user-message-bubble-0')),
        findsOneWidget,
      );
      expect(find.text('10:41'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('streaming response exposes a live responding status', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pumpMessages(
      tester,
      width: 320,
      controller: controller,
      state: AgentChatState(
        initialized: true,
        routeReady: true,
        status: AgentChatRunStatus.running,
        streamingMessage: AssistantMessage(
          content: const [AssistantTextContent('Writing the response')],
          stopReason: StopReason.stop,
        ),
      ),
    );

    expect(find.text('Responding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMessages(
  WidgetTester tester, {
  required double width,
  required AgentChatPanelController controller,
  required AgentChatState state,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 900,
          child: AgentChatMessages(
            viewData: AgentChatPanelViewData(
              state: state,
              config: PromptAssistantConfigState.defaults(),
              agentSettings: const AgentSettingsState(initialized: true),
              webAccess: const WebAccessConfigState(initialized: true),
              mobile: width < 600,
              fullScreen: width < 600,
              compactMobile: width < 420,
              width: width,
              height: 900,
              onClose: null,
              onOpenSettings: null,
              mobileHeaderWrapper: null,
            ),
            commands: _commands,
            controller: controller,
          ),
        ),
      ),
    ),
  );
}

final _commands = AgentChatPanelCommands(
  collapse: () {},
  newSession: () async {},
  selectSession: (_) async {},
  renameSession: (_) async {},
  deleteSession: (_) async {},
  moreAction: (_) async {},
  selectModel: (_, __) async {},
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
  resolveApproval: (_, __) => false,
  useSuggestion: (_) {},
  copyUserMessage: (_) async {},
  editUserMessage: (_, __) async {},
  cancelUserMessageEdit: () {},
  copyAssistantMessage: (_) async {},
  editQueuedMessage: (_) async {},
  removeQueuedMessage: (_) {},
  clearQueuedMessages: () {},
  addPendingResource: (_) async {},
  removePendingResource: (_) async {},
);
