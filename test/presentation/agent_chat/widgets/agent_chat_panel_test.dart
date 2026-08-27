import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';

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
    state = state.copyWith(
      sessionTransitioning: value,
      sessionContentLoading: value,
    );
  }

  void setMessages(List<Message> messages) {
    state = state.copyWith(messages: messages);
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

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
