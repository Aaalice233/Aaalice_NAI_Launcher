import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/precise_reference_type_dialog.dart';

void main() {
  testWidgets('returns the selected precise reference type', (tester) async {
    PreciseRefType? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await PreciseReferenceTypeDialog.show(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Character'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Character + Style'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('precise-reference-type-characterAndStyle')),
    );
    await tester.pumpAndSettle();

    expect(selected, PreciseRefType.characterAndStyle);
  });

  testWidgets('reference choices remain available in a short narrow viewport', (
    tester,
  ) async {
    final view = tester.view;
    view.devicePixelRatio = 3;
    view.physicalSize = const Size(960, 1704);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 568),
            padding: EdgeInsets.fromLTRB(12, 24, 12, 16),
            viewInsets: EdgeInsets.only(bottom: 240),
            textScaler: TextScaler.linear(3),
          ),
          child: Scaffold(body: PreciseReferenceTypeDialog()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('precise-reference-type-character')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
