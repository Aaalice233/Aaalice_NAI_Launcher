import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/data/models/image/image_params.dart';
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
}
