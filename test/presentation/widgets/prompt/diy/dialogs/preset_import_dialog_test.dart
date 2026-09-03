import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/preset_import_dialog.dart';

void main() {
  testWidgets('导入面板在 Compact 3x 文本、IME 和 SafeArea 下动作可达', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _pumpLauncher(tester, textScale: 3);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preset-import-scroll')), findsOneWidget);

    final closeRect = tester.getRect(
      find.widgetWithIcon(IconButton, Icons.close),
    );
    final submitRect = tester.getRect(find.byType(FilledButton));
    final cancelRect = tester.getRect(find.byType(OutlinedButton));
    expect(closeRect.top, greaterThanOrEqualTo(24));
    expect(submitRect.left, greaterThanOrEqualTo(0));
    expect(cancelRect.right, lessThanOrEqualTo(320));
    expect(cancelRect.bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.byType(PresetImportDialog), findsNothing);
  });

  testWidgets('导入面板在 Expanded 使用受限宽度侧栏', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLauncher(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('preset-import-scroll')),
    );
    expect(find.byType(Dialog), findsNothing);
    expect(contentRect.width, lessThanOrEqualTo(560));
    expect(contentRect.right, lessThanOrEqualTo(1600));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncher(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => PresetImportDialog.showImport(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
