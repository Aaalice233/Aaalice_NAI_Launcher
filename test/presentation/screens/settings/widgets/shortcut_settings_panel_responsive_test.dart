import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/shortcut_settings_panel.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_binding_editor.dart';

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _EmptyShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => const ShortcutConfig();
}

class _FailingShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() =>
      Future.error(StateError('shortcut storage unavailable'));
}

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    double bottomInset = 0,
    ShortcutConfigNotifier Function()? notifierFactory,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            notifierFactory ?? _TestShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: ShortcutSettingsPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 600.0, 840.0, 1600.0]) {
    testWidgets('快捷键面板在 ${width.toInt()} 宽度无布局异常', (tester) async {
      await pumpPanel(tester, size: Size(width, 720));

      expect(find.text('键盘快捷键'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('全局'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320 短高度、3x 文本和 IME 下仍保留搜索与列表视口', (tester) async {
    await pumpPanel(
      tester,
      size: const Size(320, 420),
      textScale: 3,
      bottomInset: 120,
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact 管理页使用共享有界 bottom sheet 并保留搜索编辑状态', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      top: 12,
      bottom: 12,
      left: 8,
      right: 8,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _TestShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => ShortcutSettingsPanel.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    await tester.enterText(find.byType(TextField), 'generation');
    tester.view.viewInsets = const FakeViewPadding(bottom: 120);
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(surface);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'generation',
    );
    expect(panelRect.left, greaterThanOrEqualTo(8));
    expect(panelRect.top, greaterThanOrEqualTo(12));
    expect(panelRect.right, lessThanOrEqualTo(312));
    expect(panelRect.bottom, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  testWidgets('宽屏快捷键管理使用合理宽度的共享 pane', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _TestShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => ShortcutSettingsPanel.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final pane = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(pane, findsOneWidget);
    expect(tester.getSize(pane).width, 720);
    expect(find.byType(ShortcutSettingsPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空配置显示明确空态', (tester) async {
    await pumpPanel(
      tester,
      size: const Size(320, 520),
      notifierFactory: _EmptyShortcutConfigNotifier.new,
    );

    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.text('未找到匹配的快捷键'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('存储错误显示错误态而不是空白面板', (tester) async {
    await pumpPanel(
      tester,
      size: const Size(320, 520),
      notifierFactory: _FailingShortcutConfigNotifier.new,
    );

    expect(find.textContaining('加载失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索空态在窄屏可见且无溢出', (tester) async {
    await pumpPanel(tester, size: const Size(320, 520));

    await tester.enterText(find.byType(TextField), 'no-such-shortcut');
    await tester.pump();

    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.text('未找到匹配的快捷键'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('录制冲突会显示错误并禁止保存', (tester) async {
    final config = ShortcutConfig.createDefault();
    final binding = config.bindings[ShortcutIds.navigateToGeneration]!;

    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _TestShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShortcutBindingEditor(binding: binding),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ctrl+1'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
    await tester.pump();

    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(saveButton.onPressed, isNull);
    expect(tester.takeException(), isNull);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });
}
