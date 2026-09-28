import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/database/database_providers.dart';
import '../../core/database/datasources/gallery_data_source.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/local_image_record.dart';
import '../models/gallery/nai_image_metadata.dart';
import 'bulk_gallery_store.dart';
import 'bulk_image_state_service.dart';
import 'bulk_operation_types.dart';

export 'bulk_operation_types.dart';

part 'bulk_operation_service.g.dart';

/// Bulk operation service for managing batch operations on local images
class BulkOperationService {
  final Ref _ref;
  final BulkGalleryStore? _store;

  BulkOperationService({Ref? ref, BulkGalleryStore? store})
    : _ref = ref ?? _FakeRef(),
      _store = store;

  Future<BulkImageStateService> _stateService() async {
    final store = _store;
    if (store != null) return BulkImageStateService(store);
    return BulkImageStateService(
      GalleryDataSourceBulkStore(await _getDataSource()),
    );
  }

  /// 获取 GalleryDataSource
  Future<GalleryDataSource> _getDataSource() async {
    final dbManager = await _ref.read(databaseManagerProvider.future);
    final dataSource = dbManager.getDataSource<GalleryDataSource>('gallery');
    if (dataSource == null) {
      throw StateError('GalleryDataSource not found');
    }
    return dataSource;
  }

  /// 批量删除图片
  Future<BulkOperationResult> bulkDelete(
    List<String> imagePaths, {
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];
    final successfulItems = <String>[];

    AppLogger.i(
      'Starting bulk delete: ${imagePaths.length} images',
      'BulkOperationService',
    );

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(
        current: i,
        total: imagePaths.length,
        currentItem: imagePath,
        isComplete: false,
      );

      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          successCount++;
          successfulItems.add(imagePath);
          AppLogger.d(
            'Deleted: $imagePath ($successCount/${imagePaths.length})',
            'BulkOperationService',
          );
        } else {
          failedCount++;
          errors.add('File not found: $imagePath');
          AppLogger.w('File not found: $imagePath', 'BulkOperationService');
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to delete $imagePath: $e');
        AppLogger.e(
          'Delete failed for $imagePath',
          e,
          null,
          'BulkOperationService',
        );
      }
    }

    onProgress?.call(
      current: imagePaths.length,
      total: imagePaths.length,
      currentItem: '',
      isComplete: true,
    );
    stopwatch.stop();
    AppLogger.i(
      'Bulk delete completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return (
      success: successCount,
      failed: failedCount,
      errors: errors,
      successfulItems: successfulItems,
    );
  }

  /// 批量导出图片元数据到文件
  Future<File?> bulkExport(
    List<LocalImageRecord> records, {
    String outputFormat = 'json',
    bool includeMetadata = true,
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    AppLogger.i(
      'Starting bulk export: ${records.length} images as $outputFormat',
      'BulkOperationService',
    );

    try {
      final outputDir = await _getExportDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final extension = outputFormat.toLowerCase() == 'csv' ? 'csv' : 'json';
      final fileName = 'nai_bulk_export_$timestamp.$extension';
      final filePath = '${outputDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      final exportData = await _prepareExportData(
        records,
        includeMetadata,
        onProgress,
      );

      if (outputFormat.toLowerCase() == 'csv') {
        await _writeCsv(file, exportData, includeMetadata);
      } else {
        await _writeJson(file, exportData, records.length, includeMetadata);
      }

      onProgress?.call(
        current: records.length,
        total: records.length,
        currentItem: '',
        isComplete: true,
      );
      stopwatch.stop();
      AppLogger.i(
        'Bulk export completed: ${records.length} images exported to $fileName in ${stopwatch.elapsedMilliseconds}ms',
        'BulkOperationService',
      );

      return file;
    } catch (e) {
      AppLogger.e('Bulk export failed', e, null, 'BulkOperationService');
      return null;
    }
  }

  Future<Directory> _getExportDirectory() async {
    try {
      return await getDownloadsDirectory() ?? Directory.systemTemp;
    } catch (e) {
      AppLogger.w(
        'Downloads directory not available: $e',
        'BulkOperationService',
      );
      return Directory.systemTemp;
    }
  }

  Future<List<Map<String, dynamic>>> _prepareExportData(
    List<LocalImageRecord> records,
    bool includeMetadata,
    BulkProgressCallback? onProgress,
  ) async {
    final exportData = <Map<String, dynamic>>[];

    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      onProgress?.call(
        current: i,
        total: records.length,
        currentItem: record.path,
        isComplete: false,
      );

      exportData.add(_buildExportMap(record, includeMetadata));
    }

    return exportData;
  }

  Map<String, dynamic> _buildExportMap(
    LocalImageRecord record,
    bool includeMetadata,
  ) {
    final map = <String, dynamic>{
      'path': record.path,
      'fileName': record.path.split(Platform.pathSeparator).last,
      'size': record.size,
      'modifiedAt': record.modifiedAt.toIso8601String(),
      'isFavorite': record.isFavorite,
      'tags': record.tags,
      'metadataStatus': record.metadataStatus.name,
    };

    if (includeMetadata && record.metadata?.hasData == true) {
      map['metadata'] = _buildMetadataMap(record.metadata!);
    }

    return map;
  }

  Map<String, dynamic> _buildMetadataMap(NaiImageMetadata meta) {
    return {
      'prompt': meta.prompt,
      'negativePrompt': meta.negativePrompt,
      'seed': meta.seed,
      'sampler': meta.sampler,
      'steps': meta.steps,
      'scale': meta.scale,
      'width': meta.width,
      'height': meta.height,
      'model': meta.model,
      'smea': meta.smea,
      'smeaDyn': meta.smeaDyn,
      'noiseSchedule': meta.noiseSchedule,
      'cfgRescale': meta.cfgRescale,
      'ucPreset': meta.ucPreset,
      'qualityToggle': meta.qualityToggle,
      'isImg2Img': meta.isImg2Img,
      'strength': meta.strength,
      'noise': meta.noise,
      'software': meta.software,
      'version': meta.version,
      'source': meta.source,
      'characterPrompts': meta.characterPrompts,
      'characterNegativePrompts': meta.characterNegativePrompts,
    };
  }

  Future<void> _writeJson(
    File file,
    List<Map<String, dynamic>> exportData,
    int totalImages,
    bool includeMetadata,
  ) async {
    final jsonData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalImages': totalImages,
      'includeMetadata': includeMetadata,
      'images': exportData,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonData),
    );
  }

  /// 批量编辑元数据（添加/删除标签）
  Future<BulkTagEditOutcome> bulkEditMetadata(
    List<String> imagePaths, {
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
    BulkProgressCallback? onProgress,
  }) async {
    if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
      AppLogger.w(
        'No tags to add or remove, skipping bulk metadata edit',
        'BulkOperationService',
      );
      return BulkTagEditOutcome(
        result: emptyBulkOperationResult,
        previous: const [],
        applied: const [],
      );
    }

    AppLogger.i(
      'Starting bulk metadata edit: ${imagePaths.length} images (add: ${tagsToAdd.length}, remove: ${tagsToRemove.length})',
      'BulkOperationService',
    );

    final stopwatch = Stopwatch()..start();
    final stateService = await _stateService();
    final outcome = await stateService.editTags(
      imagePaths,
      tagsToAdd: tagsToAdd,
      tagsToRemove: tagsToRemove,
      onProgress: onProgress,
    );
    stopwatch.stop();

    AppLogger.i(
      'Bulk metadata edit completed: ${outcome.result.success} succeeded, ${outcome.result.failed} failed in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return outcome;
  }

  /// 按显式目标回放标签，供撤销/重做复用同一条写入路径
  Future<BulkOperationResult> applyTagAssignments(
    List<BulkTagAssignment> assignments, {
    BulkProgressCallback? onProgress,
  }) async {
    if (assignments.isEmpty) return emptyBulkOperationResult;

    final stateService = await _stateService();
    return stateService.applyTagAssignments(
      assignments,
      onProgress: onProgress,
    );
  }

  /// 批量切换收藏状态
  Future<BulkFavoriteOutcome> bulkToggleFavorite(
    List<String> imagePaths, {
    required bool isFavorite,
    BulkProgressCallback? onProgress,
  }) async {
    AppLogger.i(
      'Starting bulk toggle favorite: ${imagePaths.length} images -> $isFavorite',
      'BulkOperationService',
    );

    final stopwatch = Stopwatch()..start();
    final stateService = await _stateService();
    final outcome = await stateService.setFavorites(
      imagePaths,
      isFavorite: isFavorite,
      onProgress: onProgress,
    );
    stopwatch.stop();

    AppLogger.i(
      'Bulk toggle favorite completed: ${outcome.result.success} succeeded, ${outcome.result.failed} failed in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return outcome;
  }

  /// 按显式目标回放收藏状态，供撤销/重做复用同一条写入路径
  Future<BulkOperationResult> applyFavoriteAssignments(
    List<BulkFavoriteAssignment> assignments, {
    BulkProgressCallback? onProgress,
  }) async {
    if (assignments.isEmpty) return emptyBulkOperationResult;

    final stateService = await _stateService();
    return stateService.applyFavoriteAssignments(
      assignments,
      onProgress: onProgress,
    );
  }

  Future<void> _writeCsv(
    File file,
    List<Map<String, dynamic>> data,
    bool includeMetadata,
  ) async {
    final buffer = StringBuffer();
    final baseHeaders = [
      'fileName',
      'size',
      'modifiedAt',
      'isFavorite',
      'tags',
      'metadataStatus',
    ];
    final metaHeaders = [
      'prompt',
      'negativePrompt',
      'seed',
      'sampler',
      'steps',
      'scale',
      'width',
      'height',
      'model',
    ];

    buffer.writeln(
      (includeMetadata ? [...baseHeaders, ...metaHeaders] : baseHeaders).join(
        ',',
      ),
    );

    for (final row in data) {
      final values = [
        _escapeCsv(row['fileName'].toString()),
        row['size'].toString(),
        _escapeCsv(row['modifiedAt'].toString()),
        row['isFavorite'].toString(),
        _escapeCsv((row['tags'] as List).join('; ')),
        _escapeCsv(row['metadataStatus'].toString()),
      ];

      if (includeMetadata) {
        final meta = row['metadata'] as Map<String, dynamic>?;
        values.addAll([
          _escapeCsv(meta?['prompt']?.toString() ?? ''),
          _escapeCsv(meta?['negativePrompt']?.toString() ?? ''),
          meta?['seed']?.toString() ?? '',
          _escapeCsv(meta?['sampler']?.toString() ?? ''),
          meta?['steps']?.toString() ?? '',
          meta?['scale']?.toString() ?? '',
          meta?['width']?.toString() ?? '',
          meta?['height']?.toString() ?? '',
          _escapeCsv(meta?['model']?.toString() ?? ''),
        ]);
      }

      buffer.writeln(values.join(','));
    }

    await file.writeAsString(buffer.toString());
  }

  String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// Fake Ref for when no ref is provided (for backward compatibility)
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// BulkOperationService Provider
@riverpod
BulkOperationService bulkOperationService(Ref ref) {
  return BulkOperationService(ref: ref);
}
