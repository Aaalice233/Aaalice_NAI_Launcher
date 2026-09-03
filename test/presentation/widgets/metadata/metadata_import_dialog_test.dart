import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/utils/fixed_tag_import_resolution.dart';
import 'package:nai_launcher/presentation/widgets/metadata/metadata_import_dialog.dart';

void main() {
  Future<MetadataImportOptions?> pumpAndOpenDialog(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    NaiImageMetadata metadata = const NaiImageMetadata(steps: 28, scale: 5),
    FixedTagImportResolution? fixedTagResolution,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    MetadataImportOptions? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: padding,
            viewPadding: padding,
            viewInsets: viewInsets,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open-metadata-import'),
              onPressed: () async {
                result = await MetadataImportDialog.show(
                  context,
                  metadata: metadata,
                  fixedTagResolution: fixedTagResolution,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-metadata-import')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('compact form is full-screen at 320px and respects SafeArea', (
    tester,
  ) async {
    const size = Size(320, 640);
    const safePadding = EdgeInsets.fromLTRB(8, 24, 12, 20);
    await pumpAndOpenDialog(tester, size: size, padding: safePadding);

    expect(find.byKey(const ValueKey('adaptive-full-screen-form')), findsOne);
    final rect = tester.getRect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
    );
    expect(rect.left, greaterThanOrEqualTo(safePadding.left));
    expect(rect.top, greaterThanOrEqualTo(safePadding.top));
    expect(rect.right, lessThanOrEqualTo(size.width - safePadding.right));
    expect(rect.bottom, lessThanOrEqualTo(size.height - safePadding.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text and IME keep compact actions visible and scrollable',
    (tester) async {
      const size = Size(320, 700);
      const keyboardInset = 260.0;
      await pumpAndOpenDialog(
        tester,
        size: size,
        textScale: 3,
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
        viewInsets: const EdgeInsets.only(bottom: keyboardInset),
      );

      expect(find.byKey(const Key('metadata-import-options-list')), findsOne);
      expect(find.text('Confirm'), findsOne);
      final dialogRect = tester.getRect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
      );
      expect(dialogRect.bottom, lessThanOrEqualTo(size.height - keyboardInset));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('medium and expanded presentations stay width-bounded', (
    tester,
  ) async {
    for (final size in [const Size(700, 800), const Size(1000, 800)]) {
      await pumpAndOpenDialog(tester, size: size);

      final surfaceFinder = size.width < 840
          ? find.byKey(const ValueKey('adaptive-centered-form'))
          : find.byKey(const ValueKey('adaptive-centered-form'));
      expect(surfaceFinder, findsOneWidget);
      expect(tester.getSize(surfaceFinder).width, lessThanOrEqualTo(560));
      expect(tester.takeException(), isNull, reason: '$size');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('system back dismisses without returning import options', (
    tester,
  ) async {
    final result = await pumpAndOpenDialog(tester, size: const Size(320, 640));

    expect(result, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsNothing,
    );
    expect(find.byKey(const Key('open-metadata-import')), findsOneWidget);
  });

  testWidgets('generation-only preset preserves selective import result', (
    tester,
  ) async {
    MetadataImportOptions? result;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await MetadataImportDialog.show(
                  context,
                  metadata: const NaiImageMetadata(
                    prompt: 'main prompt',
                    steps: 28,
                    scale: 5,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parameters Only'));
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.importPrompt, isFalse);
    expect(result!.importSteps, isTrue);
    expect(result!.importScale, isTrue);
  });

  testWidgets('generation option labels omit localized value separators', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MetadataImportDialog(
            metadata: NaiImageMetadata(steps: 28, scale: 5),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('步数'), findsOneWidget);
    expect(find.text('CFG 强度'), findsOneWidget);
    expect(find.text('CFG 强度：'), findsNothing);
  });

  testWidgets('unknown fixed tags require an explicit stacking policy', (
    tester,
  ) async {
    const metadata = NaiImageMetadata(prompt: 'shared prompt');
    await pumpAndOpenDialog(
      tester,
      size: const Size(700, 800),
      metadata: metadata,
      fixedTagResolution: const FixedTagImportResolution(
        metadata: metadata,
        source: FixedTagImportSource.unknown,
      ),
    );

    expect(find.text('Source: not recorded; cannot be determined'), findsOne);
    expect(find.text('Disable current fixed tags (recommended)'), findsOne);
    expect(find.text('Keep and stack with the image prompt'), findsOne);
  });
}
