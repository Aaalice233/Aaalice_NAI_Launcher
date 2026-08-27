import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/providers/mobile_shell_overlay_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_layout.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('agent_chat_panel_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  testWidgets('session selector is disabled during a session transition', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'agent_chat_panel_test_',
    );
    late ProviderContainer container;
    addTearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final storage = _MemoryLocalStorage();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        agentChatNotifierProvider.overrideWith((ref) {
          return _TestAgentChatNotifier(
            ref,
            supportDir: tempDir,
            workspaceDir: tempDir,
          );
        }),
      ],
    );
    await tester.runAsync(() async {
      container.read(agentChatNotifierProvider);
      await _waitForInitialized(container);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 420, height: 720, child: AgentChatPanel()),
          ),
        ),
      ),
    );

    PopupMenuButton<String> selector() => tester.widget(
      find.byKey(const ValueKey('agent-chat-session-selector')),
    );
    expect(selector().enabled, isTrue);

    final notifier =
        container.read(agentChatNotifierProvider.notifier)
            as _TestAgentChatNotifier;
    notifier.setSessionTransitioning(true);
    await tester.pump();

    expect(selector().enabled, isFalse);

    notifier.setSessionTransitioning(false);
    await tester.pump();
    expect(selector().enabled, isTrue);
  });

  testWidgets('mobile panel stays usable at phone drawer width', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'agent_chat_panel_mobile_test_',
    );
    late ProviderContainer container;
    addTearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final storage = _MemoryLocalStorage();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        agentChatNotifierProvider.overrideWith((ref) {
          return _TestAgentChatNotifier(
            ref,
            supportDir: tempDir,
            workspaceDir: tempDir,
          );
        }),
      ],
    );
    await tester.runAsync(() async {
      container.read(agentChatNotifierProvider);
      await _waitForInitialized(container);
    });

    var closed = false;
    var settingsOpened = false;
    Widget buildPanel(double height) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: height,
              child: AgentChatPanel(
                mobile: true,
                onClose: () => closed = true,
                onOpenSettings: () => settingsOpened = true,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildPanel(640));
    await tester.pump();

    for (final key in [
      'agent-chat-mobile-close',
      'agent-chat-mobile-new-session',
      'agent-chat-session-selector',
      'agent-chat-open-settings',
    ]) {
      final target = find.byKey(ValueKey(key));
      expect(target, findsOneWidget, reason: key);
      final size = tester.getSize(target);
      expect(size.height, greaterThanOrEqualTo(48), reason: '$key height');
    }
    expect(find.byKey(const ValueKey('agent-chat-input')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-chat-open-settings')));
    expect(settingsOpened, isTrue);

    final notifier =
        container.read(agentChatNotifierProvider.notifier)
            as _TestAgentChatNotifier;
    notifier.setRouteReady(true);
    await tester.pump();
    for (final key in [
      'agent-chat-input',
      'agent-chat-attach-image',
      'agent-chat-more-actions',
      'agent-chat-permission-mode',
      'agent-chat-send',
    ]) {
      final target = find.byKey(ValueKey(key));
      expect(target, findsOneWidget, reason: key);
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(48), reason: '$key width');
      expect(size.height, greaterThanOrEqualTo(48), reason: '$key height');
    }

    notifier.setError('Request failed');
    await tester.pump();
    final errorDismiss = find.byKey(const ValueKey('agent-chat-error-dismiss'));
    expect(errorDismiss, findsOneWidget);
    expect(tester.getSize(errorDismiss).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(errorDismiss).height, greaterThanOrEqualTo(48));
    await tester.tap(errorDismiss);
    await tester.pump();
    expect(errorDismiss, findsNothing);

    await tester.pumpWidget(buildPanel(420));
    await tester.pump();
    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason:
          'header=${tester.getSize(find.byKey(const ValueKey('agent-chat-mobile-header')))}, '
          'input=${tester.getSize(find.byKey(const ValueKey('agent-chat-input-container')))}',
    );

    await tester.tap(find.byKey(const ValueKey('agent-chat-mobile-close')));
    await tester.pump();

    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile generation opens AI assistant as a full-screen workspace',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'agent_chat_generation_fullscreen_test_',
      );
      late ProviderContainer container;
      addTearDown(() {
        container.dispose();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final storage = _MemoryLocalStorage();
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentChatNotifierProvider.overrideWith((ref) {
            return _TestAgentChatNotifier(
              ref,
              supportDir: tempDir,
              workspaceDir: tempDir,
            );
          }),
        ],
      );
      await tester.runAsync(() async {
        container.read(agentChatNotifierProvider);
        await _waitForInitialized(container);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 720,
                child: MobileGenerationLayout(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      var hapticCount = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') hapticCount++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      expect(
        find.byKey(const ValueKey('generation-gesture-hint')),
        findsOneWidget,
      );
      expect(find.text('下滑编辑提示词'), findsWidgets);
      expect(find.text('上滑打开 AI 助手'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('generation-agent-drawer-action')),
      );
      await tester.pump();

      final fullScreen = find.byKey(
        const ValueKey('generation-agent-fullscreen'),
      );
      expect(fullScreen, findsOneWidget);
      expect(tester.getSize(fullScreen).width, 360);
      expect(
        find.byKey(const ValueKey('generation-agent-drawer')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-chat-mobile-header')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(
        container.read(mobileShellOverlayNotifierProvider),
        contains(MobileShellOverlay.agentChat),
      );

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('generation-agent-drawer-action')),
        findsOneWidget,
      );
      expect(container.read(mobileShellOverlayNotifierProvider), isEmpty);

      final verticalShortcuts = find.byKey(
        const ValueKey('generation-vertical-shortcuts'),
      );
      expect(verticalShortcuts, findsOneWidget);

      await tester.timedDrag(
        verticalShortcuts,
        const Offset(140, 20),
        const Duration(milliseconds: 300),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('generation-agent-drawer-action')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('maximized-prompt')), findsNothing);

      await tester.timedDrag(
        verticalShortcuts,
        const Offset(0, -80),
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        find.byKey(const ValueKey('generation-agent-drawer-action')),
        findsOneWidget,
      );
      expect(hapticCount, 0);

      final reverseDrag = await tester.startGesture(
        tester.getCenter(verticalShortcuts),
      );
      await reverseDrag.moveBy(const Offset(0, -100));
      await tester.pump();
      await reverseDrag.moveBy(const Offset(0, 100));
      await reverseDrag.up();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        find.byKey(const ValueKey('generation-agent-drawer-action')),
        findsOneWidget,
      );
      expect(hapticCount, 1);

      await tester.timedDrag(
        verticalShortcuts,
        const Offset(0, -48),
        const Duration(milliseconds: 40),
      );
      await tester.pump();
      expect(fullScreen, findsOneWidget);
      expect(hapticCount, 2);
      expect(
        storage.getSetting<bool>(
          StorageKeys.mobileGenerationGestureHintCompleted,
        ),
        isTrue,
      );
      expect(
        container.read(mobileShellOverlayNotifierProvider),
        contains(MobileShellOverlay.agentChat),
      );

      final notifier =
          container.read(agentChatNotifierProvider.notifier)
              as _TestAgentChatNotifier;
      notifier.setRouteReady(true);
      await tester.pump();
      final chatInput = find.byKey(const ValueKey('agent-chat-input'));
      await tester.enterText(chatInput, '保留的会话草稿');
      await tester.timedDrag(
        chatInput,
        const Offset(0, 120),
        const Duration(milliseconds: 500),
      );
      await tester.pump();
      expect(fullScreen, findsOneWidget);

      final agentCloseHandle = find.byKey(
        const ValueKey('generation-agent-close-drag-handle'),
      );
      await tester.timedDrag(
        agentCloseHandle,
        const Offset(0, 120),
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        find.byKey(const ValueKey('generation-agent-drawer-action')),
        findsOneWidget,
      );
      expect(hapticCount, 3);

      await tester.timedDrag(
        verticalShortcuts,
        const Offset(0, -120),
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(fullScreen, findsOneWidget);
      final editable = tester.widget<EditableText>(
        find.descendant(of: chatInput, matching: find.byType(EditableText)),
      );
      expect(editable.controller.text, '保留的会话草稿');
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        find.byKey(const ValueKey('generation-agent-drawer-action')),
        findsOneWidget,
      );

      await tester.timedDrag(
        verticalShortcuts,
        const Offset(0, 120),
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 220));
      final maximizedPrompt = find.byKey(const ValueKey('maximized-prompt'));
      expect(maximizedPrompt, findsOneWidget);
      expect(
        container.read(mobileShellOverlayNotifierProvider),
        isNot(contains(MobileShellOverlay.agentChat)),
      );
      expect(
        container.read(mobileShellOverlayNotifierProvider),
        contains(MobileShellOverlay.promptEditor),
      );

      await tester.timedDrag(
        find.byKey(const ValueKey('generation_prompt_positive_input')),
        const Offset(0, -120),
        const Duration(milliseconds: 500),
      );
      await tester.pump();
      expect(maximizedPrompt, findsOneWidget);

      await tester.timedDrag(
        find.byKey(const ValueKey('generation-prompt-editor-drag-handle')),
        const Offset(0, -120),
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(maximizedPrompt, findsNothing);
      expect(container.read(mobileShellOverlayNotifierProvider), isEmpty);
      expect(hapticCount, greaterThanOrEqualTo(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile shortcuts respect keyboard, reduce motion, landscape and text scale',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'generation_gesture_accessibility_test_',
      );
      final storage = _MemoryLocalStorage();
      await storage.setSetting(
        StorageKeys.mobileGenerationGestureHintCompleted,
        true,
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          agentChatNotifierProvider.overrideWith((ref) {
            return _TestAgentChatNotifier(
              ref,
              supportDir: tempDir,
              workspaceDir: tempDir,
            );
          }),
        ],
      );
      addTearDown(() {
        container.dispose();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      await tester.runAsync(() async {
        container.read(agentChatNotifierProvider);
        await _waitForInitialized(container);
      });

      Widget app({required double keyboardInset}) {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(800, 500),
                viewInsets: EdgeInsets.only(bottom: keyboardInset),
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 500,
                  child: MobileGenerationLayout(),
                ),
              ),
            ),
          ),
        );
      }

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpWidget(app(keyboardInset: 280));
      await tester.pump();
      final hintOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('generation-gesture-hint')),
      );
      expect(hintOpacity.opacity, 0);
      final shortcuts = find.byKey(
        const ValueKey('generation-vertical-shortcuts'),
      );
      await tester.timedDrag(
        shortcuts,
        const Offset(0, -140),
        const Duration(milliseconds: 400),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('generation-agent-fullscreen')),
        findsNothing,
      );

      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpWidget(app(keyboardInset: 0));
      await tester.pump();
      final motionWidgets = tester.widgetList<AnimatedSlide>(
        find.byType(AnimatedSlide),
      );
      expect(motionWidgets, isNotEmpty);
      expect(
        motionWidgets.every((widget) => widget.duration == Duration.zero),
        isTrue,
      );

      await tester.timedDrag(
        shortcuts,
        const Offset(0, -120),
        const Duration(milliseconds: 400),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('generation-agent-fullscreen')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    },
  );
}

Future<void> _waitForInitialized(ProviderContainer container) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (container.read(agentChatNotifierProvider).initialized) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('AgentChatNotifier did not initialize');
}

class _TestAgentChatNotifier extends AgentChatNotifier {
  _TestAgentChatNotifier(
    super.ref, {
    required super.supportDir,
    required super.workspaceDir,
  }) : super(presetSkills: const []);

  void setSessionTransitioning(bool value) {
    state = state.copyWith(sessionTransitioning: value);
  }

  void setError(String value) {
    state = state.copyWith(error: value);
  }

  void setRouteReady(bool value) {
    state = state.copyWith(routeReady: value);
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
