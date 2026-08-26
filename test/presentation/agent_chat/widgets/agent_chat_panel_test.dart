import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';

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

    notifier.setSessionTransitioning(false);
    await tester.pump();
    expect(selector().enabled, isTrue);
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

class _TestAgentChatNotifier extends AgentChatNotifier {
  _TestAgentChatNotifier(
    super.ref, {
    required super.supportDir,
    required super.workspaceDir,
  }) : super(presetSkills: const []);

  void setSessionTransitioning(bool value) {
    state = state.copyWith(sessionTransitioning: value);
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
