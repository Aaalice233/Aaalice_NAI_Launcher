import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_view_data.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_shared_widgets.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_approval.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_status.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';

AgentChatRetryStatus _retryStatus({
  required int resumesInMs,
  String errorMessage =
      'LLM request failed: network error: provider=DeepSeek: '
      'HttpException: Connection closed while receiving data',
}) => AgentChatRetryStatus(
  attempt: 2,
  maxAttempts: 3,
  delayMs: 4000,
  errorMessage: errorMessage,
  resumesAtMs: DateTime.now().millisecondsSinceEpoch + resumesInMs,
);

AgentChatPanelViewData _viewData(AgentChatState state, double width) =>
    AgentChatPanelViewData(
      state: state,
      config: PromptAssistantConfigState.defaults(),
      agentSettings: const AgentSettingsState(initialized: true),
      webAccess: const WebAccessConfigState(initialized: true),
      fullScreen: width < 600,
      compactHeight: false,
      width: width,
      height: 900,
      onClose: null,
      onOpenSettings: null,
      headerWrapper: null,
    );

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
  pasteClipboardImage: () async => false,
  attachImageFiles: (_) async {},
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
  removeQueuedMessage: (_) async {},
  clearQueuedMessages: () async {},
  addPendingResource: (_) async {},
  removePendingResource: (_) async {},
);

void main() {
  Widget app({
    required double width,
    required Widget child,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true, textScaler: textScaler),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('running work status is static and bounded at narrow width', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0, 600.0, 840.0]) {
      await tester.pumpWidget(
        app(
          width: width,
          textScaler: const TextScaler.linear(2),
          child: const AgentChatWorkStatus(
            phase: AgentChatWorkPhase.usingTools,
            routeLabel: 'provider/very-long-production-model-route-name',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final status = find.byKey(const ValueKey('agent-chat-work-status'));
      expect(status, findsOneWidget);
      final container = tester.widget<Container>(status);
      expect(
        (container.margin! as EdgeInsets).left,
        width < 600 ? 12 : 10,
        reason: 'width $width',
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('approval stays actionable and bounded on a narrow phone', (
    tester,
  ) async {
    final decisions = <bool>[];
    await tester.pumpWidget(
      app(
        width: 240,
        child: AgentChatApprovalCard(
          toolName: 'submit_generation',
          args: {
            'prompt': List.filled(30, 'long production prompt').join(' '),
            'model': 'nai-diffusion-4-full',
          },
          estimatedAnlas: 12,
          fileTargets: const [],
          onResolve: decisions.add,
        ),
      ),
    );

    expect(find.textContaining('12 Anlas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final detailsToggle = find.byKey(
      const ValueKey('agent-chat-approval-details'),
    );
    await tester.tap(detailsToggle);
    await tester.pump();

    final details = find.descendant(
      of: detailsToggle,
      matching: find.byType(AgentToolDetailSurface),
    );
    expect(details, findsOneWidget);
    expect(tester.getSize(details).height, lessThanOrEqualTo(132));
    expect(
      find.descendant(of: details, matching: find.byType(SelectableText)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FilledButton));
    expect(decisions, [isTrue]);
  });

  testWidgets('retry notice stays complete across widths and 3x text', (
    tester,
  ) async {
    for (final width in [320.0, 600.0, 840.0, 1180.0]) {
      await tester.pumpWidget(
        app(
          width: width,
          textScaler: const TextScaler.linear(3),
          child: AgentChatRetryNotice(
            status: _retryStatus(resumesInMs: 3500),
          ),
        ),
      );

      final notice = find.byKey(const ValueKey('agent-chat-retry-notice'));
      expect(notice, findsOneWidget);
      expect(
        (tester.widget<Container>(notice).margin! as EdgeInsets).left,
        width < 600 ? 12 : 10,
      );
      expect(find.text('Retrying (2/3) in 4s'), findsOneWidget);
      expect(
        find.text('Network connection error. Check your network connection.'),
        findsOneWidget,
      );
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.value, isNotNull, reason: 'reduce motion is honoured');
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retry notice explains the failure it is retrying', (
    tester,
  ) async {
    for (final (errorMessage, reason) in [
      (
        'LLM request failed: HTTP 503: provider=DeepSeek: busy',
        'Request failed (503)',
      ),
      (
        'Anthropic stream ended before message_stop.',
        'Anthropic stream ended before message_stop.',
      ),
    ]) {
      await tester.pumpWidget(
        app(
          width: 600,
          child: AgentChatRetryNotice(
            status: _retryStatus(resumesInMs: -1, errorMessage: errorMessage),
          ),
        ),
      );
      expect(find.text('Retrying (2/3)…'), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
    }
  });

  testWidgets('status shows the retry notice and the exhausted error card', (
    tester,
  ) async {
    final retrying = AgentChatState(
      status: AgentChatRunStatus.running,
      workPhase: AgentChatWorkPhase.retrying,
      retryStatus: _retryStatus(resumesInMs: 1500),
      messages: [UserMessage.text('hello')],
    );
    await tester.pumpWidget(
      app(
        width: 600,
        child: AgentChatStatus(
          viewData: _viewData(retrying, 600),
          commands: _commands,
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('agent-chat-retry-notice')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-chat-error-card')), findsNothing);

    for (final width in [320.0, 840.0]) {
      final failed = AgentChatState(
        error: 'LLM request failed: HTTP 503: provider=DeepSeek: busy',
        errorRetryAttempts: 3,
        messages: [UserMessage.text('hello')],
      );
      await tester.pumpWidget(
        app(
          width: width,
          textScaler: const TextScaler.linear(3),
          child: AgentChatStatus(
            viewData: _viewData(failed, width),
            commands: _commands,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('agent-chat-retry-notice')),
        findsNothing,
      );
      expect(find.text('Request failed (503)'), findsOneWidget);
      expect(
        find.text('Automatic retries: 3'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-chat-error-retry')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }

    await tester.pumpWidget(
      app(
        width: 600,
        child: AgentChatStatus(
          viewData: _viewData(
            AgentChatState(
              error: 'LLM request failed: HTTP 401: provider=DeepSeek: bad key',
              messages: [UserMessage.text('hello')],
            ),
            600,
          ),
          commands: _commands,
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('agent-chat-error-retry-attempts')),
      findsNothing,
    );
  });

  test('a new error never inherits the previous retry count', () {
    const failed = AgentChatState(error: 'first', errorRetryAttempts: 3);
    expect(failed.copyWith(error: 'second').errorRetryAttempts, 0);
    expect(failed.copyWith(error: '').errorRetryAttempts, 0);
    expect(failed.copyWith(status: AgentChatRunStatus.idle).errorRetryAttempts, 3);
    expect(
      failed
          .copyWith(retryStatus: _retryStatus(resumesInMs: 0))
          .copyWith(clearRetryStatus: true)
          .retryStatus,
      isNull,
    );
  });
}
