import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
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
      final time = find.byKey(const ValueKey('agent-assistant-message-time-1'));
      final actions = find.byKey(
        const ValueKey('agent-assistant-message-actions-1'),
      );
      expect(
        tester.getCenter(time).dy,
        closeTo(tester.getCenter(actions).dy, 1),
      );
      // 操作栏与同行时间戳同属消息附属信息，不得自带色面把自己抬成独立层级。
      // 按填充色而非部件类型断言：换一种容器铺色面同样要被挡住。
      final filledFooterSurfaces = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byKey(
                const ValueKey('agent-assistant-message-footer-1'),
              ),
              matching: find.byType(Material),
            ),
          )
          .where((material) => (material.color?.a ?? 0) > 0);
      expect(filledFooterSurfaces, isEmpty);
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

  testWidgets(
    'user message body stays left aligned while metadata and actions keep alignment',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      final messages = [
        UserMessage.text(
          '嗯',
          timestamp: DateTime(2025, 5, 16, 16, 19).millisecondsSinceEpoch,
        ),
        UserMessage.text(
          'This is a deliberately long user message that wraps across '
          'multiple lines without changing its centered alignment.',
          timestamp: DateTime(2025, 5, 16, 16, 20).millisecondsSinceEpoch,
        ),
      ];
      for (final width in [360.0, 840.0]) {
        final textHeights = <double>[];
        for (final message in messages) {
          await _pumpMessages(
            tester,
            width: width,
            controller: controller,
            state: AgentChatState(
              initialized: true,
              routeReady: true,
              messages: [message],
            ),
          );

          final bubble = find.byKey(
            const ValueKey('agent-user-message-bubble-0'),
          );
          final textFinder = find.byKey(
            const ValueKey('agent-user-message-text-0'),
          );
          final text = tester.widget<Text>(textFinder);
          final bubbleRect = tester.getRect(bubble);
          final textRect = tester.getRect(textFinder);
          final statusIcon = find.descendant(
            of: bubble,
            matching: find.byIcon(Icons.done_all_rounded),
          );

          textHeights.add(textRect.height);
          expect(text.textAlign, TextAlign.left);
          expect(textRect.left, closeTo(bubbleRect.left + 12, 0.01));
          expect(
            tester.getRect(statusIcon).right,
            closeTo(bubbleRect.right - 12, 0.01),
          );
          expect(
            tester.getSize(
              find.byKey(const ValueKey('agent-user-message-copy-0')),
            ),
            const Size(40, 40),
          );
        }
        expect(textHeights.last, greaterThan(textHeights.first));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('touch policy keeps user message actions touch safe', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pumpMessages(
      tester,
      width: 840,
      controller: controller,
      state: AgentChatState(
        initialized: true,
        routeReady: true,
        messages: [UserMessage.text('Touch message')],
      ),
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: true,
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('agent-user-message-copy-0'))),
      const Size(48, 48),
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 840.0]) {
    testWidgets(
      'sent resource references stay visible at ${width.toInt()} and 2x text',
      (tester) async {
        final controller = AgentChatPanelController();
        addTearDown(controller.dispose);
        const message = HarnessCustomMessage(
          customType: 'agentResourcePrompt',
          display: true,
          blockContent: [
            UserTextContent('<agent-resource-references />'),
            UserTextContent('Use these resources'),
          ],
          details: {
            'visibleContentOffset': 1,
            'references': [
              {
                'version': 1,
                'kind': 'generatedImage',
                'source': 'generation_history',
                'resourceId': 'image-1',
                'display': {'name': 'Current canvas'},
                'provenance': <String, String>{},
              },
              {
                'version': 1,
                'kind': 'tagLibraryEntry',
                'source': 'tag_library',
                'resourceId': 'tag-1',
                'display': {'name': 'Group OC'},
                'provenance': <String, String>{},
              },
              {
                'version': 1,
                'kind': 'vibeLibraryEntry',
                'source': 'vibe_library',
                'resourceId': 'vibe-1',
                'display': {'name': 'Soft light'},
              },
              {
                'version': 1,
                'kind': 'preciseRefLibraryEntry',
                'source': 'precise_reference_library',
                'resourceId': 'precise-1',
                'display': {'name': 'Pose reference'},
              },
              {
                'version': 1,
                'kind': 'onlineGalleryMedia',
                'source': 'online_gallery',
                'resourceId': 'post-1',
                'display': {'name': 'Gallery image'},
              },
            ],
          },
          timestamp: 123,
        );

        await _pumpMessages(
          tester,
          width: width,
          controller: controller,
          state: const AgentChatState(
            initialized: true,
            routeReady: true,
            messages: [message],
          ),
        );

        expect(find.text('Use these resources'), findsOneWidget);
        expect(find.text('Current canvas'), findsOneWidget);
        expect(find.text('Group OC'), findsOneWidget);
        final bubble = find.byKey(
          const ValueKey('agent-user-message-bubble-0'),
        );
        final resources = find.byKey(
          const ValueKey('agent-user-message-resources-0'),
        );
        final firstCard = find.byKey(
          const ValueKey('agent-user-message-resource-0-0'),
        );
        final secondCard = find.byKey(
          const ValueKey('agent-user-message-resource-0-1'),
        );
        final thirdCard = find.byKey(
          const ValueKey('agent-user-message-resource-0-2'),
        );
        expect(firstCard, findsOneWidget);
        expect(secondCard, findsOneWidget);
        expect(thirdCard, findsOneWidget);
        expect(find.descendant(of: bubble, matching: firstCard), findsNothing);
        expect(
          find.descendant(of: resources, matching: firstCard),
          findsOneWidget,
        );
        expect(
          tester.getTopRight(resources).dx,
          closeTo(tester.getTopRight(bubble).dx, 0.01),
        );
        expect(
          find.descendant(
            of: firstCard,
            matching: find.byIcon(Icons.image_outlined),
          ),
          findsOneWidget,
        );
        await tester.pump();
        expect(
          find.descendant(
            of: firstCard,
            matching: find.byIcon(Icons.link_off_outlined),
          ),
          findsOneWidget,
        );
        if (width >= 840) {
          expect(
            tester.getTopLeft(firstCard).dy,
            tester.getTopLeft(secondCard).dy,
          );
        } else {
          expect(
            tester.getTopLeft(thirdCard).dy,
            greaterThan(tester.getTopLeft(firstCard).dy),
          );
        }
        expect(find.textContaining('agent-resource-references'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reference-only message renders outside the empty body bubble', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    const message = HarnessCustomMessage(
      customType: 'agentResourcePrompt',
      display: true,
      blockContent: [UserTextContent('<agent-resource-references />')],
      details: {
        'references': [
          {
            'version': 1,
            'kind': 'vibeLibraryEntry',
            'source': 'vibe_library',
            'resourceId': 'vibe-1',
            'display': {'name': 'Lighting vibe'},
          },
        ],
      },
      timestamp: 123,
    );

    await _pumpMessages(
      tester,
      width: 320,
      controller: controller,
      state: const AgentChatState(
        initialized: true,
        routeReady: true,
        messages: [message],
      ),
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
    );

    final reference = find.byKey(
      const ValueKey('agent-user-message-resource-0-0'),
    );
    expect(find.text('Lighting vibe'), findsOneWidget);
    expect(reference, findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-user-message-bubble-0')),
      findsNothing,
    );
    final delivery = find.byKey(
      const ValueKey('agent-user-message-delivery-0'),
    );
    final resources = find.byKey(
      const ValueKey('agent-user-message-resources-0'),
    );
    final copyAction = find.byKey(const ValueKey('agent-user-message-copy-0'));
    expect(delivery, findsOneWidget);
    expect(copyAction, findsOneWidget);
    expect(
      tester.getTopRight(delivery).dx,
      lessThan(tester.getTopRight(resources).dx),
    );
    expect(tester.getSize(copyAction).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(copyAction).height, greaterThanOrEqualTo(48));
    expect(find.textContaining('agent-resource-references'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed resource preview keeps the sent reference available', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    const message = HarnessCustomMessage(
      customType: 'agentResourcePrompt',
      display: true,
      blockContent: [UserTextContent('Inspect this reference')],
      details: {
        'references': [
          {
            'version': 1,
            'kind': 'localGalleryImage',
            'source': 'local_gallery',
            'resourceId': 'missing-image',
            'display': {'name': 'Missing image'},
          },
        ],
      },
      timestamp: 123,
    );

    await _pumpMessages(
      tester,
      width: 320,
      controller: controller,
      state: const AgentChatState(
        initialized: true,
        routeReady: true,
        messages: [message],
      ),
      commands: _commandsWithResolver(
        (_) async => throw StateError('preview unavailable'),
      ),
    );

    final reference = find.byKey(
      const ValueKey('agent-user-message-resource-0-0'),
    );
    expect(
      find.descendant(
        of: reference,
        matching: find.byIcon(Icons.image_outlined),
      ),
      findsOneWidget,
    );
    await tester.pump();
    expect(
      find.descendant(
        of: reference,
        matching: find.byIcon(Icons.link_off_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('Missing image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
  AgentChatPanelCommands? commands,
  InteractionPolicy interactionPolicy = const InteractionPolicy(
    modality: InteractionModality.pointer,
    touchAvailable: false,
    precisePointerAvailable: true,
  ),
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
      home: InteractionPolicyScope(
        initialPolicy: interactionPolicy,
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: 900,
            child: AgentChatMessages(
              viewData: AgentChatPanelViewData(
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
                mobileHeaderWrapper: null,
              ),
              commands: commands ?? _commands,
              controller: controller,
            ),
          ),
        ),
      ),
    ),
  );
}

final _commands = _commandsWithResolver((_) async => null);

AgentChatPanelCommands _commandsWithResolver(
  Future<ResolvedAgentResource?> Function(AgentChatResourceReference reference)
  resolveResourcePreview,
) => AgentChatPanelCommands(
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
  resolveResourcePreview: resolveResourcePreview,
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
