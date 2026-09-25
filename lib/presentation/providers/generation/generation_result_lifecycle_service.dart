import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_save_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/gallery/gallery_index_admission.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../services/generation_history_storage_service.dart';
import 'generation_models.dart';

class GenerationResultLifecycleDependencies {
  const GenerationResultLifecycleDependencies({
    required this.historyStorage,
    required this.resolveGalleryRootPath,
    required this.addGalleryImages,
    required this.refreshGallery,
    required this.removeGalleryImages,
    required this.deleteGalleryFile,
    required this.incrementStatistics,
    this.publishToSystemGallery,
  });

  final GenerationHistoryStorageService historyStorage;
  final Future<String?> Function() resolveGalleryRootPath;
  final Future<GalleryIndexAdmission> Function(List<String> paths)
  addGalleryImages;
  final Future<void> Function() refreshGallery;
  final Future<void> Function(List<String> paths) removeGalleryImages;

  /// 文件已不存在时返回 `false`。
  final Future<bool> Function(String path) deleteGalleryFile;
  final Future<void> Function(int count) incrementStatistics;
  final Future<void> Function(String sourcePath, String fileName)?
  publishToSystemGallery;
}

class GenerationSaveSnapshot {
  const GenerationSaveSnapshot({
    this.fixedTagUsageSnapshot,
    this.useCoords = false,
  });

  final FixedTagUsageSnapshot? fixedTagUsageSnapshot;
  final bool useCoords;
}

class GenerationSaveResult {
  const GenerationSaveResult(
    this.images,
    this.savedPaths, {
    this.systemGalleryExportFailureCount = 0,
  });

  final List<GeneratedImage> images;
  final List<String> savedPaths;
  final int systemGalleryExportFailureCount;
}

class SavedFileDeletionResult {
  const SavedFileDeletionResult({
    this.deletedPaths = const [],
    this.failures = const {},
  });

  final List<String> deletedPaths;
  final Map<String, Object> failures;
}

class GeneratedImageRemovalResult {
  const GeneratedImageRemovalResult({
    this.removedCount = 0,
    this.files = const SavedFileDeletionResult(),
  });

  final int removedCount;
  final SavedFileDeletionResult files;
}

class ExternalImagePreparationResult {
  const ExternalImagePreparationResult({
    required this.image,
    required this.params,
  });

  final GeneratedImage image;
  final ImageParams params;
}

/// Handles durable/result-side effects. It never reads Ref and never mutates
/// ImageGenerationState; callers apply its typed results through the reducer.
class GenerationResultLifecycleService {
  const GenerationResultLifecycleService(this.dependencies);

  static const int historyLimit = 50;

  final GenerationResultLifecycleDependencies dependencies;

  Future<List<GeneratedImage>> loadHistory() =>
      dependencies.historyStorage.load();

  Future<void> persistHistory({
    required Iterable<GeneratedImage> changedImages,
    required List<String> order,
  }) => dependencies.historyStorage.persistImages(
    changedImages: changedImages,
    order: order,
  );

  Future<void> flushHistory() => dependencies.historyStorage.flush();

  List<GeneratedImage> mergeHistory(
    List<GeneratedImage> current,
    List<GeneratedImage> restored,
  ) {
    final seen = <String>{};
    return <GeneratedImage>[
      for (final image in current)
        if (seen.add(image.id)) image,
      for (final image in restored)
        if (seen.add(image.id)) image,
    ].take(historyLimit).toList(growable: false);
  }

  Future<ExternalImagePreparationResult> prepareExternalImage(
    Uint8List bytes, {
    required ImageParams params,
    int? width,
    int? height,
    ImageComparisonSource? comparisonSource,
    required bool embedNaiMetadata,
  }) async {
    final size =
        _resolveImageSize(bytes, width: width, height: height) ??
        (params.width, params.height);
    final effectiveParams = params.copyWith(width: size.$1, height: size.$2);
    final Uint8List normalized;
    if (embedNaiMetadata) {
      final metadata = await ImageMetadataService().getMetadataFromBytes(bytes);
      normalized = await ImageSaveUtils.rebuildImageBytesWithMetadata(
        imageBytes: bytes,
        params: effectiveParams,
        actualSeed: metadata?.seed,
      );
    } else {
      normalized = bytes;
    }
    return ExternalImagePreparationResult(
      image: GeneratedImage.create(
        normalized,
        width: size.$1,
        height: size.$2,
        comparisonSource: comparisonSource,
        preserveOriginalBytesOnSave: !embedNaiMetadata,
      ),
      params: effectiveParams,
    );
  }

  Future<GenerationSaveResult> saveImages(
    List<GeneratedImage> images,
    ImageParams params, {
    required GenerationSaveSnapshot snapshot,
    String? directoryPath,
    bool syncToGalleryIndex = true,
  }) async {
    String? rootPath;
    try {
      rootPath = directoryPath ?? await dependencies.resolveGalleryRootPath();
    } catch (error, stackTrace) {
      AppLogger.e('自动保存失败', error, stackTrace);
      return GenerationSaveResult(images, const []);
    }
    if (rootPath == null) return GenerationSaveResult(images, const []);
    final directory = Directory(rootPath);
    try {
      if (!await directory.exists()) await directory.create(recursive: true);
    } catch (error, stackTrace) {
      AppLogger.e('自动保存失败', error, stackTrace);
      return GenerationSaveResult(images, const []);
    }

    final charCaptions = <Map<String, dynamic>>[];
    final charNegCaptions = <Map<String, dynamic>>[];
    for (final character in params.characters) {
      charCaptions.add({
        'char_caption': character.prompt,
        'centers': [
          {'x': 0.5, 'y': 0.5},
        ],
      });
      charNegCaptions.add({
        'char_caption': character.negativePrompt,
        'centers': [
          {'x': 0.5, 'y': 0.5},
        ],
      });
    }

    final updated = <GeneratedImage>[];
    final paths = <String>[];
    var systemGalleryExportFailureCount = 0;
    for (final image in images) {
      try {
        final hasMetadata = ImageSaveUtils.hasEmbeddedNovelAiMetadata(
          image.bytes,
        );
        var actualSeed = params.seed;
        if (actualSeed < 0 || hasMetadata) {
          final metadata = await ImageMetadataService().getMetadataFromBytes(
            image.bytes,
          );
          actualSeed = metadata?.seed ?? actualSeed;
          if (actualSeed < 0) {
            actualSeed = Random().nextInt(4294967295);
          }
        }
        final saved = await ImageSaveUtils.saveResultImage(
          rootPath: rootPath,
          imageBytes: image.bytes,
          preserveOriginalBytes: image.preserveOriginalBytesOnSave,
          fixedTagUsageSnapshot:
              image.fixedTagUsageSnapshot ?? snapshot.fixedTagUsageSnapshot,
          seed: actualSeed,
          rebuild: () => ImageSaveUtils.rebuildImageBytesWithMetadata(
            imageBytes: image.bytes,
            params: params.copyWith(width: image.width, height: image.height),
            actualSeed: actualSeed,
            charCaptions: charCaptions,
            charNegCaptions: charNegCaptions,
            useCoords: snapshot.useCoords,
            useStealth: false,
          ),
        );
        final path = saved.path;
        paths.add(path);
        updated.add(image.copyWithFilePath(path));
        final publishToSystemGallery = dependencies.publishToSystemGallery;
        if (publishToSystemGallery != null) {
          try {
            await publishToSystemGallery(path, p.basename(path));
          } catch (error, stackTrace) {
            systemGalleryExportFailureCount++;
            AppLogger.e('自动保存到系统相册失败', error, stackTrace);
          }
        }
      } catch (error, stackTrace) {
        AppLogger.e('自动保存图像失败', error, stackTrace);
        updated.add(image);
      }
    }

    if (paths.isNotEmpty) {
      if (syncToGalleryIndex) {
        try {
          // 全量重扫要枚举整个图库根目录，只有索引与磁盘真的对不上才值得付这个代价。
          final admission = await dependencies.addGalleryImages(paths);
          if (admission.requiresFullRescan) {
            await dependencies.refreshGallery();
          }
        } catch (error, stackTrace) {
          AppLogger.e('自动保存图库索引更新失败', error, stackTrace);
        }
      }
      try {
        await dependencies.incrementStatistics(paths.length);
      } catch (error) {
        AppLogger.w('统计缓存增量更新失败: $error', 'AutoSave');
      }
      preloadMetadata(updated.where((image) => image.filePath != null));
    }
    return GenerationSaveResult(
      updated,
      paths,
      systemGalleryExportFailureCount: systemGalleryExportFailureCount,
    );
  }

  /// 单个文件失败不阻断其余文件；只把真正删掉的路径移出图库索引。
  Future<SavedFileDeletionResult> deleteSavedFiles(
    Iterable<String> paths,
  ) async {
    final deleted = <String>[];
    final failures = <String, Object>{};
    for (final path in paths.toSet()) {
      try {
        if (await dependencies.deleteGalleryFile(path)) deleted.add(path);
      } catch (error, stackTrace) {
        AppLogger.e('删除生成结果的图库文件失败', error, stackTrace);
        failures[path] = error;
      }
    }
    if (deleted.isNotEmpty) {
      try {
        await dependencies.removeGalleryImages(deleted);
      } catch (error, stackTrace) {
        AppLogger.e('删除后更新图库索引失败', error, stackTrace);
      }
    }
    return SavedFileDeletionResult(
      deletedPaths: List.unmodifiable(deleted),
      failures: Map.unmodifiable(failures),
    );
  }

  void preloadMetadata(Iterable<GeneratedImage> images) {
    final service = ImageMetadataService();
    for (final image in images) {
      service.enqueuePreload(
        taskId: image.id,
        filePath: image.filePath,
        bytes: image.filePath == null ? image.bytes : null,
      );
    }
  }

  (int, int)? _resolveImageSize(Uint8List bytes, {int? width, int? height}) {
    final encoded = NaiResolutionAdapter.readImageSize(bytes);
    if (encoded != null) return encoded;
    if (width != null && height != null) return (width, height);
    return null;
  }
}
