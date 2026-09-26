import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_top_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

void main() {
  for (final panelWidth in [320.0, 600.0]) {
    testWidgets('actions adapt to an embedded ${panelWidth.toInt()}px panel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: panelWidth,
                  child: DetailTopBar(
                    currentImage: GeneratedImageDetailData(
                      imageBytes: Uint8List(0),
                    ),
                    currentIndex: 0,
                    totalImages: 1,
                    onClose: () {},
                    onSave: () {},
                    onShare: () {},
                    onShowMetadata: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      if (panelWidth < 420) {
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Share'), findsOneWidget);
      } else {
        expect(find.byIcon(Icons.save_alt), findsOneWidget);
        expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  group('save as', () {
    for (final (panelWidth, textScale) in [
      (320.0, 1.0),
      (600.0, 1.0),
      (1180.0, 1.0),
      (1180.0, 3.0),
    ]) {
      testWidgets(
        'stays reachable at ${panelWidth.toInt()}px with ${textScale}x text',
        (tester) async {
          var saveAsCount = 0;
          await _pumpTopBar(
            tester,
            panelWidth: panelWidth,
            textScale: textScale,
            image: GeneratedImageDetailData(imageBytes: Uint8List(0)),
            onSaveAs: () => saveAsCount++,
          );

          final inline = find.byTooltip('Save as…');
          if (inline.evaluate().isEmpty) {
            await tester.tap(find.byIcon(Icons.more_vert));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Save as…'));
          } else {
            expect(find.byIcon(Icons.save_as), findsOneWidget);
            await tester.tap(inline);
          }
          await tester.pumpAndSettle();

          expect(saveAsCount, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('is offered for images already saved to the gallery', (
      tester,
    ) async {
      await _pumpTopBar(
        tester,
        panelWidth: 1180,
        image: GeneratedImageDetailData(
          imageBytes: Uint8List(0),
          showSaveButton: false,
        ),
        onSaveAs: () {},
      );

      expect(find.byTooltip('Save'), findsNothing);
      expect(find.byTooltip('Save as…'), findsOneWidget);
    });

    testWidgets('follows the per-image flag even with a callback', (
      tester,
    ) async {
      await _pumpTopBar(
        tester,
        panelWidth: 320,
        image: GeneratedImageDetailData(
          imageBytes: Uint8List(0),
          showSaveAsButton: false,
        ),
        onSaveAs: () {},
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Save as…'), findsNothing);
      expect(find.byIcon(Icons.save_as), findsNothing);
    });
  });
}

Future<void> _pumpTopBar(
  WidgetTester tester, {
  required double panelWidth,
  required ImageDetailData image,
  required VoidCallback onSaveAs,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: panelWidth,
              child: DetailTopBar(
                currentImage: image,
                currentIndex: 0,
                totalImages: 1,
                onClose: () {},
                onSave: () {},
                onSaveAs: onSaveAs,
                onShare: () {},
                onShowMetadata: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
