import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as md;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/windowing/agent_chat_session_picker.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/network/web_access/web_access_models.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_memory_image.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:nai_launcher/presentation/widgets/gallery/draggable_image_card.dart';
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
            body: SizedBox(width: 240, height: 720, child: AgentChatPanel()),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('agent-chat-compact-header')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('agent-chat-compact-more')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    AgentChatSessionPicker selector() => tester.widget(
      find.byKey(const ValueKey('agent-chat-session-selector')),
    );
    expect(selector().enabled, isTrue);

    final notifier =
        container.read(agentChatNotifierProvider.notifier)
            as _TestAgentChatNotifier;
    notifier.setSessionTransitioning(true);
    await tester.pump();

    expect(selector().enabled, isFalse);
    expect(
      find.byKey(const ValueKey('agent-chat-session-loading')),
      findsOneWidget,
    );

    notifier.setSessionTransitioning(false);
    await tester.pump();
    expect(selector().enabled, isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 960, height: 720, child: AgentChatPanel()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-chat-desktop-header')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('web access button reads the shared agent configuration', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'agent_chat_panel_web_access_test_',
    );
    late ProviderContainer container;
    addTearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final storage = _MemoryLocalStorage({
      StorageKeys.agentSettingsJson: const AgentSettings(
        chat: AgentChatConfig(webAccessEnabled: true),
      ).encode(),
      StorageKeys.agentWebAccessConfigJson: const WebAccessConfig(
        enabled: true,
      ).encode(),
    });
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
        agentSettingsProvider.overrideWith(
          (ref) => AgentSettingsNotifier(
            ref,
            supportDirectory: tempDir,
            workspaceDirectory: tempDir,
            environment: const {},
          ),
        ),
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
      await _waitForAgentSettingsInitialized(container);
      await _waitForWebAccessInitialized(container);
    });
    (container.read(agentChatNotifierProvider.notifier)
            as _TestAgentChatNotifier)
        .setRouteReady(true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 360, height: 720, child: AgentChatPanel()),
          ),
        ),
      ),
    );

    const key = ValueKey('agent-chat-web-access-toggle');
    IconButton toggle() => tester.widget(find.byKey(key));
    expect(container.read(agentSettingsProvider).error, isEmpty);
    expect(toggle().onPressed, isNotNull);
    expect(toggle().isSelected, isTrue);
    expect(toggle().iconSize, 18);
    expect(
      toggle().style?.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      find.byKey(const ValueKey('agent-chat-session-controls')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-chat-message-actions')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(find.byKey(key)).dy,
      tester
          .getCenter(find.byKey(const ValueKey('agent-chat-permission-mode')))
          .dy,
    );
    expect(container.read(webAccessConfigProvider).config.enabled, isTrue);
    expect(tester.takeException(), isNull);

    final notifier =
        container.read(agentChatNotifierProvider.notifier)
            as _TestAgentChatNotifier;
    notifier.setRunningActivity(
      const AgentToolActivity(
        toolCallId: 'narrow-running',
        toolName: 'read',
        args: {},
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('agent-chat-stop')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tool visuals align and image opens the shared metadata detail viewer',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'agent_chat_panel_image_test_',
      );
      final imageFile = File(
        '${tempDir.path}${Platform.pathSeparator}result.png',
      )..writeAsBytesSync(base64Decode(_oneByOnePngBase64));
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
          shortcutConfigNotifierProvider.overrideWith(
            _TestShortcutConfigNotifier.new,
          ),
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
      final notifier =
          container.read(agentChatNotifierProvider.notifier)
              as _TestAgentChatNotifier;
      notifier.setMessages([
        AssistantMessage(
          content: const [
            ToolCallContent(
              id: 'read-image',
              name: 'read',
              arguments: {'path': 'result.png'},
            ),
          ],
          stopReason: StopReason.toolUse,
        ),
        ToolResultMessage(
          toolCallId: 'read-image',
          toolName: 'read',
          content: const [ToolResultTextContent('Image read successfully')],
        ),
        AssistantMessage(
          content: const [
            ToolCallContent(
              id: 'display-image',
              name: 'display_images',
              arguments: {},
            ),
          ],
          stopReason: StopReason.toolUse,
        ),
        ToolResultMessage(
          toolCallId: 'display-image',
          toolName: 'display_images',
          content: const [ToolResultTextContent('Image displayed')],
          details: {
            'files': [imageFile.path],
          },
        ),
        AssistantMessage(
          content: const [
            ToolCallContent(
              id: 'search-next',
              name: 'web_search',
              arguments: {},
            ),
          ],
          stopReason: StopReason.toolUse,
        ),
        ToolResultMessage(
          toolCallId: 'search-next',
          toolName: 'web_search',
          content: const [ToolResultTextContent('Search completed')],
        ),
      ]);

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
      await tester.pump();

      expect(find.byType(md.MarkdownBody), findsNothing);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.text('Worked'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-tool-result-icon-read-image')),
        findsNothing,
        reason: 'a completed Turn starts collapsed',
      );

      await tester.tap(find.byKey(const ValueKey('agent-turn-work-header-0')));
      await tester.pump();

      expect(find.text('Parameters'), findsNothing);
      expect(find.textContaining('"path": "result.png"'), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-turn-tool-result-read-image')),
        findsNothing,
        reason: 'the tool item is the second-level disclosure',
      );

      await tester.tap(
        find.byKey(const ValueKey('agent-turn-tool-item-read-image')),
      );
      await tester.pump();

      expect(find.text('Parameters'), findsOneWidget);
      final argumentsToggle = find.byKey(
        const ValueKey('agent-tool-arguments-toggle'),
      );
      await tester.ensureVisible(argumentsToggle);
      await tester.pumpAndSettle();
      await tester.tap(argumentsToggle);
      await tester.pump();
      expect(find.textContaining('"path": "result.png"'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-tool-result-details-read-image')),
        findsNothing,
        reason: 'the result payload has its own collapsed disclosure',
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-tool-result-read-image')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('agent-tool-result-details-read-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agent-tool-result-icon-read-image')),
        findsNothing,
        reason: 'a nested result does not repeat the tool status icon',
      );
      final resultColor = Theme.of(
        tester.element(find.byType(AgentChatPanel)),
      ).colorScheme.onSurfaceVariant;
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('agent-tool-result-read-image')),
          matching: find.textContaining('Image read successfully'),
        ),
        findsOneWidget,
      );

      notifier.setRunningActivity(
        const AgentToolActivity(
          toolCallId: 'generate-image',
          toolName: 'generate_image',
          args: {},
        ),
      );
      await tester.pump();
      final activity = find.byKey(
        const ValueKey('agent-tool-activity-generate-image'),
      );
      final activityIconSlot = find.byKey(
        const ValueKey('agent-tool-activity-icon-generate-image'),
      );
      expect(tester.getSize(activityIconSlot), const Size.square(18));
      final activityIcon = tester.widget<Icon>(
        find.descendant(of: activityIconSlot, matching: find.byType(Icon)),
      );
      expect(activityIcon.icon, Icons.auto_awesome_outlined);
      expect(activityIcon.color, resultColor);
      expect(find.text('Generate image'), findsOneWidget);

      expect(
        find.descendant(
          of: activity,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await tester.pump();

      final image = find.byKey(ValueKey(imageFile.path));
      expect(image, findsOneWidget);
      final fileDrag = tester.widget<DraggableImageCard>(
        find.descendant(of: image, matching: find.byType(DraggableImageCard)),
      );
      expect(fileDrag.localData, {'source': 'agent_chat_internal'});
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: image, matching: find.byType(MouseRegion)).first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.click);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(image));
      await tester.pump();
      expect(
        tester
            .widget<ImageCardHoverMotion>(
              find.descendant(
                of: image,
                matching: find.byType(ImageCardHoverMotion),
              ),
            )
            .hovered,
        isTrue,
      );

      await tester.tap(image, buttons: kSecondaryMouseButton);
      await tester.pump();
      for (final label in [
        'Send to Text to Image',
        'Send to Image2Image',
        'Send to Reverse Prompt',
        'Send to Vibe Transfer',
        'Send to Precise Reference',
        'Save to Precise Ref Library',
        'Send to Krita',
        'Upscale',
        'Share to Discord',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tapAt(Offset.zero);
      await tester.pump();

      await tester.tap(image);
      await tester.pump();
      await tester.pump();

      final viewer = tester.widget<ImageDetailViewer>(
        find.byType(ImageDetailViewer),
      );
      expect(viewer.showMetadataPanel, isTrue);
      expect(viewer.showThumbnails, isFalse);
      expect(viewer.images, hasLength(1));
      final detail = viewer.images.single as FileImageDetailData;
      expect(detail.filePath, imageFile.path);
    },
  );

  testWidgets('user message actions only copy locally', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'agent_chat_panel_message_actions_test_',
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
    final notifier =
        container.read(agentChatNotifierProvider.notifier)
            as _TestAgentChatNotifier;
    notifier.setRouteReady(true);
    final oldTimestamp = DateTime(2026, 8, 27, 14, 20).millisecondsSinceEpoch;
    final latestTimestamp = DateTime(
      2026,
      8,
      27,
      14,
      24,
    ).millisecondsSinceEpoch;
    notifier.setMessages([
      UserMessage.text('older', timestamp: oldTimestamp),
      AssistantMessage(
        content: const [AssistantTextContent('older response')],
        stopReason: StopReason.stop,
      ),
      UserMessage(
        timestamp: latestTimestamp,
        content: [
          const UserTextContent('first '),
          const UserImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: 'image/png',
                base64Data: _oneByOnePngBase64,
              ),
            ),
          ),
          const UserTextContent(' second'),
        ],
      ),
      AssistantMessage(
        content: const [AssistantTextContent('latest response')],
        stopReason: StopReason.stop,
      ),
    ]);

    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

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
    await tester.pump();

    final memoryDrag = tester.widget<DraggableMemoryImage>(
      find.byType(DraggableMemoryImage),
    );
    expect(memoryDrag.localData, {'source': 'agent_chat_internal'});
    expect(
      find.byKey(const ValueKey('agent-assistant-message-retry-3')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('agent-user-message-bubble-0')))
          .width,
      lessThan(100),
    );

    final latestMessage = find.byKey(const ValueKey('agent-user-message-2'));
    final actions = find.byKey(const ValueKey('agent-user-message-actions-2'));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    expect(
      find.byKey(const ValueKey('agent-user-message-edit-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-user-message-edit-2')),
      findsNothing,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(latestMessage));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    expect(find.text('14:24'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-user-message-copy-2')));
    await tester.pump();
    expect(copiedText, 'first [image1] second');
    await tester.pump(const Duration(seconds: 4));

    expect(container.read(agentChatNotifierProvider).messages, hasLength(4));
  });

  testWidgets('jump to latest settles at the end of a long lazy transcript', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync(
      'agent_chat_panel_long_transcript_test_',
    );
    late ProviderContainer container;
    addTearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
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
    final notifier =
        container.read(agentChatNotifierProvider.notifier)
            as _TestAgentChatNotifier;
    notifier.setRouteReady(true);
    notifier.setMessages([
      for (var index = 0; index < 60; index++) ...[
        UserMessage.text('user $index'),
        AssistantMessage(
          content: [
            AssistantTextContent(
              index == 59
                  ? 'final transcript marker'
                  : 'response $index ${'details ' * (index % 4 + 1)}',
            ),
          ],
          stopReason: StopReason.stop,
        ),
      ],
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 360, height: 720, child: AgentChatPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('final transcript marker'), findsOneWidget);

    final transcript = find.byType(CustomScrollView);
    expect(transcript, findsOneWidget);
    await tester.drag(transcript, const Offset(0, 500));
    await tester.pumpAndSettle();
    final jumpButton = find.byKey(const ValueKey('agent-chat-jump-to-latest'));
    expect(jumpButton, findsOneWidget);

    await tester.tap(jumpButton);
    await tester.pumpAndSettle();
    expect(jumpButton, findsNothing);
    expect(find.text('final transcript marker'), findsOneWidget);
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
    Widget buildPanel({
      required double width,
      required double height,
      EdgeInsets padding = EdgeInsets.zero,
      EdgeInsets viewInsets = EdgeInsets.zero,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              padding: padding,
              viewInsets: viewInsets,
              textScaler: textScaler,
            ),
            child: Scaffold(
              body: SizedBox(
                width: width,
                height: height,
                child: AgentChatPanel(
                  mobile: true,
                  onClose: () => closed = true,
                  onOpenSettings: () => settingsOpened = true,
                  // Session picker scaling is covered by its own shared-widget
                  // tests; keep this regression focused on the composer.
                  mobileHeaderWrapper: (child) =>
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.6,
                        child: child,
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildPanel(
        width: 320,
        height: 640,
        padding: const EdgeInsets.only(top: 24, bottom: 28),
      ),
    );
    await tester.pump();
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('agent-chat-mobile-header')))
          .dy,
      greaterThanOrEqualTo(24),
    );

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
    final attachmentButton = find.byKey(
      const ValueKey('agent-chat-more-actions'),
    );
    expect(attachmentButton, findsOneWidget);
    expect(tester.getSize(attachmentButton), const Size.square(48));
    for (final key in [
      'agent-chat-input',
      'agent-chat-permission-mode',
      'agent-chat-web-access-toggle',
      'agent-chat-send',
    ]) {
      final target = find.byKey(ValueKey(key));
      expect(target, findsOneWidget, reason: key);
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('agent-chat-context-target'))),
      const Size.square(44),
    );

    for (final width in const [320.0, 360.0, 412.0, 600.0]) {
      for (final scale in const [1.0, 1.6, 2.0]) {
        await tester.pumpWidget(
          buildPanel(
            width: width,
            height: 760,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'composer overflow at width=$width, textScale=$scale',
        );
        expect(
          tester.getSize(attachmentButton),
          const Size.square(48),
          reason: 'attachment target at width=$width, textScale=$scale',
        );
        for (final key in [
          'agent-chat-permission-mode',
          'agent-chat-web-access-toggle',
          'agent-chat-context-target',
          'agent-chat-send',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(
            size.shortestSide,
            greaterThanOrEqualTo(44),
            reason: '$key target at width=$width, textScale=$scale',
          );
        }
      }
    }

    await tester.pumpWidget(
      buildPanel(
        width: 320,
        height: 640,
        padding: const EdgeInsets.only(bottom: 24),
        viewInsets: const EdgeInsets.only(bottom: 280),
        textScaler: const TextScaler.linear(1.6),
      ),
    );
    await tester.pump();
    final composerBottom = tester
        .getBottomRight(
          find.byKey(const ValueKey('agent-chat-input-container')),
        )
        .dy;
    expect(composerBottom, lessThanOrEqualTo(640 - 280));
    expect(tester.takeException(), isNull);

    final inputFinder = find.byKey(const ValueKey('agent-chat-input'));
    await tester.tap(inputFinder);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'draft',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(tester.widget<TextField>(inputFinder).controller?.text, 'draft');

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
    expect(tester.widget<TextField>(inputFinder).controller?.text, 'draft\n');

    await tester.pumpWidget(buildPanel(width: 320, height: 640));
    await tester.pump();
    notifier.setSessionTransitioning(true);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<TextField>(inputFinder).controller?.text,
      'draft\n',
      reason: 'a blocked send must not discard the draft',
    );
    notifier.setSessionTransitioning(false);
    await tester.pump();

    await tester.enterText(inputFinder, List.filled(20, 'line').join('\n'));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('agent-chat-input'))).height,
      lessThanOrEqualTo(176),
    );

    notifier.setError('Request failed');
    await tester.pump();
    final errorDismiss = find.byKey(const ValueKey('agent-chat-error-dismiss'));
    expect(errorDismiss, findsOneWidget);
    expect(tester.getSize(errorDismiss).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(errorDismiss).height, greaterThanOrEqualTo(48));
    await tester.tap(errorDismiss);
    await tester.pump();
    expect(errorDismiss, findsNothing);

    await tester.enterText(inputFinder, 'queued draft');
    notifier.setRunningActivity(
      const AgentToolActivity(
        toolCallId: 'mobile-running',
        toolName: 'read',
        args: {},
      ),
    );
    notifier.setQueuedMessages(20);
    await tester.pumpWidget(buildPanel(width: 320, height: 640));
    await tester.pump();
    expect(find.byKey(const ValueKey('agent-chat-stop')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-chat-follow-up')),
      findsNothing,
      reason: 'queued actions stay inside the collapsed queue disclosure',
    );
    for (final key in ['agent-chat-stop', 'agent-chat-send']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).shortestSide,
        greaterThanOrEqualTo(44),
        reason: '$key running target',
      );
    }
    expect(find.bySemanticsLabel('Steer current work'), findsWidgets);
    expect(find.bySemanticsLabel('Stop'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('agent-chat-queue')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('agent-chat-follow-up')))
          .shortestSide,
      greaterThanOrEqualTo(44),
    );
    expect(find.bySemanticsLabel('Continue after current task'), findsWidgets);
    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason:
          'header=${tester.getSize(find.byKey(const ValueKey('agent-chat-mobile-header')))}, '
          'input=${tester.getSize(find.byKey(const ValueKey('agent-chat-input-container')))}',
    );

    for (final size in const [Size(640, 360), Size(800, 640)]) {
      await tester.pumpWidget(
        buildPanel(width: size.width, height: size.height),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'mobile Agent overflow at ${size.width}x${size.height}',
      );
      expect(find.byKey(const ValueKey('agent-chat-send')), findsOneWidget);
    }

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

Future<void> _waitForWebAccessInitialized(ProviderContainer container) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (container.read(webAccessConfigProvider).initialized) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('WebAccessConfigNotifier did not initialize');
}

Future<void> _waitForAgentSettingsInitialized(
  ProviderContainer container,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (container.read(agentSettingsProvider).initialized) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('AgentSettingsNotifier did not initialize');
}

class _TestAgentChatNotifier extends AgentChatNotifier {
  _TestAgentChatNotifier(
    super.ref, {
    required super.supportDir,
    required super.workspaceDir,
  }) : super(presetSkills: const []);

  void setSessionTransitioning(bool value) {
    state = state.copyWith(
      sessionTransitioning: value,
      sessionContentLoading: value,
    );
  }

  void setMessages(List<Message> messages) {
    state = state.copyWith(messages: messages);
  }

  @override
  Future<UserMessage?> rewindLastUserMessage() async {
    var targetIndex = -1;
    for (var index = state.messages.length - 1; index >= 0; index--) {
      if (state.messages[index] is UserMessage) {
        targetIndex = index;
        break;
      }
    }
    if (targetIndex < 0 || !canManageAgentChatSessions(state)) {
      return null;
    }
    final message = state.messages[targetIndex] as UserMessage;
    state = state.copyWith(messages: state.messages.sublist(0, targetIndex));
    return message;
  }

  void setRunningActivity(AgentToolActivity activity) {
    state = state.copyWith(
      status: AgentChatRunStatus.running,
      activities: [activity],
    );
  }

  void setQueuedMessages(int count) {
    state = state.copyWith(
      queuedMessages: [
        for (var index = 0; index < count; index++)
          AgentQueuedMessage(
            kind: AgentQueuedMessageKind.steering,
            id: index,
            message: UserMessage.text('queued $index'),
          ),
      ],
    );
  }

  void setError(String value) {
    state = state.copyWith(error: value);
  }

  void setRouteReady(bool value) {
    state = state.copyWith(routeReady: value);
  }
}

class _MemoryLocalStorage extends LocalStorageService {
  _MemoryLocalStorage([Map<String, Object?> initial = const {}]) {
    _values.addAll(initial);
  }

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

class _MemorySecureStorage extends SecureStorageService {
  @override
  Future<String?> getAgentWebAccessExaApiKey() async => null;
}

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
