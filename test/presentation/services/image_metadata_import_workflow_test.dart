import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/services/image_metadata_import_workflow.dart';
import 'package:nai_launcher/presentation/services/mobile_image_metadata_importer.dart';

void main() {
  testWidgets('system picker cancellation stops without processing', (
    tester,
  ) async {
    var processed = false;
    final importer = MobileImageMetadataImporter(
      imageBytesPicker: () async => null,
      imageProcessor: (context, ref, image) async {
        processed = true;
      },
    );

    await _pumpAction(
      tester,
      action: (context, ref) => importer.run(context: context, ref: ref),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(processed, isFalse);
  });

  testWidgets('picked image bytes and file name enter the shared action flow', (
    tester,
  ) async {
    PickedImageData? processedImage;
    final importer = MobileImageMetadataImporter(
      imageBytesPicker: () async => PickedImageData(
        fileName: 'original.webp',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      imageProcessor: (context, ref, image) async {
        processedImage = image;
      },
    );

    await _pumpAction(
      tester,
      action: (context, ref) => importer.run(context: context, ref: ref),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(processedImage?.fileName, 'original.webp');
    expect(processedImage?.bytes, [1, 2, 3]);
  });

  testWidgets('missing metadata reports noMetadata without opening dialog', (
    tester,
  ) async {
    var optionsOpened = false;
    final reports = <ImageMetadataImportResult>[];
    final workflow = ImageMetadataImportWorkflow(
      metadataReader: (bytes) async => null,
      optionsPicker: (context, metadata) async {
        optionsOpened = true;
        return const MetadataImportOptions();
      },
      resultReporter: (context, result, appliedCount) => reports.add(result),
    );

    await _pumpAction(
      tester,
      action: (context, ref) => workflow.run(
        context: context,
        read: ref.read,
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(optionsOpened, isFalse);
    expect(reports, [ImageMetadataImportResult.noMetadata]);
  });

  testWidgets('dialog cancellation does not apply or report an error', (
    tester,
  ) async {
    var applied = false;
    final reports = <ImageMetadataImportResult>[];
    final workflow = ImageMetadataImportWorkflow(
      metadataReader: (bytes) async => const NaiImageMetadata(prompt: '1girl'),
      optionsPicker: (context, metadata) async => null,
      metadataApplier: (read, metadata, options, l10n) async {
        applied = true;
        return 1;
      },
      resultReporter: (context, result, appliedCount) => reports.add(result),
    );

    await _pumpAction(
      tester,
      action: (context, ref) => workflow.run(
        context: context,
        read: ref.read,
        bytes: Uint8List.fromList([1]),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(applied, isFalse);
    expect(reports, isEmpty);
  });

  testWidgets('zero applied parameters reports noParametersSelected', (
    tester,
  ) async {
    final reports = <ImageMetadataImportResult>[];
    var openedGeneration = false;
    final workflow = ImageMetadataImportWorkflow(
      metadataReader: (bytes) async => const NaiImageMetadata(prompt: '1girl'),
      optionsPicker: (context, metadata) async =>
          const MetadataImportOptions(importPrompt: true),
      metadataApplier: (read, metadata, options, l10n) async => 0,
      resultReporter: (context, result, appliedCount) => reports.add(result),
      generationPageOpener: (context) => openedGeneration = true,
    );

    await _pumpAction(
      tester,
      action: (context, ref) => workflow.run(
        context: context,
        read: ref.read,
        bytes: Uint8List.fromList([1]),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(reports, [ImageMetadataImportResult.noParametersSelected]);
    expect(openedGeneration, isFalse);
  });

  testWidgets('successful selection applies parameters and opens generation', (
    tester,
  ) async {
    var applyCalls = 0;
    var openedGeneration = false;
    final reports = <(ImageMetadataImportResult, int)>[];
    final workflow = ImageMetadataImportWorkflow(
      metadataReader: (bytes) async => const NaiImageMetadata(prompt: '1girl'),
      optionsPicker: (context, metadata) async =>
          const MetadataImportOptions(importPrompt: true),
      metadataApplier: (read, metadata, options, l10n) async {
        applyCalls++;
        expect(metadata.prompt, '1girl');
        expect(options.importPrompt, isTrue);
        return 1;
      },
      resultReporter: (context, result, appliedCount) {
        reports.add((result, appliedCount));
      },
      generationPageOpener: (context) => openedGeneration = true,
    );

    await _pumpAction(
      tester,
      action: (context, ref) => workflow.run(
        context: context,
        read: ref.read,
        bytes: Uint8List.fromList([1]),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(applyCalls, 1);
    expect(reports, [(ImageMetadataImportResult.applied, 1)]);
    expect(openedGeneration, isTrue);
  });
}

typedef _TestAction =
    Future<Object?> Function(BuildContext context, WidgetRef ref);

Future<void> _pumpAction(
  WidgetTester tester, {
  required _TestAction action,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Consumer(
          builder: (context, ref, child) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => action(context, ref),
              child: const Text('run'),
            ),
          ),
        ),
      ),
    ),
  );
}
