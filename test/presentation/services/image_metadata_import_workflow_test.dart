import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata_import_selection_store.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/services/image_metadata_import_workflow.dart';
import 'package:nai_launcher/presentation/services/mobile_image_metadata_importer.dart';
import 'package:nai_launcher/presentation/utils/fixed_tag_import_resolution.dart';

import '../../helpers/content_hash.dart';
import '../../helpers/image_metadata_service_sandbox.dart';
import '../../helpers/memory_local_storage.dart';

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
      optionsPicker: (context, metadata, initialOptions) async {
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
      optionsPicker: (context, metadata, initialOptions) async => null,
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
      optionsPicker: (context, metadata, initialOptions) async =>
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
      optionsPicker: (context, metadata, initialOptions) async =>
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

  group('上次勾选的记忆', () {
    ImageMetadataImportWorkflow buildWorkflow({
      required MetadataImportOptionsPicker picker,
      MetadataImportApplier? applier,
      List<ImageMetadataImportResult>? reports,
    }) => ImageMetadataImportWorkflow(
      metadataReader: (bytes) async =>
          const NaiImageMetadata(prompt: '1girl', seed: 7),
      optionsPicker: picker,
      metadataApplier: applier ?? (read, metadata, options, l10n) async => 1,
      resultReporter: (context, result, appliedCount) => reports?.add(result),
      generationPageOpener: (context) {},
    );

    Future<void> pumpImport(
      WidgetTester tester,
      ImageMetadataImportWorkflow workflow,
      MetadataImportSelectionStore store,
    ) => _pumpAction(
      tester,
      selectionStore: store,
      action: (context, ref) => workflow.run(
        context: context,
        read: ref.read,
        bytes: Uint8List.fromList([1]),
      ),
    );

    testWidgets('确认后的类别开关成为下一次导入的初始勾选', (tester) async {
      final store = _RecordingSelectionStore();
      final offered = <MetadataImportOptions>[];
      final workflow = buildWorkflow(
        picker: (context, metadata, initialOptions) async {
          offered.add(initialOptions);
          return initialOptions.copyWith(
            importSeed: false,
            selectedCharacterIndices: [0],
          );
        },
      );

      await pumpImport(tester, workflow, store);
      for (var round = 0; round < 2; round++) {
        await tester.tap(find.text('run'));
        await tester.pumpAndSettle();
      }

      expect(offered, [
        MetadataImportOptions.all(),
        MetadataImportOptions.all().copyWith(importSeed: false),
      ]);
      expect(store.saved, hasLength(2));
    });

    testWidgets('取消对话框不改动已记住的勾选', (tester) async {
      final store = _RecordingSelectionStore();
      final remembered = MetadataImportOptions.all().copyWith(
        importSeed: false,
      );
      await store.save(remembered);
      store.saved.clear();
      MetadataImportOptions? offered;
      final workflow = buildWorkflow(
        picker: (context, metadata, initialOptions) async {
          offered = initialOptions;
          return null;
        },
      );

      await pumpImport(tester, workflow, store);
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();

      expect(offered, remembered);
      expect(store.saved, isEmpty);
      expect(store.load(), remembered);
    });

    testWidgets('记忆写入失败时仍完成已确认的导入', (tester) async {
      final store = _RecordingSelectionStore(failSave: true);
      final reports = <ImageMetadataImportResult>[];
      var applyCalls = 0;
      final workflow = buildWorkflow(
        picker: (context, metadata, initialOptions) async =>
            const MetadataImportOptions(importPrompt: true),
        applier: (read, metadata, options, l10n) async {
          applyCalls++;
          return 1;
        },
        reports: reports,
      );

      await pumpImport(tester, workflow, store);
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();

      expect(store.saved, hasLength(1));
      expect(applyCalls, 1);
      expect(reports, [ImageMetadataImportResult.applied]);
    });
  });

  group('固定词导入判定', () {
    const qualityBlock =
        '<quality>\n2::best quality::,masterpiece,very aesthetic, highres, '
        'absurdres, highly finished\n</quality>';
    useImageMetadataServiceSandbox();

    Future<Uint8List> buildImage(String prompt) =>
        ImageSaveUtils.rebuildImageBytesWithMetadata(
          imageBytes: Uint8List.fromList(
            img.encodePng(img.Image(width: 2, height: 2)),
          ),
          params: ImageParams(prompt: prompt, width: 2, height: 2),
          actualSeed: 219,
        );

    test('没有记录时同名词库条目仍会被推断为固定词', () async {
      final bytes = await buildImage('$qualityBlock, 1girl');
      final metadata = await ImageMetadataService().getMetadataFromBytes(bytes);

      final resolution = resolveFixedTagImport(
        metadata: metadata!,
        entries: [FixedTagEntry.create(name: '质量词', content: qualityBlock)],
      );

      expect(resolution.source, FixedTagImportSource.currentLibrary);
      expect(resolution.metadata.mainPrompt, '1girl');
    });

    test('记录库中的空快照阻断词库推断', () async {
      final bytes = await buildImage('$qualityBlock, 1girl');
      await FixedTagUsageRecordStore().record(
        contentHash: contentHashOf(bytes),
        snapshot: const FixedTagUsageSnapshot(),
      );
      final metadata = await ImageMetadataService().getMetadataFromBytes(bytes);

      final resolution = resolveFixedTagImport(
        metadata: metadata!,
        entries: [FixedTagEntry.create(name: '质量词', content: qualityBlock)],
      );

      expect(resolution.source, FixedTagImportSource.structured);
      expect(resolution.snapshot?.entries, isEmpty);
      expect(resolution.metadata.fixedPrefixTags, isEmpty);
      expect(resolution.metadata.mainPrompt, '$qualityBlock, 1girl');
    });
  });
}

typedef _TestAction =
    Future<Object?> Function(BuildContext context, WidgetRef ref);

class _RecordingSelectionStore extends MetadataImportSelectionStore {
  _RecordingSelectionStore({this.failSave = false})
    : super(MemoryLocalStorage());

  final bool failSave;
  final saved = <MetadataImportOptions>[];

  @override
  Future<void> save(MetadataImportOptions options) async {
    saved.add(options);
    if (failSave) throw const FileSystemException('disk full');
    await super.save(options);
  }
}

Future<void> _pumpAction(
  WidgetTester tester, {
  required _TestAction action,
  MetadataImportSelectionStore? selectionStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        metadataImportSelectionStoreProvider.overrideWithValue(
          selectionStore ?? _RecordingSelectionStore(),
        ),
      ],
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
