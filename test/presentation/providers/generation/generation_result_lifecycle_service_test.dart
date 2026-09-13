import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import 'package:nai_launcher/data/services/metadata/hash_calculator.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_result_lifecycle_service.dart';
import 'package:nai_launcher/presentation/services/generation_history_storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('自动保存会将最终图片逐张发布到系统相册', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nai_generation_media_store_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final bytes = Uint8List.fromList(
      image_lib.encodePng(image_lib.Image(width: 2, height: 2)),
    );
    final images = List.generate(
      2,
      (_) => GeneratedImage.create(
        bytes,
        width: 2,
        height: 2,
        preserveOriginalBytesOnSave: true,
      ),
    );
    final published = <({String sourcePath, String fileName})>[];
    var indexedPaths = <String>[];
    var statisticsCount = 0;
    final service = GenerationResultLifecycleService(
      GenerationResultLifecycleDependencies(
        historyStorage: GenerationHistoryStorageService(enabled: false),
        resolveGalleryRootPath: () async => directory.path,
        addGalleryImages: (paths) async {
          indexedPaths = paths;
          return paths.length;
        },
        refreshGallery: () async {},
        incrementStatistics: (count) async => statisticsCount += count,
        publishToSystemGallery: (sourcePath, fileName) async {
          published.add((sourcePath: sourcePath, fileName: fileName));
        },
      ),
    );

    final result = await service.saveImages(
      images,
      const ImageParams(seed: 123),
      snapshot: const GenerationSaveSnapshot(),
    );

    expect(result.savedPaths, hasLength(2));
    expect(result.systemGalleryExportFailureCount, 0);
    expect(indexedPaths, result.savedPaths);
    expect(statisticsCount, 2);
    expect(published, hasLength(2));
    for (var index = 0; index < result.savedPaths.length; index++) {
      expect(published[index].sourcePath, result.savedPaths[index]);
      expect(published[index].fileName, p.basename(result.savedPaths[index]));
      expect(await File(published[index].sourcePath).readAsBytes(), bytes);
    }
  });

  test('系统相册发布失败不回滚应用图库自动保存', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nai_generation_media_store_failure_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final bytes = Uint8List.fromList(
      image_lib.encodePng(image_lib.Image(width: 2, height: 2)),
    );
    var indexedCount = 0;
    final service = GenerationResultLifecycleService(
      GenerationResultLifecycleDependencies(
        historyStorage: GenerationHistoryStorageService(enabled: false),
        resolveGalleryRootPath: () async => directory.path,
        addGalleryImages: (paths) async => indexedCount = paths.length,
        refreshGallery: () async {},
        incrementStatistics: (_) async {},
        publishToSystemGallery: (_, _) async => throw StateError('denied'),
      ),
    );

    final result = await service.saveImages(
      [
        GeneratedImage.create(
          bytes,
          width: 2,
          height: 2,
          preserveOriginalBytesOnSave: true,
        ),
      ],
      const ImageParams(seed: 456),
      snapshot: const GenerationSaveSnapshot(),
    );

    expect(result.savedPaths, hasLength(1));
    expect(result.systemGalleryExportFailureCount, 1);
    expect(indexedCount, 1);
    expect(await File(result.savedPaths.single).exists(), isTrue);
    expect(result.images.single.filePath, result.savedPaths.single);
  });

  group('固定词使用记录', () {
    late Directory hiveDirectory;

    setUp(() async {
      hiveDirectory = await Directory.systemTemp.createTemp(
        'nai_generation_fixed_usage_hive_',
      );
      Hive.init(hiveDirectory.path);
    });

    tearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    Future<Uint8List> novelAiBytes() =>
        ImageSaveUtils.rebuildImageBytesWithMetadata(
          imageBytes: Uint8List.fromList(
            image_lib.encodePng(image_lib.Image(width: 2, height: 2)),
          ),
          params: const ImageParams(
            prompt: 'masterpiece, subject',
            width: 2,
            height: 2,
          ),
          actualSeed: 321,
        );

    GenerationResultLifecycleService buildService(Directory directory) =>
        GenerationResultLifecycleService(
          GenerationResultLifecycleDependencies(
            historyStorage: GenerationHistoryStorageService(enabled: false),
            resolveGalleryRootPath: () async => directory.path,
            addGalleryImages: (paths) async => paths.length,
            refreshGallery: () async {},
            incrementStatistics: (_) async {},
          ),
        );

    test('自动保存不改写 NAI 字节，快照写入旁路记录库', () async {
      final directory = await Directory.systemTemp.createTemp(
        'nai_generation_fixed_snapshot_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = await novelAiBytes();
      const generatedSnapshot = FixedTagUsageSnapshot(
        entries: [
          FixedTagUsageEntry(
            fixedTagId: 'a',
            name: 'A',
            content: 'masterpiece',
            weight: 1,
            renderedContent: 'masterpiece',
            position: FixedTagPosition.prefix,
            promptType: FixedTagPromptType.positive,
            order: 0,
          ),
        ],
      );

      final result = await buildService(directory).saveImages(
        [
          GeneratedImage.create(
            bytes,
            width: 2,
            height: 2,
            fixedTagUsageSnapshot: generatedSnapshot,
          ),
        ],
        const ImageParams(prompt: 'changed later', seed: 999),
        snapshot: const GenerationSaveSnapshot(
          fixedTagUsageSnapshot: FixedTagUsageSnapshot(),
        ),
      );
      final saved = await File(result.savedPaths.single).readAsBytes();

      expect(saved, orderedEquals(bytes));
      final metadata = UnifiedMetadataParser.parseFromPng(saved).metadata!;
      expect(metadata.fixedTagUsageData, isNull);
      expect(
        FixedTagUsageRecordStore()
            .lookup(FileHashCalculator().calculateFromBytes(bytes))
            ?.entries
            .single
            .fixedTagId,
        'a',
      );
    });

    test('未启用固定词时同样记录空快照', () async {
      final directory = await Directory.systemTemp.createTemp(
        'nai_generation_empty_snapshot_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = await novelAiBytes();

      final result = await buildService(directory).saveImages(
        [GeneratedImage.create(bytes, width: 2, height: 2)],
        const ImageParams(seed: 321),
        snapshot: const GenerationSaveSnapshot(
          fixedTagUsageSnapshot: FixedTagUsageSnapshot(),
        ),
      );

      expect(result.savedPaths, hasLength(1));
      final recorded = FixedTagUsageRecordStore().lookup(
        FileHashCalculator().calculateFromBytes(bytes),
      );
      expect(recorded, isNotNull);
      expect(recorded!.entries, isEmpty);
    });
  });
}
