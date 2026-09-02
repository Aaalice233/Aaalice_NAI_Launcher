import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/nai_rules_dialog.dart';

void main() {
  testWidgets('规则说明按窗口宽度使用自适应表单容器', (tester) async {
    for (final width in [320.0, 600.0, 1600.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await _pumpAndShowDialog(tester);

      final expectedSurface = switch (width) {
        < 600 => 'adaptive-full-screen-form',
        < 840 => 'adaptive-centered-form',
        _ => 'adaptive-side-sheet',
      };
      final surface = tester.getRect(find.byKey(ValueKey(expectedSurface)));
      expect(surface.left, greaterThanOrEqualTo(0));
      expect(surface.right, lessThanOrEqualTo(width));
      if (width >= 840) {
        expect(surface.width, 600);
      }
      expect(find.byKey(const ValueKey('nai-rules-scroll')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport width $width');

      await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
      await tester.pumpAndSettle();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('320x568、3x 文本和 IME 下可滚动且关闭返回', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    final completed = ValueNotifier(false);
    addTearDown(completed.dispose);
    await _pumpAndShowDialog(tester, textScale: 3, completed: completed);

    final surface = tester.getRect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
    );
    final actionFinder = find.descendant(
      of: find.byType(NaiRulesDialog),
      matching: find.byType(FilledButton),
    );
    final actionButton = tester.getRect(actionFinder);
    expect(surface.top, greaterThanOrEqualTo(24));
    expect(surface.bottom, lessThanOrEqualTo(368));
    expect(actionButton.bottom, lessThanOrEqualTo(surface.bottom));
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);

    final listView = tester.widget<ListView>(find.byType(ListView));
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(listView.controller!.offset, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.tap(actionFinder);
    await tester.pumpAndSettle();
    expect(find.byType(NaiRulesDialog), findsNothing);
    expect(completed.value, isTrue);
  });
}

Future<void> _pumpAndShowDialog(
  WidgetTester tester, {
  double textScale = 1,
  ValueNotifier<bool>? completed,
}) async {
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
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              await NaiRulesDialog.show(context);
              completed?.value = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
