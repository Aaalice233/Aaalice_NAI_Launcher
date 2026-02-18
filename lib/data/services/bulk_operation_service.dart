import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_logger.dart';
import '../models/gallery/local_image_record.dart';
import '../models/gallery/nai_image_metadata.dart';
import '../repositories/local_gallery_repository.dart';

part 'bulk_operation_service.g.dart';

/// Progress callback for bulk operations
typedef BulkProgressCallback = void Function({
  required int current,
  required int total,
  required String currentItem,
  required bool isComplete,
});

/// Bulk operation result
typedef BulkOperationResult = ({
  int success,
  int failed,
  List<String> errors,
});

/// Bulk operation service for managing batch operations on local images
class BulkOperationService {
  final LocalGalleryRepository _galleryRepository;

  BulkOperationService({LocalGalleryRepository? galleryRepository})
      : _galleryRepository = galleryRepository ?? LocalGalleryRepository.instance;

  /// 批量删除图片
  Future<BulkOperationResult> bulkDelete(
    List<String> imagePaths, {
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    AppLogger.i('Starting bulk delete: ${imagePaths.length} images', 'BulkOperationService');

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(current: i, total: imagePaths.length, currentItem: imagePath, isComplete: false);

      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          successCount++;
          AppLogger.d('Deleted: $imagePath ($successCount/${imagePaths.length})', 'BulkOperationService');
        } else {
          failedCount++;
          errors.add('File not found: $imagePath');
          AppLogger.w('File not found: $imagePath', 'BulkOperationService');
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to delete $imagePath: $e');
        AppLogger.e('Delete failed for $imagePath', e, null, 'BulkOperationService');
      }
    }

    onProgress?.call(current: imagePaths.length, total: imagePaths.length, currentItem: '', isComplete: true);
    stopwatch.stop();
    AppLogger.i(
      'Bulk delete completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return (success: successCount, failed: failedCount, errors: errors);
  }

  /// 批量导出图片元数据到文件
  Future<File?> bulkExport(
    List<LocalImageRecord> records, {
    String outputFormat = 'json',
    bool includeMetadata = true,
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    AppLogger.i('Starting bulk export: ${records.length} images as $outputFormat', 'BulkOperationService');

    try {
      final outputDir = await _getExportDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final extension = outputFormat.toLowerCase() == 'csv' ? 'csv' : 'json';
      final fileName = 'nai_bulk_export_$timestamp.$extension';
      final filePath = '${outputDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      final exportData = await _prepareExportData(records, includeMetadata, onProgress);

      if (outputFormat.toLowerCase() == 'csv') {
        await _writeCsv(file, exportData, includeMetadata);
      } else {
        await _writeJson(file, exportData, records.length, includeMetadata);
      }

      onProgress?.call(current: records.length, total: records.length, currentItem: '', isComplete: true);
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
      AppLogger.w('Downloads directory not available: $e', 'BulkOperationService');
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
      onProgress?.call(current: i, total: records.length, currentItem: record.path, isComplete: false);

      exportData.add(_buildExportMap(record, includeMetadata));
    }

    return exportData;
  }

  Map<String, dynamic> _buildExportMap(LocalImageRecord record, bool includeMetadata) {
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
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonData));
  }

  /// 批量编辑元数据（添加/删除标签）
  Future<BulkOperationResult> bulkEditMetadata(
    List<String> imagePaths, {
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
      AppLogger.w('No tags to add or remove, skipping bulk metadata edit', 'BulkOperationService');
      return (success: 0, failed: 0, errors: <String>[]);
    }

    AppLogger.i(
      'Starting bulk metadata edit: ${imagePaths.length} images (add: ${tagsToAdd.length}, remove: ${tagsToRemove.length})',
      'BulkOperationService',
    );

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(current: i, total: imagePaths.length, currentItem: imagePath, isComplete: false);

      try {
        final currentTags = await _galleryRepository.getTags(imagePath);
        final updatedTags = List<String>.from(currentTags)
          ..addAll(tagsToAdd.where((tag) => !currentTags.contains(tag)))
          ..removeWhere((tag) => tagsToRemove.contains(tag));

        await _galleryRepository.setTags(imagePath, updatedTags);
        successCount++;
        AppLogger.d(
          'Updated tags for $imagePath: ${currentTags.length} -> ${updatedTags.length} ($successCount/${imagePaths.length})',
          'BulkOperationService',
        );
      } catch (e) {
        failedCount++;
        errors.add('Failed to edit metadata for $imagePath: $e');
        AppLogger.e('Metadata edit failed for $imagePath', e, null, 'BulkOperationService');
      }
    }

    onProgress?.call(current: imagePaths.length, total: imagePaths.length, currentItem: '', isComplete: true);
    stopwatch.stop();
    AppLogger.i(
      'Bulk metadata edit completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return (success: successCount, failed: failedCount, errors: errors);
  }

  /// 批量切换收藏状态
  Future<BulkOperationResult> bulkToggleFavorite(
    List<String> imagePaths, {
    required bool isFavorite,
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    AppLogger.i(
      'Starting bulk toggle favorite: ${imagePaths.length} images -> $isFavorite',
      'BulkOperationService',
    );

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      onProgress?.call(current: i, total: imagePaths.length, currentItem: imagePath, isComplete: false);

      try {
        await _galleryRepository.setFavorite(imagePath, isFavorite);
        successCount++;
        AppLogger.d(
          'Set favorite: $imagePath -> $isFavorite ($successCount/${imagePaths.length})',
          'BulkOperationService',
        );
      } catch (e) {
        failedCount++;
        errors.add('Failed to toggle favorite for $imagePath: $e');
        AppLogger.e('Toggle favorite failed for $imagePath', e, null, 'BulkOperationService');
      }
    }

    onProgress?.call(current: imagePaths.length, total: imagePaths.length, currentItem: '', isComplete: true);
    stopwatch.stop();
    AppLogger.i(
      'Bulk toggle favorite completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return (success: successCount, failed: failedCount, errors: errors);
  }

  Future<void> _writeCsv(
    File file,
    List<Map<String, dynamic>> data,
    bool includeMetadata,
  ) async {
    final buffer = StringBuffer();
    final baseHeaders = ['fileName', 'size', 'modifiedAt', 'isFavorite', 'tags', 'metadataStatus'];
    final metaHeaders = ['prompt', 'negativePrompt', 'seed', 'sampler', 'steps', 'scale', 'width', 'height', 'model'];

    buffer.writeln((includeMetadata ? [...baseHeaders, ...metaHeaders] : baseHeaders).join(','));

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
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// BulkOperationService Provider
@riverpod
BulkOperationService bulkOperationService(Ref ref) {
  return BulkOperationService();
}
