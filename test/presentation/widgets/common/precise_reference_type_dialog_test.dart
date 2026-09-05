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

  testWidgets(
    'all reference choices stay reachable across pane sizes with 3x text',
    (tester) async {
      final view = tester.view;
      view.devicePixelRatio = 1;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      for (final size in const [
        Size(320, 568),
        Size(600, 720),
        Size(840, 760),
        Size(1180, 800),
        Size(1600, 900),
      ]) {
        view.physicalSize = size;
        PreciseRefType? selected;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: size,
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
                viewInsets: EdgeInsets.only(
                  bottom: size.width == 320 ? 240 : 0,
                ),
                textScaler: const TextScaler.linear(3),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await PreciseReferenceTypeDialog.show(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        for (final type in PreciseRefType.values) {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final choice = find.byKey(
            ValueKey('precise-reference-type-${type.name}'),
          );
          await tester.scrollUntilVisible(choice, 100);
          // A 3x label can exceed the viewport; center its tap target instead
          // of requiring the entire row to fit on the short screen at once.
          await Scrollable.ensureVisible(
            tester.element(choice),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          expect(
            choice.hitTestable(),
            findsOneWidget,
            reason:
                '$size / $type; choice=${tester.getRect(choice)}; list=${tester.getRect(find.byType(ListView))}',
          );
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(selected, type);
          expect(tester.takeException(), isNull, reason: '$size / $type');
        }
      }
    },
  );
}
