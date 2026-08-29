import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_turn_timeline.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_messages.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_view_data.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_tool_widgets.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_turn.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';

void main() {
  test(
    'assembler pairs call_id and keeps final assistant outside work items',
    () {
      final messages = <Message>[
        UserMessage.text('Inspect the prompt', timestamp: 1000),
        AssistantMessage(
          content: const [
            AssistantThinkingContent('I should read the current state.'),
            AssistantTextContent('I will inspect the file first.'),
            ToolCallContent(
              id: 'call-1',
              name: 'read',
              arguments: {'path': 'prompt.txt'},
            ),
          ],
          stopReason: StopReason.toolUse,
          timestamp: 1100,
        ),
        ToolResultMessage(
          toolCallId: 'call-1',
          toolName: 'read',
          content: const [ToolResultTextContent('prompt contents')],
          timestamp: 1200,
        ),
        AssistantMessage(
          content: const [AssistantTextContent('The prompt is ready.')],
          stopReason: StopReason.stop,
          timestamp: 1300,
        ),
      ];

      final thread = AgentChatThreadModel.fromMessages(messages);

      expect(thread.turns, hasLength(1));
      expect(thread.turns.single.workItems, hasLength(3));
      expect(
        thread.turns.single.workItems.first.thinking,
        'I should read the current state.',
      );
      expect(
        thread.turns.single.workItems.first.thinking,
        isNot(contains('I will inspect the file first.')),
      );
      expect(
        thread.turns.single.workItems[1].narration,
        'I will inspect the file first.',
      );
      expect(thread.turns.single.workItems.last.call?.id, 'call-1');
      expect(thread.turns.single.workItems.last.result?.toolCallId, 'call-1');
      expect(
        thread.turns.single.finalMessages.map(
          (entry) => (entry.message as AssistantMessage).text,
        ),
        ['The prompt is ready.'],
      );
      expect(thread.turns.single.timeline, isNull);
    },
  );

  test(
    'assembler only exposes authoritative timeline identity and duration',
    () {
      final messages = <Message>[
        UserMessage.text('Run it', timestamp: 1000),
        AssistantMessage(
          content: const [AssistantTextContent('Done')],
          stopReason: StopReason.stop,
          timestamp: 900000,
        ),
      ];
      final withoutTimeline = AgentChatThreadModel.fromMessages(messages);
      final withTimeline = AgentChatThreadModel.fromMessages(
        messages,
        timeline: [
          AgentChatTurnTimeline(
            id: 'turn-authoritative',
            status: AgentChatTurnStatus.completed,
            firstSeq: 1,
            lastSeq: 2,
            startedAt: DateTime(2025, 1, 1, 12).millisecondsSinceEpoch,
            completedAt: DateTime(2025, 1, 1, 12, 0, 3).millisecondsSinceEpoch,
            duration: const Duration(seconds: 3),
            items: const [
              AgentChatTimelineItem(
                id: 'entry:user',
                entryId: 'user',
                seq: 1,
                parentEntryId: null,
                kind: AgentChatTimelineItemKind.userMessage,
                timestamp: 1000,
              ),
              AgentChatTimelineItem(
                id: 'entry:assistant',
                entryId: 'assistant',
                seq: 2,
                parentEntryId: 'user',
                kind: AgentChatTimelineItemKind.assistantMessage,
                timestamp: 2000,
              ),
            ],
          ),
        ],
      );

      expect(withoutTimeline.turns.single.timeline, isNull);
      expect(withTimeline.turns.single.timeline?.id, 'turn-authoritative');
      expect(
        withTimeline.turns.single.timeline?.duration,
        const Duration(seconds: 3),
      );
    },
  );

  testWidgets('completed work collapses while final answer remains visible', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller: controller,
      state: AgentChatState(
        initialized: true,
        routeReady: true,
        messages: _completedTurn(),
      ),
    );

    expect(find.text('Worked'), findsOneWidget);
    expect(find.textContaining('Worked for'), findsNothing);
    expect(find.text('The prompt is ready.'), findsOneWidget);
    expect(find.text('prompt contents'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-turn-work-header-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Read file · prompt contents'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-turn-tool-result-call-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-tool-arguments-toggle')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('agent-turn-tool-item-call-1')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-turn-tool-result-call-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-tool-result-details-call-1')),
      findsNothing,
    );
    expect(find.textContaining('prompt.txt'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-tool-arguments-toggle')));
    await tester.pump();
    expect(find.textContaining('prompt.txt'), findsOneWidget);
    expect(find.text('The prompt is ready.'), findsOneWidget);
  });

  testWidgets(
    'tool narration stays visible without creating a reasoning item',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        controller: controller,
        state: AgentChatState(
          initialized: true,
          routeReady: true,
          messages: [
            UserMessage.text('Inspect it'),
            AssistantMessage(
              content: const [
                AssistantTextContent('I will inspect the repository.'),
                ToolCallContent(id: 'read-1', name: 'read', arguments: {}),
              ],
              stopReason: StopReason.toolUse,
            ),
            ToolResultMessage(
              toolCallId: 'read-1',
              toolName: 'read',
              content: const [ToolResultTextContent('done')],
            ),
          ],
        ),
      );

      expect(find.text('I will inspect the repository.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-turn-work-header-0')));
      await tester.pump();
      expect(find.text('I will inspect the repository.'), findsOneWidget);
      expect(find.text('Reasoning'), findsNothing);
    },
  );

  test('only explicit display tools expose media results', () {
    AgentChatTurnModel buildTurn(String toolName) =>
        AgentChatThreadModel.fromMessages([
          UserMessage.text('Images'),
          AssistantMessage(
            content: [
              ToolCallContent(
                id: 'image-call',
                name: toolName,
                arguments: const {},
              ),
            ],
            stopReason: StopReason.toolUse,
          ),
          ToolResultMessage(
            toolCallId: 'image-call',
            toolName: toolName,
            content: [
              ToolResultImageContent(
                ImageContent(
                  source: ImageSource.base64(
                    mimeType: 'image/png',
                    base64Data: base64Encode(_onePixelPng),
                  ),
                ),
              ),
            ],
          ),
        ]).turns.single;

    expect(buildTurn('get_recent_images').mediaResults, isEmpty);
    expect(buildTurn('search_local_gallery').mediaResults, isEmpty);
    expect(buildTurn('display_images').mediaResults, hasLength(1));
    expect(buildTurn('preview_generated_image').mediaResults, hasLength(1));
  });

  testWidgets(
    'display image media stays visible outside collapsed work details',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        controller: controller,
        state: AgentChatState(
          initialized: true,
          routeReady: true,
          messages: [
            UserMessage.text('Show the latest image'),
            AssistantMessage(
              content: const [
                ToolCallContent(
                  id: 'display-image-1',
                  name: 'display_images',
                  arguments: {'resource_refs': <Object>[]},
                ),
              ],
              stopReason: StopReason.toolUse,
            ),
            ToolResultMessage(
              toolCallId: 'display-image-1',
              toolName: 'display_images',
              content: [
                const ToolResultTextContent('{"count":1}'),
                ToolResultImageContent(
                  ImageContent(
                    source: ImageSource.base64(
                      mimeType: 'image/png',
                      base64Data: base64Encode(_onePixelPng),
                    ),
                  ),
                ),
              ],
            ),
            AssistantMessage(
              content: const [
                AssistantTextContent('Here is the latest image.'),
              ],
              stopReason: StopReason.stop,
            ),
          ],
        ),
      );

      expect(
        find.byKey(const ValueKey('agent-tool-media-display-image-1')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Here is the latest image.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-turn-work-header-0')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('agent-turn-tool-item-display-image-1')),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('failed tool keeps error and arguments folded by default', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller: controller,
      state: AgentChatState(
        initialized: true,
        routeReady: true,
        messages: [
          UserMessage.text('Submit it'),
          AssistantMessage(
            content: const [
              ToolCallContent(
                id: 'failed-submit',
                name: 'submit_generation',
                arguments: {'preparation_id': 'private-id'},
              ),
            ],
            stopReason: StopReason.toolUse,
          ),
          ToolResultMessage(
            toolCallId: 'failed-submit',
            toolName: 'submit_generation',
            isError: true,
            content: const [
              ToolResultTextContent(
                '{"error":"Generation submission failed","debug":"private body"}',
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Worked'), findsOneWidget);
    expect(find.textContaining('Generation submission failed'), findsNothing);
    expect(find.textContaining('private body'), findsNothing);
    expect(find.textContaining('private-id'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-turn-work-header-0')));
    await tester.pump();
    expect(
      find.textContaining('Submit generation · Generation submission failed'),
      findsOneWidget,
    );
    expect(find.textContaining('private body'), findsNothing);
    expect(find.textContaining('private-id'), findsNothing);
  });

  testWidgets('running turn expands work and keeps streaming final separate', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller: controller,
      state: AgentChatState(
        initialized: true,
        routeReady: true,
        status: AgentChatRunStatus.running,
        messages: [
          UserMessage.text('Inspect it'),
          AssistantMessage(
            content: const [
              AssistantThinkingContent('Checking the source'),
              ToolCallContent(id: 'live-call', name: 'read', arguments: {}),
            ],
            stopReason: StopReason.toolUse,
          ),
        ],
        activities: const [
          AgentToolActivity(
            toolCallId: 'live-call',
            toolName: 'read',
            args: {'path': 'prompt.txt'},
          ),
        ],
        streamingMessage: AssistantMessage(
          content: const [AssistantTextContent('The current result')],
          stopReason: StopReason.stop,
        ),
      ),
    );

    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Reasoning'), findsWidgets);
    expect(
      find.byKey(const ValueKey('agent-tool-activity-live-call')),
      findsOneWidget,
    );
    expect(find.textContaining('prompt.txt'), findsNothing);
    expect(find.text('The current result'), findsOneWidget);
  });

  testWidgets(
    'manual turn collapse overrides running lifecycle across live updates',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      AgentChatState runningState(String reasoning) => AgentChatState(
        initialized: true,
        routeReady: true,
        status: AgentChatRunStatus.running,
        messages: [UserMessage.text('Inspect it')],
        streamingMessage: AssistantMessage(
          content: [AssistantThinkingContent(reasoning)],
          stopReason: StopReason.toolUse,
        ),
      );

      await _pump(
        tester,
        controller: controller,
        state: runningState('First live reasoning'),
      );
      expect(find.text('First live reasoning'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-turn-work-header-0')));
      await tester.pump();
      expect(find.text('First live reasoning'), findsNothing);

      await _pump(
        tester,
        controller: controller,
        state: runningState('Updated live reasoning'),
      );
      await tester.pump();
      expect(find.text('Updated live reasoning'), findsNothing);
      expect(find.text('Working'), findsOneWidget);
    },
  );

  testWidgets('live reasoning item can be folded independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentChatReasoningTile(
            thinking: 'Private live reasoning',
            live: true,
          ),
        ),
      ),
    );

    expect(find.text('Private live reasoning'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-reasoning-toggle')));
    await tester.pump();
    expect(find.text('Private live reasoning'), findsNothing);
  });

  testWidgets('large thread retains recent turns and lazily reveals history', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    final messages = <Message>[
      for (var index = 0; index < 80; index++) ...[
        UserMessage.text('User turn $index'),
        AssistantMessage(
          content: [AssistantTextContent('Assistant turn $index')],
          stopReason: StopReason.stop,
        ),
      ],
    ];
    await _pump(
      tester,
      controller: controller,
      state: AgentChatState(
        initialized: true,
        routeReady: true,
        activeSessionId: 'large-thread',
        messages: messages,
      ),
      height: 640,
    );

    expect(find.byType(SliverList), findsOneWidget);
    expect(find.text('Assistant turn 79'), findsOneWidget);
    expect(find.text('Assistant turn 0'), findsNothing);
    expect(find.byKey(const ValueKey('agent-turn-content-0')), findsNothing);
    expect(find.byKey(const ValueKey('agent-turn-content-79')), findsOneWidget);
    controller.scrollController.jumpTo(
      controller.scrollController.position.maxScrollExtent,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-chat-earlier-messages')),
      findsOneWidget,
    );

    final before = controller.scrollController.offset;
    await tester.tap(find.byKey(const ValueKey('agent-chat-earlier-messages')));
    await tester.pump();
    expect(controller.scrollController.offset, closeTo(before, 0.1));
    expect(tester.takeException(), isNull);
  });
}

List<Message> _completedTurn() => [
  UserMessage.text('Inspect the prompt'),
  AssistantMessage(
    content: const [
      AssistantThinkingContent('I should inspect it.'),
      ToolCallContent(
        id: 'call-1',
        name: 'read',
        arguments: {'path': 'prompt.txt'},
      ),
    ],
    stopReason: StopReason.toolUse,
  ),
  ToolResultMessage(
    toolCallId: 'call-1',
    toolName: 'read',
    content: const [ToolResultTextContent('prompt contents')],
  ),
  AssistantMessage(
    content: const [AssistantTextContent('The prompt is ready.')],
    stopReason: StopReason.stop,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required AgentChatPanelController controller,
  required AgentChatState state,
  double height = 800,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: height,
          child: AgentChatMessages(
            viewData: AgentChatPanelViewData(
              state: state,
              config: PromptAssistantConfigState.defaults(),
              agentSettings: const AgentSettingsState(initialized: true),
              webAccess: const WebAccessConfigState(initialized: true),
              mobile: false,
              fullScreen: false,
              compactMobile: false,
              width: 600,
              height: height,
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

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=',
);

final _commands = AgentChatPanelCommands(
  collapse: () {},
  detach: () async {},
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
  copyAssistantMessage: (_) async {},
  editQueuedMessage: (_) async {},
  removeQueuedMessage: (_) {},
  clearQueuedMessages: () {},
  addPendingResource: (_) async {},
  removePendingResource: (_) async {},
);
