import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/collapsed_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_controller.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/web_left_panel.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'web_left_panel_test_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  setUp(() async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    SharedPreferences.setMockInitialValues({});
    await Hive.box(StorageKeys.settingsBox).clear();
    await Hive.box(StorageKeys.historyBox).clear();
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  for (final width in [39.0, 200.0, 319.0]) {
    testWidgets('expanded panel uses its compact entry at ${width}px', (
      tester,
    ) async {
      await _pumpPanel(tester, width: width, expanded: true);

      expect(
        find.byKey(const ValueKey('web-left-panel-compact-content')),
        findsOneWidget,
      );
      expect(find.byType(CollapsedPanel), findsOneWidget);
      expect(find.text('Parameters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320px Chinese panel fits at 200% text scaling', (tester) async {
    await _pumpPanel(
      tester,
      width: 320,
      expanded: true,
      locale: const Locale('zh'),
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey('web-left-panel-expanded-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('web-generation-workspace-header')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.brush_outlined), findsOneWidget);
    expect(find.text('画布'), findsOneWidget);
    expect(find.text('参数'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal-width Chinese panel fits 200% text scaling', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      width: 400,
      expanded: true,
      locale: const Locale('zh'),
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey('web-left-panel-expanded-content')),
      findsOneWidget,
    );
    expect(find.text('参数'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing retains the prompt subtree with its tag toolbar open', (
    tester,
  ) async {
    final resizing = ValueNotifier(false);
    addTearDown(resizing.dispose);
    await _pumpPanel(
      tester,
      width: 500,
      expanded: true,
      resizing: resizing,
      prompt: 'cat, dog',
    );
    final toggle = find.byKey(const ValueKey('tag-mode-button')).hitTestable();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final capsule = find.byType(TagEditorCapsule).first;
    await tester.ensureVisible(capsule);
    await tester.tap(capsule);
    await tester.pumpAndSettle();
    final toolbar = find.byKey(const ValueKey('tag-action-toolbar'));
    expect(toolbar, findsOneWidget);
    final expanded = find.byKey(
      const ValueKey('web-left-panel-expanded-content'),
    );
    final element = tester.element(expanded);
    final editorState = tester.state(find.byType(TagEditorView));
    for (final active in [true, false, true, false]) {
      resizing.value = active;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.element(expanded), same(element));
      expect(tester.state(find.byType(TagEditorView)), same(editorState));
      expect(toolbar, findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('macOS expand and collapse animations do not overflow', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.macOS,
    );
    final storage = _MemoryLocalStorageService(expanded: false);
    await _pumpPanel(
      tester,
      width: 400,
      expanded: false,
      storage: storage,
      platform: TargetPlatform.macOS,
    );

    await tester.tap(find.byType(CollapsedPanel));
    await tester.pump();
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    }

    expect(
      find.byKey(const ValueKey('web-left-panel-expanded-content')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    }
    expect(
      find.byKey(const ValueKey('web-left-panel-compact-content')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required double width,
  required bool expanded,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  TargetPlatform platform = TargetPlatform.windows,
  _MemoryLocalStorageService? storage,
  ValueNotifier<bool>? resizing,
  String prompt = '',
}) async {
  final effectiveStorage =
      storage ?? _MemoryLocalStorageService(expanded: expanded);
  final negativeModeNotifier = ValueNotifier<bool>(false);
  final promptInputController = PromptInputController(
    prompt: prompt,
    negativePrompt: '',
    negativeModeNotifier: negativeModeNotifier,
  );
  final promptInputKey = GlobalKey();
  addTearDown(promptInputController.dispose);
  addTearDown(negativeModeNotifier.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
        localStorageServiceProvider.overrideWithValue(effectiveStorage),
        kritaBridgeNotifierProvider.overrideWith(
          (ref) => _TestKritaBridgeNotifier(),
        ),
        replicationQueueNotifierProvider.overrideWith(
          _TestReplicationQueueNotifier.new,
        ),
        queueExecutionNotifierProvider.overrideWith(
          _TestQueueExecutionNotifier.new,
        ),
        subscriptionNotifierProvider.overrideWith(
          _TestSubscriptionNotifier.new,
        ),
        estimatedCostProvider.overrideWith((ref) => 0),
        isFreeGenerationProvider.overrideWith((ref) => true),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: textScaler,
            disableAnimations: false,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 900,
                child: ValueListenableBuilder<bool>(
                  valueListenable:
                      resizing ?? const AlwaysStoppedAnimation(false),
                  builder: (context, isResizing, _) => WebLeftPanel(
                    isResizing: isResizing,
                    negativeModeNotifier: negativeModeNotifier,
                    promptInputController: promptInputController,
                    promptInputKey: promptInputKey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  if (expanded && width >= 320) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService({required this.expanded});

  final Map<String, Object?> _values = {};
  bool expanded;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  bool getWebLeftPanelExpanded() => expanded;

  @override
  Future<void> setWebLeftPanelExpanded(bool value) async {
    expanded = value;
  }
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _TestKritaBridgeNotifier extends KritaBridgeNotifier {
  @override
  Future<void> close() async {}
}

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _TestQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.initial();
}
