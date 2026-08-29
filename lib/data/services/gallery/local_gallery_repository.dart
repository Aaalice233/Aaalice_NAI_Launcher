import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/exceptions/gallery_exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/local_image_record.dart';
import '../../models/gallery/nai_image_metadata.dart';
import '../../repositories/gallery_folder_repository.dart';
import '../image_metadata_service.dart';
import 'scan_config.dart';

/// File-system and persistence boundary for the local gallery.
class LocalGalleryRepository {
  LocalGalleryRepository({required GalleryDataSource dataSource})
    : _dataSource = dataSource;

  final GalleryDataSource _dataSource;

  Future<List<File>> findGalleryFiles() async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw GalleryPermissionDeniedException(
        path: rootPath,
        message: 'Gallery root path not set',
      );
    }

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      throw GalleryPermissionDeniedException(
        path: rootPath,
        message: 'Gallery folder does not exist: $rootPath',
      );
    }

    var files = <File>[];
    const scanConfig = ScanConfig();
    try {
      await for (final entity in rootDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && scanConfig.acceptsGalleryImagePath(entity.path)) {
          files.add(entity);
        }
      }

      const statBatchSize = 32;
      final validStats = <({File file, FileStat stat})>[];
      for (var start = 0; start < files.length; start += statBatchSize) {
        final end = min(start + statBatchSize, files.length);
        final stats = await Future.wait(
          files.sublist(start, end).map((file) async {
            try {
              return (file: file, stat: await file.stat());
            } catch (_) {
              return null;
            }
          }),
        );
        validStats.addAll(stats.whereType<({File file, FileStat stat})>());
        await Future<void>.delayed(Duration.zero);
      }
      validStats.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));
      files = validStats.map((entry) => entry.file).toList();
    } catch (error) {
      AppLogger.e(
        'Failed to get image files',
        error,
        null,
        'LocalGalleryService',
      );
      throw GalleryFileSystemException(
        path: rootPath,
        operation: FileSystemOperation.list,
        message: 'Failed to list image files',
        cause: error,
      );
    }
    return files;
  }

  Future<List<LocalImageRecord>> loadRecords(
    List<File> files, {
    bool includeErrorPlaceholders = true,
  }) async {
    if (files.isEmpty) return [];

    final fileStats = <File, FileStat>{};
    for (final file in files) {
      try {
        fileStats[file] = await file.stat();
      } catch (_) {
        AppLogger.w('Failed to stat file: ${file.path}', 'LocalGalleryService');
      }
    }

    final paths = files.map((file) => file.path).toList();
    final pathToId = await _dataSource.getImageIdsByPaths(paths);
    final imageIds = pathToId.values.whereType<int>().toList();
    final results = await Future.wait([
      if (imageIds.isNotEmpty)
        _dataSource.getFavoritesByImageIds(imageIds)
      else
        Future.value(<int, bool>{}),
      if (imageIds.isNotEmpty)
        _dataSource.getTagsByImageIds(imageIds)
      else
        Future.value(<int, List<String>>{}),
      if (imageIds.isNotEmpty)
        _dataSource.getMetadataByImageIds(imageIds)
      else
        Future.value(<int, GalleryMetadataRecord?>{}),
    ]);

    final favorites = results[0] as Map<int, bool>;
    final tags = results[1] as Map<int, List<String>>;
    final metadata = results[2] as Map<int, GalleryMetadataRecord?>;
    final records = <LocalImageRecord>[];
    for (final file in files) {
      try {
        final stat = fileStats[file];
        if (stat == null) continue;
        final imageId = pathToId[file.path];
        final metadataRecord = imageId == null ? null : metadata[imageId];
        final imageMetadata = metadataRecord == null
            ? null
            : _buildMetadata(metadataRecord);
        records.add(
          LocalImageRecord(
            path: file.path,
            size: stat.size,
            modifiedAt: stat.modified,
            isFavorite: imageId == null ? false : favorites[imageId] ?? false,
            tags: imageId == null ? const [] : tags[imageId] ?? const [],
            metadata: imageMetadata,
            metadataStatus: imageMetadata == null
                ? MetadataStatus.none
                : imageMetadata.hasData
                ? MetadataStatus.success
                : MetadataStatus.none,
          ),
        );
      } catch (_) {
        AppLogger.w(
          'Failed to load record for ${file.path}',
          'LocalGalleryService',
        );
        if (includeErrorPlaceholders) {
          records.add(
            LocalImageRecord(
              path: file.path,
              size: 0,
              modifiedAt: DateTime.now(),
            ),
          );
        }
      }
    }
    return records;
  }

  Future<bool> toggleFavorite(String filePath) async {
    final file = File(filePath);
    var imageId = await _dataSource.getImageIdByPath(filePath);
    if (imageId == null) {
      if (!await file.exists()) return false;
      final stat = await file.stat();
      imageId = await _dataSource.upsertImage(
        filePath: filePath,
        fileName: p.basename(filePath),
        fileSize: stat.size,
        createdAt: stat.changed,
        modifiedAt: stat.modified,
      );
    }
    return _dataSource.toggleFavorite(imageId);
  }

  Future<bool> isFavorite(String filePath) async {
    final imageId = await _dataSource.getImageIdByPath(filePath);
    return imageId == null ? false : _dataSource.isFavorite(imageId);
  }

  Future<List<GalleryImageRecord>> queryFavoriteImages({required int limit}) =>
      _dataSource.queryFavoriteImages(limit: limit);

  Future<int> getFavoriteCount() => _dataSource.getFavoriteCount();

  Future<NaiImageMetadata?> getMetadata(String filePath) =>
      ImageMetadataService().getMetadataImmediate(filePath);

  Future<bool> addImage(File file, {NaiImageMetadata? metadata}) async {
    final stat = await file.stat();
    final resolvedMetadata = metadata?.hasData == true
        ? metadata
        : await getMetadata(file.path);
    final hasMetadata = resolvedMetadata?.hasData == true;
    final imageId = await _dataSource.upsertImage(
      filePath: file.path,
      fileName: p.basename(file.path),
      fileSize: stat.size,
      width: resolvedMetadata?.width,
      height: resolvedMetadata?.height,
      aspectRatio:
          resolvedMetadata?.width != null &&
              resolvedMetadata?.height != null &&
              resolvedMetadata!.height! > 0
          ? resolvedMetadata.width! / resolvedMetadata.height!
          : null,
      createdAt: stat.modified,
      modifiedAt: stat.modified,
      resolutionKey:
          resolvedMetadata?.width != null && resolvedMetadata?.height != null
          ? '${resolvedMetadata!.width}x${resolvedMetadata.height}'
          : null,
      lastScannedAt: hasMetadata ? DateTime.now() : null,
      metadataStatus: hasMetadata
          ? MetadataStatus.success
          : MetadataStatus.none,
    );
    if (hasMetadata) {
      await _dataSource.upsertMetadata(imageId, resolvedMetadata!);
      ImageMetadataService().cacheMetadata(file.path, resolvedMetadata);
    }
    AppLogger.i(
      '[AddNewImage] Added new image immediately: ${p.basename(file.path)} '
          '(ID: $imageId)',
      'LocalGalleryService',
    );
    return true;
  }

  NaiImageMetadata _buildMetadata(GalleryMetadataRecord record) {
    return NaiImageMetadata(
      prompt: record.prompt,
      negativePrompt: record.negativePrompt,
      seed: record.seed,
      sampler: record.sampler,
      steps: record.steps,
      scale: record.scale,
      width: record.width,
      height: record.height,
      model: record.model,
      smea: record.smea,
      smeaDyn: record.smeaDyn,
      noiseSchedule: record.noiseSchedule,
      cfgRescale: record.cfgRescale,
      ucPreset: record.ucPreset,
      qualityToggle: record.qualityToggle,
      isImg2Img: record.isImg2Img,
      strength: record.strength,
      noise: record.noise,
      software: record.software,
      source: record.source,
      version: record.version,
      rawJson: record.rawJson,
    ).upgradeFromRawJsonIfNeeded();
  }
}
