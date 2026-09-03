import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/diy_guide_dialog.dart';

void main() {
  testWidgets('指南面板在 Compact 3x 文本、IME 和 SafeArea 下动作可达', (tester) async {
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
    expect(find.byKey(const ValueKey('diy-guide-scroll')), findsOneWidget);

    final closeRect = tester.getRect(
      find.widgetWithIcon(IconButton, Icons.close),
    );
    final actionRect = tester.getRect(find.byType(FilledButton));
    expect(closeRect.top, greaterThanOrEqualTo(24));
    expect(actionRect.left, greaterThanOrEqualTo(0));
    expect(actionRect.right, lessThanOrEqualTo(320));
    expect(actionRect.bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(DiyGuideDialog), findsNothing);
  });

  testWidgets('指南面板在 Expanded 使用受限宽度侧栏', (tester) async {
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
      find.byKey(const ValueKey('diy-guide-scroll')),
    );
    expect(find.byType(Dialog), findsNothing);
    expect(contentRect.width, lessThanOrEqualTo(680));
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
            onPressed: () => DiyGuideDialog.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
