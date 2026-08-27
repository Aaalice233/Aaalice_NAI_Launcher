import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_memory_image.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:nai_launcher/presentation/widgets/gallery/draggable_image_card.dart';

void main() {
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
    expect(
      find.byKey(const ValueKey('agent-chat-session-loading')),
      findsOneWidget,
    );

    notifier.setSessionTransitioning(false);
    await tester.pump();
    expect(selector().enabled, isTrue);
  });

  testWidgets('web access button toggles the shared agent configuration', (
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
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        secureStorageServiceProvider.overrideWithValue(_MemorySecureStorage()),
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
      await _waitForWebAccessInitialized(container);
    });

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
    expect(toggle().isSelected, isFalse);
    expect(toggle().iconSize, 18);
    expect(
      toggle().style?.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('agent-chat-composer-controls')))
          .height,
      30,
    );
    expect(
      tester.getCenter(find.byKey(key)).dy,
      tester.getCenter(find.byIcon(Icons.image_outlined)).dy,
    );
    expect(container.read(webAccessConfigProvider).config.enabled, isFalse);

    await tester.tap(find.byKey(key));
    await tester.pump();

    expect(toggle().isSelected, isTrue);
    expect(container.read(webAccessConfigProvider).config.enabled, isTrue);

    await tester.tap(find.byKey(key));
    await tester.pump();

    expect(toggle().isSelected, isFalse);
    expect(container.read(webAccessConfigProvider).config.enabled, isFalse);
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
        ToolResultMessage(
          toolCallId: 'read-image',
          toolName: 'read',
          content: const [ToolResultTextContent('Image read successfully')],
          details: {
            'files': [imageFile.path],
          },
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

      final resultIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('agent-tool-result-icon-read-image')),
          matching: find.byType(Icon),
        ),
      );
      expect(resultIcon.icon, Icons.description_outlined);
      expect(find.text('Read file'), findsOneWidget);

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
      expect(activityIcon.icon, Icons.auto_awesome);
      expect(activityIcon.color, isNot(resultIcon.color));
      expect(find.text('Generate image'), findsOneWidget);

      final firstDecoration = tester.widget<Container>(activity).decoration;
      expect(firstDecoration, isA<BoxDecoration>());
      final firstGradient = (firstDecoration! as BoxDecoration).gradient;
      expect(firstGradient, isA<LinearGradient>());
      await tester.pump(const Duration(milliseconds: 600));
      final secondGradient =
          (tester.widget<Container>(activity).decoration! as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(
        secondGradient.begin,
        isNot((firstGradient! as LinearGradient).begin),
      );

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

  testWidgets('user message actions copy and rewind the latest message', (
    tester,
  ) async {
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
          UserImageContent(
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

    final latestMessage = find.byKey(const ValueKey('agent-user-message-2'));
    final actions = find.byKey(const ValueKey('agent-user-message-actions-2'));
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    expect(
      find.byKey(const ValueKey('agent-user-message-edit-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('agent-user-message-edit-2')),
      findsOneWidget,
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

    await tester.tap(find.byKey(const ValueKey('agent-user-message-edit-2')));
    await tester.pump();
    await tester.pump();

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.controller?.text, 'first [image1] second');
    expect(container.read(agentChatNotifierProvider).messages, hasLength(2));
    expect(
      container.read(agentChatNotifierProvider).messages.last,
      isA<AssistantMessage>(),
    );
  });
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
