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
              child: AgentChatPanel(mobile: true, onClose: () => closed = true),
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

    final notifier = container.read(agentChatNotifierProvider.notifier);
    (notifier as _TestAgentChatNotifier).setError('Request failed');
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
