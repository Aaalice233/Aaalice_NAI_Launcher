import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_save_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../services/generation_history_storage_service.dart';
import 'generation_models.dart';

class GenerationResultLifecycleDependencies {
  const GenerationResultLifecycleDependencies({
    required this.historyStorage,
    required this.resolveGalleryRootPath,
    required this.addGalleryImages,
    required this.refreshGallery,
    required this.incrementStatistics,
  });

  final GenerationHistoryStorageService historyStorage;
  final Future<String?> Function() resolveGalleryRootPath;
  final Future<int> Function(List<String> paths) addGalleryImages;
  final Future<void> Function() refreshGallery;
  final Future<void> Function(int count) incrementStatistics;
}

class GenerationSaveSnapshot {
  const GenerationSaveSnapshot({
    this.fixedPrefixTags = const [],
    this.fixedSuffixTags = const [],
    this.fixedNegativePrefixTags = const [],
    this.fixedNegativeSuffixTags = const [],
    this.useCoords = false,
  });

  final List<String> fixedPrefixTags;
  final List<String> fixedSuffixTags;
  final List<String> fixedNegativePrefixTags;
  final List<String> fixedNegativeSuffixTags;
  final bool useCoords;
}

class GenerationSaveResult {
  const GenerationSaveResult(this.images, this.savedPaths);

  final List<GeneratedImage> images;
  final List<String> savedPaths;
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
        final bytes = image.preserveOriginalBytesOnSave || hasMetadata
            ? image.bytes
            : await ImageSaveUtils.rebuildImageBytesWithMetadata(
                imageBytes: image.bytes,
                params: params.copyWith(
                  width: image.width,
                  height: image.height,
                ),
                actualSeed: actualSeed,
                fixedPrefixTags: snapshot.fixedPrefixTags,
                fixedSuffixTags: snapshot.fixedSuffixTags,
                fixedNegativePrefixTags: snapshot.fixedNegativePrefixTags,
                fixedNegativeSuffixTags: snapshot.fixedNegativeSuffixTags,
                charCaptions: charCaptions,
                charNegCaptions: charNegCaptions,
                useCoords: snapshot.useCoords,
                useStealth: false,
              );
        final path = await ImageSaveUtils.saveBytesToDatedPath(
          rootPath: rootPath,
          bytes: bytes,
          seed: actualSeed,
        );
        paths.add(path);
        updated.add(image.copyWithFilePath(path));
      } catch (error, stackTrace) {
        AppLogger.e('自动保存图像失败', error, stackTrace);
        updated.add(image);
      }
    }

    if (paths.isNotEmpty) {
      if (syncToGalleryIndex) {
        try {
          final added = await dependencies.addGalleryImages(paths);
          if (added < paths.length) await dependencies.refreshGallery();
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
    return GenerationSaveResult(updated, paths);
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
