import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_import_naming_dialog.dart';

void main() {
  for (final scenario in [
    const _Scenario('320x568', textScale: 1, keyboardHeight: 0),
    const _Scenario('320x568 at 3x text', textScale: 3, keyboardHeight: 0),
    const _Scenario('320x568 with IME', textScale: 1, keyboardHeight: 240),
  ]) {
    testWidgets('${scenario.name} keeps naming confirmation reachable', (
      tester,
    ) async {
      await _setViewport(tester, keyboardHeight: scenario.keyboardHeight);
      await tester.pumpWidget(
        _wrap(
          VibeImportNamingDialog(
            suggestedName: 'imported vibe',
            thumbnail: _onePixelPng,
            isBatchImport: true,
          ),
          textScale: scenario.textScale,
          keyboardHeight: scenario.keyboardHeight,
        ),
      );
      await tester.pump();

      final frame = tester.getRect(
        find.byKey(const Key('vibe-import-naming-frame')),
      );
      expect(frame.left, greaterThanOrEqualTo(0));
      expect(frame.right, lessThanOrEqualTo(320));
      expect(frame.bottom, lessThanOrEqualTo(568 - scenario.keyboardHeight));
      await tester.ensureVisible(find.text('确认'));
      await tester.pump();
      expect(find.text('确认'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('adaptive presentation preserves naming result fields', (
    tester,
  ) async {
    await _setViewport(tester);
    VibeImportResult? result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await VibeImportNamingDialog.show(
                context: context,
                suggestedName: 'suggested',
                isBatchImport: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'renamed');
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('确认'));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(result?.name, 'renamed');
    expect(result?.applyToAll, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _Scenario {
  const _Scenario(
    this.name, {
    required this.textScale,
    required this.keyboardHeight,
  });

  final String name;
  final double textScale;
  final double keyboardHeight;
}

Future<void> _setViewport(
  WidgetTester tester, {
  double keyboardHeight = 0,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
}

Widget _wrap(Widget child, {double textScale = 1, double keyboardHeight = 0}) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        viewInsets: EdgeInsets.only(bottom: keyboardHeight),
      ),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
