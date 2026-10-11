import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_dock_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/agent/agent_chat_placement_card.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';

void main() {
  Future<(ProviderContainer, _MemoryLocalStorage)> pumpCard(
    WidgetTester tester, {
    required double width,
    double textScale = 1,
    Locale locale = const Locale('zh'),
  }) async {
    final storage = _MemoryLocalStorage();
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: AgentChatPlacementCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AgentChatPlacementCard)),
    );
    return (container, storage);
  }

  testWidgets('默认选中独占切换，并注明仅宽屏生效', (tester) async {
    await pumpCard(tester, width: 1180);
    final control = tester.widget<SegmentedButton<AgentChatDockMode>>(
      find.byKey(const ValueKey('agent-chat-dock-mode')),
    );
    expect(control.selected, {AgentChatDockMode.exclusive});
    expect(find.text('仅在宽屏生效；窄屏保持全屏聊天。'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('agent-chat-floating-switch')),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('切换停靠方式与浮窗开关即时生效并写入本机设置', (tester) async {
    final (container, storage) = await pumpCard(tester, width: 1180);
    await tester.tap(find.text('左右分栏'));
    await tester.pump();
    expect(
      container.read(agentChatDockProvider).mode,
      AgentChatDockMode.sideBySide,
    );
    expect(
      storage.values[StorageKeys.agentChatDockMode],
      AgentChatDockMode.sideBySide.storageValue,
    );

    await tester.tap(find.byKey(const ValueKey('agent-chat-floating-switch')));
    await tester.pump();
    expect(container.read(agentChatDockProvider).floatingEnabled, isTrue);
    expect(storage.values[StorageKeys.agentChatFloatingEnabled], isTrue);
  });

  testWidgets('窄屏与 3 倍文字下三个选项与浮窗开关仍在同一卡片内且可达', (tester) async {
    for (final (width, locale) in const [
      (320.0, Locale('en')),
      (600.0, Locale('ja')),
      (840.0, Locale('zh')),
      (1600.0, Locale('en')),
    ]) {
      await pumpCard(tester, width: width, textScale: 3, locale: locale);
      final reason = 'width=$width locale=$locale';
      expect(tester.takeException(), isNull, reason: reason);
      final card = tester.getRect(find.byType(SettingsCard));
      final control = find.byKey(const ValueKey('agent-chat-dock-mode'));
      final floating = find.byKey(const ValueKey('agent-chat-floating-switch'));
      for (final target in [control, floating]) {
        final rect = tester.getRect(target);
        expect(rect.top, greaterThanOrEqualTo(card.top), reason: reason);
        expect(rect.bottom, lessThanOrEqualTo(card.bottom), reason: reason);
      }
      for (final mode in AgentChatDockMode.values) {
        final segment = find.descendant(
          of: control,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == _label(tester.element(control), mode),
          ),
        );
        await tester.ensureVisible(segment);
        await tester.pump();
        expect(segment.hitTestable(), findsOneWidget, reason: '$reason $mode');
      }
      final toggle = find.descendant(
        of: floating,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(toggle);
      await tester.pump();
      expect(toggle.hitTestable(), findsOneWidget, reason: reason);
    }
  });
}

String _label(BuildContext context, AgentChatDockMode mode) {
  final l10n = AppLocalizations.of(context)!;
  return switch (mode) {
    AgentChatDockMode.exclusive => l10n.agentSettings_dockExclusive,
    AgentChatDockMode.stacked => l10n.agentSettings_dockStacked,
    AgentChatDockMode.sideBySide => l10n.agentSettings_dockSideBySide,
  };
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
