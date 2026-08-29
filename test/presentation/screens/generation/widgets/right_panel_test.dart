import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/right_panel.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('right_panel_test_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.box(StorageKeys.settingsBox).close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  testWidgets('resize mode changes preserve the history panel state', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    final isResizing = ValueNotifier(false);
    addTearDown(isResizing.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 640,
              child: ValueListenableBuilder<bool>(
                valueListenable: isResizing,
                builder: (_, value, __) => RightPanel(isResizing: value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final initialState = tester.state(find.byType(HistoryPanel));
    expect(_panelContainer(tester).duration, const Duration(milliseconds: 200));

    isResizing.value = true;
    await tester.pump();
    expect(tester.state(find.byType(HistoryPanel)), same(initialState));
    expect(_panelContainer(tester).duration, Duration.zero);

    isResizing.value = false;
    await tester.pump();
    expect(tester.state(find.byType(HistoryPanel)), same(initialState));
    expect(_panelContainer(tester).duration, const Duration(milliseconds: 200));
  });

  testWidgets('expanded content waits for the panel width animation', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
          agentChatNotifierProvider.overrideWith(
            (ref) => AgentChatNotifier(
              ref,
              supportDir: hiveDir,
              workspaceDir: Directory('${hiveDir.path}/agent-workspace'),
              presetSkills: const [],
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(width: 400, height: 640, child: RightPanel()),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(AgentChatPanel), findsNothing);

    await tester.tap(find.byIcon(Icons.smart_toy_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AgentChatPanel), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(AgentChatPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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

AnimatedContainer _panelContainer(WidgetTester tester) {
  return tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.byType(HistoryPanel),
      matching: find.byType(AnimatedContainer),
    ),
  );
}
