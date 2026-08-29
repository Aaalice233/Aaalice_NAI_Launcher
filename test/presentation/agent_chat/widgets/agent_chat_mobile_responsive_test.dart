import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';

void main() {
  testWidgets('mobile chat keeps transcript and composer in every viewport', (
    tester,
  ) async {
    final supportDir = Directory.systemTemp.createTempSync(
      'agent_chat_mobile_responsive_',
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        agentChatNotifierProvider.overrideWith(
          (ref) => _ResponsiveTestNotifier(
            ref,
            supportDir: supportDir,
            workspaceDir: supportDir,
          ),
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      if (supportDir.existsSync()) supportDir.deleteSync(recursive: true);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.view.resetPadding();
    });

    await tester.runAsync(() async {
      container.read(agentChatNotifierProvider);
      await _waitForInitialized(container);
    });
    final notifier =
        container.read(agentChatNotifierProvider.notifier)
            as _ResponsiveTestNotifier;
    notifier.showReadyConversation();

    Future<void> pumpViewport(
      Size size, {
      double textScale = 1,
      double keyboardInset = 0,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const Scaffold(
              body: AgentChatPanel(mobile: true, fullScreen: true),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(412, 915),
      Size(600, 960),
      Size(840, 600),
    ]) {
      await pumpViewport(size);
      _expectCoreRegionsVisible(tester, size.height);
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }

    await pumpViewport(const Size(360, 800), textScale: 2);
    _expectCoreRegionsVisible(tester, 800);
    expect(tester.takeException(), isNull);

    final input = find.byKey(const ValueKey('agent-chat-input'));
    await tester.tap(input);
    await tester.pump();
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);

    await pumpViewport(const Size(360, 800), textScale: 2, keyboardInset: 320);
    _expectCoreRegionsVisible(tester, 480);
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);
    await tester.enterText(input, 'still typing');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller?.text, 'still typing');

    await pumpViewport(
      const Size(412, 760),
      textScale: 1.6,
      keyboardInset: 280,
    );
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);
    await tester.enterText(input, 'continued after resize');
    await tester.pump();
    expect(
      tester.widget<TextField>(input).controller?.text,
      'continued after resize',
    );
    expect(tester.takeException(), isNull);

    notifier.showApprovalAndQueue();
    await tester.pump();
    _expectCoreRegionsVisible(tester, 480);
    expect(
      find.byKey(const ValueKey('agent-chat-approval-surface')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agent-chat-queue')), findsOneWidget);
    expect(tester.takeException(), isNull);

    notifier.showSessionLoading();
    await tester.pump();
    _expectCoreRegionsVisible(tester, 480);
    expect(
      find.byKey(const ValueKey('agent-chat-session-loading')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _expectCoreRegionsVisible(WidgetTester tester, double viewportBottom) {
  for (final key in const [
    'agent-chat-mobile-header',
    'agent-chat-mobile-viewport',
    'agent-chat-input-container',
    'agent-chat-input',
    'agent-chat-send',
  ]) {
    final finder = find.byKey(ValueKey(key));
    expect(finder, findsOneWidget, reason: key);
    final rect = tester.getRect(finder);
    expect(rect.top, lessThan(viewportBottom), reason: '$key top');
    expect(
      rect.bottom,
      lessThanOrEqualTo(viewportBottom),
      reason: '$key bottom',
    );
  }
}

Future<void> _waitForInitialized(ProviderContainer container) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (container.read(agentChatNotifierProvider).initialized) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('AgentChatNotifier did not initialize');
}

class _ResponsiveTestNotifier extends AgentChatNotifier {
  _ResponsiveTestNotifier(
    super.ref, {
    required super.supportDir,
    required super.workspaceDir,
  }) : super(presetSkills: const []);

  void showReadyConversation() {
    state = state.copyWith(
      routeReady: true,
      messages: [
        UserMessage.text('Plan a compact mobile workflow.'),
        AssistantMessage(
          content: const [
            AssistantTextContent('I will keep the conversation visible.'),
          ],
          stopReason: StopReason.stop,
        ),
      ],
    );
  }

  void showApprovalAndQueue() {
    state = state.copyWith(
      approvalRequest: const AgentToolApprovalRequest(
        toolCallId: 'generate-1',
        toolName: 'generate_image',
        args: {'prompt': 'A long production prompt', 'images': 1},
        estimatedAnlas: 12,
      ),
      queuedMessages: [
        AgentQueuedMessage(
          kind: AgentQueuedMessageKind.steering,
          id: 1,
          message: UserMessage.text('Keep the result concise.'),
        ),
      ],
    );
  }

  void showSessionLoading() {
    state = state.copyWith(sessionContentLoading: true);
  }
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }
}
