import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/context_usage.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/windowing/agent_chat_shared_widgets.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_composer.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_view_data.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile composer follows the mockup hierarchy', (tester) async {
    final resource = AgentChatResourceReference(
      kind: AgentChatResourceKind.fixedTag,
      source: 'test',
      resourceId: 'golden-hair',
      display: const {'name': 'golden hair'},
    );
    await _pumpComposer(
      tester,
      width: 412,
      state: _readyState.copyWith(
        contextUsage: const AgentContextUsage(
          tokens: 29300,
          contextWindow: 128000,
          percent: 22.890625,
          estimated: false,
        ),
        pendingResources: [resource],
      ),
    );

    final input = tester.getRect(
      find.byKey(const ValueKey('agent-chat-input')),
    );
    final resources = tester.getRect(find.text('golden hair'));
    final actions = tester.getRect(
      find.byKey(const ValueKey('agent-chat-message-actions')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('agent-chat-session-controls')),
    );
    expect(input.top, lessThan(resources.top));
    expect(resources.top, lessThan(actions.top));
    expect(actions, settings);

    final moreCenter = tester.getCenter(
      find.byKey(const ValueKey('agent-chat-more-actions')),
    );
    final sendCenter = tester.getCenter(
      find.byKey(const ValueKey('agent-chat-send')),
    );
    expect(moreCenter.dx, lessThan(sendCenter.dx));

    final modelCenter = tester.getCenter(
      find.byKey(const ValueKey('agent-chat-model-selector')),
    );
    final thinkingCenter = tester.getCenter(
      find.byKey(const ValueKey('agent-chat-thinking-selector')),
    );
    final permissionCenter = tester.getCenter(
      find.byKey(const ValueKey('agent-chat-permission-mode')),
    );
    final webCenter = tester.getCenter(
      find.byKey(const ValueKey('agent-chat-web-access-toggle')),
    );
    final contextCenter = tester.getCenter(
      find.byKey(const ValueKey('agent-chat-context-target')),
    );
    expect(moreCenter.dx, lessThan(modelCenter.dx));
    expect(moreCenter.dy, modelCenter.dy);
    expect(modelCenter.dy, lessThan(thinkingCenter.dy));
    expect(thinkingCenter.dx, lessThan(permissionCenter.dx));
    expect(permissionCenter.dx, lessThan(webCenter.dx));
    expect(webCenter.dx, lessThan(contextCenter.dx));
    expect(contextCenter.dx, lessThan(sendCenter.dx));
    expect(thinkingCenter.dy, sendCenter.dy);
    expect(
      find.byKey(const ValueKey('agent-chat-context-ring')),
      findsOneWidget,
    );
    expect(find.text('23%'), findsOneWidget);

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('agent-chat-composer-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable context stays compact and has no empty ring', (
    tester,
  ) async {
    await _pumpComposer(tester, width: 320);

    expect(
      find.byKey(const ValueKey('agent-chat-context-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-chat-context-ring')),
      findsOneWidget,
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Context usage unavailable'), findsNothing);
    final target = tester.getSize(
      find.byKey(const ValueKey('agent-chat-context-target')),
    );
    expect(target, const Size.square(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow desktop uses one toolbar and one context ring', (
    tester,
  ) async {
    await _pumpComposer(
      tester,
      width: 520,
      mobile: false,
      state: _readyState.copyWith(
        contextUsage: const AgentContextUsage.unknown(contextWindow: 128000),
      ),
    );

    final toolbar = tester.getRect(
      find.byKey(const ValueKey('agent-chat-message-actions')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('agent-chat-session-controls')),
    );
    expect(toolbar, settings);
    for (final key in const [
      'agent-chat-more-actions',
      'agent-chat-model-selector',
      'agent-chat-thinking-selector',
      'agent-chat-permission-mode',
      'agent-chat-web-access-toggle',
      'agent-chat-context-target',
      'agent-chat-send',
    ]) {
      expect(
        tester.getCenter(find.byKey(ValueKey(key))).dy,
        closeTo(toolbar.center.dy, 0.1),
      );
    }
    expect(find.text('—'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-chat-context-ring')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('very narrow desktop splits controls without overflow', (
    tester,
  ) async {
    await _pumpComposer(tester, width: 265, mobile: false);

    final toolbar = tester.getRect(
      find.byKey(const ValueKey('agent-chat-message-actions')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('agent-chat-session-controls')),
    );
    expect(toolbar, settings);
    expect(toolbar.height, greaterThan(40));

    final model = tester.getRect(
      find.byKey(const ValueKey('agent-chat-model-selector')),
    );
    final thinking = tester.getRect(
      find.byKey(const ValueKey('agent-chat-thinking-selector')),
    );
    final permission = tester.getRect(
      find.byKey(const ValueKey('agent-chat-permission-mode')),
    );
    expect(model.bottom, lessThanOrEqualTo(thinking.top));
    expect(thinking.bottom, lessThanOrEqualTo(permission.bottom));
    for (final key in const [
      'agent-chat-more-actions',
      'agent-chat-model-selector',
      'agent-chat-thinking-selector',
      'agent-chat-permission-mode',
      'agent-chat-web-access-toggle',
      'agent-chat-context-target',
      'agent-chat-send',
    ]) {
      final control = tester.getRect(find.byKey(ValueKey(key)));
      expect(control.left, greaterThanOrEqualTo(toolbar.left));
      expect(control.right, lessThanOrEqualTo(toolbar.right));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop model selector shows the complete model name', (
    tester,
  ) async {
    const modelName = 'deepseek-v4-flash-vision-exp';
    final config = PromptAssistantConfigState.defaults().copyWith(
      providers: const [
        ProviderConfig(
          id: 'deepseek',
          name: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com',
        ),
      ],
      models: const [
        ModelConfig(
          providerId: 'deepseek',
          name: modelName,
          displayName: modelName,
          forTask: AssistantTaskType.chat,
        ),
      ],
    );
    const agentSettings = AgentSettingsState(
      initialized: true,
      settings: AgentSettings(
        chat: AgentChatConfig(
          modelReference: AgentModelReference(
            providerId: 'deepseek',
            model: modelName,
          ),
        ),
      ),
    );

    await _pumpComposer(
      tester,
      width: 520,
      mobile: false,
      config: config,
      agentSettings: agentSettings,
    );

    final selector = find.byKey(const ValueKey('agent-chat-model-selector'));
    expect(find.textContaining(modelName), findsOneWidget);
    expect(tester.getSize(selector).width, greaterThan(120));

    await tester.tap(selector);
    await tester.pumpAndSettle();

    expect(find.text(modelName), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('agent-chat-model-search')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading context is contained inside the only ring', (
    tester,
  ) async {
    await _pumpComposer(
      tester,
      width: 320,
      mobile: false,
      state: _readyState.copyWith(compacting: true),
    );

    expect(
      find.byKey(const ValueKey('agent-chat-context-ring')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-chat-context-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-chat-context-unavailable')),
      findsNothing,
    );
    expect(find.text('Context usage unavailable'), findsNothing);
    expect(find.text('Compacting context…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'composer remains overflow-free across mobile widths and scaling',
    (tester) async {
      for (final width in const [320.0, 360.0, 412.0, 600.0, 840.0]) {
        for (final scale in const [1.0, 1.6, 2.0]) {
          await _pumpComposer(
            tester,
            width: width,
            textScaler: TextScaler.linear(scale),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow at width=$width, scale=$scale',
          );
          for (final key in const [
            'agent-chat-more-actions',
            'agent-chat-send',
          ]) {
            final size = tester.getSize(find.byKey(ValueKey(key)));
            expect(
              size.shortestSide,
              greaterThanOrEqualTo(44),
              reason: '$key at width=$width, scale=$scale',
            );
          }
          final compactControls = find.byKey(
            const ValueKey('agent-chat-compact-controls'),
          );
          if (compactControls.evaluate().isNotEmpty) {
            expect(
              tester.getSize(compactControls).shortestSide,
              greaterThanOrEqualTo(44),
            );
          } else {
            for (final key in const [
              'agent-chat-thinking-selector',
              'agent-chat-permission-mode',
              'agent-chat-web-access-toggle',
              'agent-chat-context-target',
            ]) {
              expect(
                tester.getSize(find.byKey(ValueKey(key))).shortestSide,
                greaterThanOrEqualTo(44),
                reason: '$key at width=$width, scale=$scale',
              );
            }
          }
        }
      }
    },
  );

  testWidgets('running composer exposes queue steering follow-up and stop', (
    tester,
  ) async {
    final queued = AgentQueuedMessage(
      kind: AgentQueuedMessageKind.followUp,
      id: 1,
      message: UserMessage.text('export the result'),
    );
    await _pumpComposer(
      tester,
      width: 320,
      state: _readyState.copyWith(
        status: AgentChatRunStatus.running,
        queuedMessages: [queued],
      ),
    );

    expect(find.byKey(const ValueKey('agent-chat-queue')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-chat-queue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-chat-follow-up')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-chat-stop')), findsOneWidget);
    expect(find.bySemanticsLabel('Steer current work'), findsWidgets);
    expect(find.bySemanticsLabel('Continue after current task'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile plus opens a safe attachment source sheet', (
    tester,
  ) async {
    await _pumpComposer(tester, width: 360);

    await tester.tap(find.byKey(const ValueKey('agent-chat-more-actions')));
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Current canvas'), findsOneWidget);
    expect(find.text('Reference gallery'), findsOneWidget);
    expect(find.text('Resource library'), findsOneWidget);
    final currentCanvas = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Current canvas'),
    );
    expect(currentCanvas.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop plus uses an anchored attachment menu', (tester) async {
    await _pumpComposer(tester, width: 840, mobile: false);

    await tester.tap(find.byKey(const ValueKey('agent-chat-more-actions')));
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Reference gallery'), findsOneWidget);
    expect(
      find.byType(PopupMenuItem<AgentChatAttachmentAction>),
      findsNWidgets(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current canvas is selectable only with an existing reference', (
    tester,
  ) async {
    var attached = 0;
    final reference = AgentChatResourceReference(
      kind: AgentChatResourceKind.generatedImage,
      source: 'generation_history',
      resourceId: 'existing-image',
    );
    await _pumpComposer(
      tester,
      width: 840,
      mobile: false,
      currentCanvasReference: reference,
      onAttachCurrentCanvas: () async => attached++,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('agent-chat-more-actions'))),
    );
    await mouse.down(
      tester.getCenter(find.byKey(const ValueKey('agent-chat-more-actions'))),
    );
    await mouse.up();
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.text('Current canvas')));
    await mouse.down(tester.getCenter(find.text('Current canvas')));
    await mouse.up();
    await tester.pumpAndSettle();

    expect(attached, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending image card previews removes and renumbers tokens', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    controller.addPendingImage(
      PendingAgentChatImage(
        name: 'first.png',
        bytes: bytes,
        mimeType: 'image/png',
      ),
    );
    controller.addPendingImage(
      PendingAgentChatImage(
        name: 'second.png',
        bytes: bytes,
        mimeType: 'image/png',
      ),
    );
    await _pumpComposer(tester, width: 412, controller: controller);

    expect(find.text('first.png'), findsOneWidget);
    expect(find.text('second.png'), findsOneWidget);
    expect(controller.inputController.text, '[image1] [image2] ');

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('agent-chat-pending-image-card')).first,
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
    expect(controller.pendingImages, hasLength(1));
    expect(controller.inputController.text.trim(), '[image1]');
    expect(find.text('second.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop running queue precedes the tonal input surface', (
    tester,
  ) async {
    final queued = AgentQueuedMessage(
      kind: AgentQueuedMessageKind.steering,
      id: 1,
      message: UserMessage.text('use the selected references'),
    );
    await _pumpComposer(
      tester,
      width: 835,
      mobile: false,
      state: _readyState.copyWith(
        status: AgentChatRunStatus.running,
        queuedMessages: [queued],
        contextUsage: const AgentContextUsage(
          tokens: 78100,
          contextWindow: 128000,
          percent: 61.015625,
          estimated: false,
        ),
      ),
    );

    final queue = tester.getRect(
      find.byKey(const ValueKey('agent-chat-queue')),
    );
    final input = tester.getRect(
      find.byKey(const ValueKey('agent-chat-input')),
    );
    final actions = tester.getRect(
      find.byKey(const ValueKey('agent-chat-message-actions')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('agent-chat-session-controls')),
    );
    expect(queue.bottom, lessThanOrEqualTo(input.top));
    expect(input.bottom, lessThanOrEqualTo(actions.top));
    expect(actions, settings);
    expect(find.text('61%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'composer expands immediately and preserves text selection and focus',
    (tester) async {
      final controller = AgentChatPanelController();
      addTearDown(controller.dispose);
      controller.inputController.value = const TextEditingValue(
        text: 'keep this draft',
        selection: TextSelection(baseOffset: 5, extentOffset: 9),
      );
      await _pumpComposer(
        tester,
        width: 520,
        mobile: false,
        controller: controller,
      );

      final input = find.byKey(const ValueKey('agent-chat-input'));
      final editor = find.byKey(const ValueKey('agent-chat-composer-editor'));
      final expand = find.byKey(const ValueKey('agent-chat-composer-expand'));
      final inputWidget = tester.widget<TextField>(input);
      expect(inputWidget.minLines, AgentChatComposerLayout.defaultMinLines);
      final collapsedHeight = tester.getSize(editor).height;

      await tester.tap(input);
      controller.inputController.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      await tester.tap(expand);
      await tester.pump();

      expect(tester.widget<TextField>(input).expands, isTrue);
      expect(tester.getSize(editor).height, greaterThan(collapsedHeight));
      expect(controller.inputController.text, 'keep this draft');
      expect(
        controller.inputController.selection,
        const TextSelection(baseOffset: 5, extentOffset: 9),
      );
      expect(controller.inputFocus.hasFocus, isTrue);
      expect(find.bySemanticsLabel(RegExp('^Collapse')), findsOneWidget);

      await tester.tap(expand);
      await tester.pump();
      expect(tester.widget<TextField>(input).expands, isFalse);
      expect(controller.inputController.text, 'keep this draft');
      expect(controller.inputFocus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expanded composer fits 320/520 widths and Android IME', (
    tester,
  ) async {
    for (final width in const [320.0, 520.0]) {
      await _pumpComposer(
        tester,
        width: width,
        height: 640,
        viewInsets: const EdgeInsets.only(bottom: 280),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-chat-composer-expand')),
      );
      await tester.pump();

      final composerBottom = tester
          .getBottomRight(
            find.byKey(const ValueKey('agent-chat-input-container')),
          )
          .dy;
      expect(
        composerBottom,
        lessThanOrEqualTo(360),
        reason: 'IME overflow at width=$width',
      );
      expect(
        find.byKey(const ValueKey('agent-chat-message-actions')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('running editor keeps stop and expand targets separate', (
    tester,
  ) async {
    await _pumpComposer(
      tester,
      width: 320,
      mobile: false,
      state: _readyState.copyWith(status: AgentChatRunStatus.running),
    );

    final editor = tester.getRect(
      find.byKey(const ValueKey('agent-chat-composer-editor')),
    );
    final stop = tester.getRect(find.byKey(const ValueKey('agent-chat-stop')));
    final expand = tester.getRect(
      find.byKey(const ValueKey('agent-chat-composer-expand')),
    );
    expect(stop.overlaps(expand), isFalse);
    expect(stop.center.dy, closeTo(editor.center.dy, 0.01));
    expect(expand.center.dy, closeTo(editor.center.dy, 0.01));
    expect(find.bySemanticsLabel('Stop'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Expand')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard insets and composing enter preserve the draft', (
    tester,
  ) async {
    var sends = 0;
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pumpComposer(
      tester,
      width: 360,
      height: 640,
      viewInsets: const EdgeInsets.only(bottom: 280),
      textScaler: const TextScaler.linear(1.6),
      controller: controller,
      onSend: () async => sends++,
    );

    final composerBottom = tester
        .getBottomRight(
          find.byKey(const ValueKey('agent-chat-input-container')),
        )
        .dy;
    expect(composerBottom, lessThanOrEqualTo(640 - 280));

    final input = find.byKey(const ValueKey('agent-chat-input'));
    await tester.tap(input);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'draft',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(controller.inputController.text, 'draft');
    expect(sends, 0);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'draft',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(controller.inputController.text, 'draft\n');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sends, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slash at the start lists skills and session commands', (
    tester,
  ) async {
    await _pumpComposer(tester, width: 412, state: _skilledState);

    expect(_slashMenu, findsNothing);
    await tester.enterText(_input, '/');
    await tester.pump();

    expect(_slashMenu, findsOneWidget);
    expect(_inMenu('Skills'), findsOneWidget);
    expect(_inMenu('/art-prompt'), findsOneWidget);
    expect(_inMenu('/paperbanana'), findsOneWidget);
    // Session commands follow the skills under their own heading; the list
    // scrolls once the group exceeds the menu's height budget.
    expect(_inMenu('Session'), findsOneWidget);
    expect(_inMenu('/new'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu filters as the name is typed', (tester) async {
    await _pumpComposer(tester, width: 412, state: _skilledState);

    await tester.enterText(_input, '/art');
    await tester.pump();
    expect(_inMenu('/art-prompt'), findsOneWidget);
    expect(_inMenu('/new'), findsNothing);

    await tester.enterText(_input, '/zzz');
    await tester.pump();
    expect(_slashMenu, findsNothing);
  });

  testWidgets('a slash later in the message never opens the menu', (
    tester,
  ) async {
    await _pumpComposer(tester, width: 412, state: _skilledState);

    await tester.enterText(_input, 'read /art');
    await tester.pump();
    expect(_slashMenu, findsNothing);
  });

  testWidgets('arrow keys move the selection and Enter inserts the skill', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    var sends = 0;
    await _pumpComposer(
      tester,
      width: 412,
      state: _skilledState,
      controller: controller,
      onSend: () async => sends++,
    );

    // "paper" matches one command; "pa" would also hit "Compact context".
    await tester.enterText(_input, '/paper');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // A single match wraps back to itself, and Enter accepts instead of sending.
    expect(controller.inputController.text, '/paperbanana ');
    expect(sends, 0);
    expect(_slashMenu, findsNothing);
  });

  testWidgets('a session command runs at once and leaves no token behind', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    final actions = <AgentChatMoreAction>[];
    var sends = 0;
    await _pumpComposer(
      tester,
      width: 412,
      state: _skilledState,
      controller: controller,
      onSend: () async => sends++,
      onMoreAction: actions.add,
    );

    await tester.enterText(_input, '/new');
    await tester.pump();
    await tester.tap(_inMenu('/new'));
    await tester.pump();

    expect(actions, [AgentChatMoreAction.newSession]);
    expect(controller.inputController.text, isEmpty);
    expect(sends, 0);
  });

  testWidgets('Escape closes the menu and hands Enter back to send', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    var sends = 0;
    await _pumpComposer(
      tester,
      width: 412,
      state: _skilledState,
      controller: controller,
      onSend: () async => sends++,
    );

    await tester.enterText(_input, '/art');
    await tester.pump();
    expect(_slashMenu, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_slashMenu, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sends, 1);
    expect(controller.inputController.text, '/art');
  });

  testWidgets('moving the caret back into the token reopens the menu', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    await _pumpComposer(
      tester,
      width: 412,
      state: _skilledState,
      controller: controller,
    );

    await tester.enterText(_input, '/art draw a cat');
    await tester.pump();
    expect(_slashMenu, findsNothing);

    // A caret-only move leaves the draft text untouched, so the composer has
    // to notice it on its own.
    controller.inputController.selection = const TextSelection.collapsed(
      offset: 4,
    );
    await tester.pump();
    expect(_slashMenu, findsOneWidget);
    expect(_inMenu('/art-prompt'), findsOneWidget);
  });

  testWidgets('the menu sits above the editor on desktop and mobile', (
    tester,
  ) async {
    for (final (width, mobile) in [(412.0, true), (720.0, false)]) {
      await _pumpComposer(
        tester,
        width: width,
        mobile: mobile,
        state: _skilledState,
      );
      await tester.enterText(_input, '/');
      await tester.pump();

      final menu = tester.getRect(_slashMenu);
      final editor = tester.getRect(_input);
      expect(
        menu.bottom,
        lessThanOrEqualTo(editor.top),
        reason: 'width $width should keep the menu clear of the editor',
      );
      expect(menu.width, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('message edit fills the composer and cancel restores its draft', (
    tester,
  ) async {
    final controller = AgentChatPanelController();
    addTearDown(controller.dispose);
    controller.inputController.text = 'unfinished draft';
    controller.beginEditingUserMessage(2, 'correct this request', const []);

    await _pumpComposer(tester, width: 420, controller: controller);

    expect(controller.inputController.text, 'correct this request');
    expect(
      find.byKey(const ValueKey('agent-chat-message-edit-header')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('agent-chat-cancel-message-edit')),
    );
    await tester.pump();

    expect(controller.isEditingUserMessage, isFalse);
    expect(controller.inputController.text, 'unfinished draft');
    expect(
      find.byKey(const ValueKey('agent-chat-message-edit-header')),
      findsNothing,
    );
  });
}

final _input = find.byKey(const ValueKey('agent-chat-input'));
final _slashMenu = find.byKey(const ValueKey('agent-chat-slash-menu'));

/// The editor holds the same literal text, so menu assertions must be scoped.
Finder _inMenu(String text) =>
    find.descendant(of: _slashMenu, matching: find.text(text));

final _skilledState = _readyState.copyWith(
  skills: const [
    HarnessSkill(
      name: 'art-prompt',
      description: 'Draw with Danbooru tags',
      content: 'skill body',
      filePath: '/skills/art-prompt/SKILL.md',
    ),
    HarnessSkill(
      name: 'paperbanana',
      description: 'Academic figures',
      content: 'skill body',
      filePath: '/skills/paperbanana/SKILL.md',
    ),
  ],
);

const _readyState = AgentChatState(
  initialized: true,
  routeReady: true,
  routeLabel: 'Test model',
);

Future<void> _pumpComposer(
  WidgetTester tester, {
  required double width,
  double height = 900,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
  AgentChatState state = _readyState,
  AgentChatPanelController? controller,
  Future<void> Function()? onSend,
  Future<void> Function()? onAttachCurrentCanvas,
  void Function(AgentChatMoreAction action)? onMoreAction,
  AgentChatResourceReference? currentCanvasReference,
  PromptAssistantConfigState? config,
  AgentSettingsState? agentSettings,
  bool mobile = true,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: textScaler,
          viewInsets: viewInsets,
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: InteractionPolicyScope(
              initialPolicy: InteractionPolicy(
                modality: mobile
                    ? InteractionModality.touch
                    : InteractionModality.pointer,
                touchAvailable: mobile,
                precisePointerAvailable: !mobile,
              ),
              child: _ComposerHarness(
                state: state,
                width: width,
                height: height - viewInsets.bottom,
                controller: controller,
                onSend: onSend,
                onAttachCurrentCanvas: onAttachCurrentCanvas,
                onMoreAction: onMoreAction,
                currentCanvasReference: currentCanvasReference,
                config: config,
                agentSettings: agentSettings,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _ComposerHarness extends StatefulWidget {
  const _ComposerHarness({
    required this.state,
    required this.width,
    required this.height,
    this.controller,
    this.onSend,
    this.onAttachCurrentCanvas,
    this.onMoreAction,
    this.currentCanvasReference,
    this.config,
    this.agentSettings,
  });

  final AgentChatState state;
  final double width;
  final double height;
  final AgentChatPanelController? controller;
  final Future<void> Function()? onSend;
  final Future<void> Function()? onAttachCurrentCanvas;
  final void Function(AgentChatMoreAction action)? onMoreAction;
  final AgentChatResourceReference? currentCanvasReference;
  final PromptAssistantConfigState? config;
  final AgentSettingsState? agentSettings;

  @override
  State<_ComposerHarness> createState() => _ComposerHarnessState();
}

class _ComposerHarnessState extends State<_ComposerHarness> {
  late final AgentChatPanelController controller;
  late final bool ownsController;

  @override
  void initState() {
    super.initState();
    ownsController = widget.controller == null;
    controller = widget.controller ?? AgentChatPanelController();
    controller.addListener(_refresh);
    controller.inputController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.inputController.removeListener(_refresh);
    if (ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commands = AgentChatPanelCommands(
      collapse: () {},
      newSession: () async {},
      selectSession: (_) async {},
      renameSession: (_) async {},
      deleteSession: (_) async {},
      moreAction: (action) async => widget.onMoreAction?.call(action),
      selectModel: (_, _) async {},
      selectThinkingLevel: (_) async {},
      selectPermissionMode: (_) async {},
      setWebAccessEnabled: (_) async {},
      pickImages: () async {},
      attachCurrentCanvas: widget.onAttachCurrentCanvas ?? () async {},
      openReferenceGallery: () async {},
      openResourceLibrary: () async {},
      resolveResourcePreview: (_) async => null,
      send: widget.onSend ?? () async {},
      sendFollowUp: () async {},
      stop: () {},
      dismissError: () {},
      retryLastMessage: () async {},
      resolveApproval: (_, _) => true,
      useSuggestion: (_) {},
      copyUserMessage: (_) async {},
      editUserMessage: (_, __) async {},
      cancelUserMessageEdit: controller.cancelEditingUserMessage,
      copyAssistantMessage: (_) async {},
      editQueuedMessage: (_) async {},
      removeQueuedMessage: (_) async {},
      clearQueuedMessages: () async {},
      addPendingResource: (_) async {},
      removePendingResource: (_) async {},
    );
    return AgentChatComposer(
      viewData: AgentChatPanelViewData(
        state: widget.state,
        config: widget.config ?? PromptAssistantConfigState.defaults(),
        agentSettings:
            widget.agentSettings ?? const AgentSettingsState(initialized: true),
        webAccess: const WebAccessConfigState(initialized: true),
        fullScreen: true,
        compactHeight: widget.height < 520,
        width: widget.width,
        height: widget.height,
        onClose: null,
        onOpenSettings: null,
        mobileHeaderWrapper: null,
        currentCanvasReference: widget.currentCanvasReference,
      ),
      commands: commands,
      controller: controller,
    );
  }
}
