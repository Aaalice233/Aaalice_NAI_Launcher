import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/app_logger.dart';
import '../models/gallery/local_image_record.dart';
import '../repositories/local_gallery_repository.dart';

part 'bulk_operation_service.g.dart';

/// Progress callback for bulk operations
///
/// [current] 当前处理的索引（从 0 开始）
/// [total] 总数
/// [currentItem] 当前正在处理的文件路径
/// [isComplete] 是否完成
typedef BulkProgressCallback = void Function({
  required int current,
  required int total,
  required String currentItem,
  required bool isComplete,
});

/// Bulk operation result
///
/// [success] 成功的数量
/// [failed] 失败的数量
/// [errors] 失败的文件路径及错误信息
typedef BulkOperationResult = ({
  int success,
  int failed,
  List<String> errors,
});

/// Bulk operation service for managing batch operations on local images
///
/// 提供批量删除、批量导出、批量元数据编辑功能
/// 支持进度回调，可在长时间运行的操作中提供实时反馈
///
/// Provides bulk delete, export, and metadata editing capabilities
/// Supports progress callbacks for real-time feedback during long-running operations
class BulkOperationService {
  /// Gallery repository instance
  final LocalGalleryRepository _galleryRepository;

  /// Constructor with dependency injection
  ///
  /// 构造函数，支持依赖注入
  BulkOperationService({
    LocalGalleryRepository? galleryRepository,
  }) : _galleryRepository =
            galleryRepository ?? LocalGalleryRepository.instance;

  /// Bulk delete images
  ///
  /// [imagePaths] List of image file paths to delete
  /// [onProgress] Optional progress callback
  /// Returns operation result with success/failed counts and errors
  ///
  /// 批量删除图片
  /// 返回操作结果（成功数、失败数、错误列表）
  Future<BulkOperationResult> bulkDelete(
    List<String> imagePaths, {
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    int successCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    AppLogger.i(
      'Starting bulk delete: ${imagePaths.length} images',
      'BulkOperationService',
    );

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];

      // Report progress
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
          AppLogger.d(
            'Deleted: $imagePath ($successCount/${imagePaths.length})',
            'BulkOperationService',
          );
        } else {
          failedCount++;
          final error = 'File not found: $imagePath';
          errors.add(error);
          AppLogger.w(error, 'BulkOperationService');
        }
      } catch (e) {
        failedCount++;
        final error = 'Failed to delete $imagePath: $e';
        errors.add(error);
        AppLogger.e(
          'Delete failed for $imagePath',
          e,
          null,
          'BulkOperationService',
        );
      }
    }

    // Final progress update
    onProgress?.call(
      current: imagePaths.length,
      total: imagePaths.length,
      currentItem: '',
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk delete completed: $successCount succeeded, $failedCount failed '
          'in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return (
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// Bulk export image metadata to JSON file
  ///
  /// [records] List of image records to export
  /// [outputFormat] Export format ('json' or 'csv')
  /// [includeMetadata] Whether to include full NAI metadata
  /// [onProgress] Optional progress callback
  /// Returns the exported file path, or null if failed
  ///
  /// 批量导出图片元数据到文件
  /// 支持 JSON 和 CSV 格式
  /// 返回导出的文件路径，失败返回 null
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
      // Try to get downloads directory, fall back to temp directory
      Directory? outputDir;
      try {
        outputDir = await getDownloadsDirectory();
      } catch (e) {
        // getDownloadsDirectory throws on some platforms (e.g., Windows)
        AppLogger.w(
          'Downloads directory not available on this platform: $e',
          'BulkOperationService',
        );
      }

      // Fallback to system temp directory for testing or unsupported platforms
      outputDir ??= Directory.systemTemp;
      AppLogger.d(
        'Using export directory: ${outputDir.path}',
        'BulkOperationService',
      );

      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final extension = outputFormat.toLowerCase() == 'csv' ? 'csv' : 'json';
      final fileName = 'nai_bulk_export_$timestamp.$extension';
      final filePath = '${outputDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      // Prepare export data
      final exportData = <Map<String, dynamic>>[];

      for (var i = 0; i < records.length; i++) {
        final record = records[i];

        // Report progress
        onProgress?.call(
          current: i,
          total: records.length,
          currentItem: record.path,
          isComplete: false,
        );

        final map = <String, dynamic>{
          'path': record.path,
          'fileName': record.path.split(Platform.pathSeparator).last,
          'size': record.size,
          'modifiedAt': record.modifiedAt.toIso8601String(),
          'isFavorite': record.isFavorite,
          'tags': record.tags,
          'metadataStatus': record.metadataStatus.name,
        };

        // Include full metadata if requested
        if (includeMetadata && record.metadata != null && record.metadata!.hasData) {
          final meta = record.metadata!;
          map['metadata'] = {
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

        exportData.add(map);
      }

      // Write to file
      if (outputFormat.toLowerCase() == 'csv') {
        await _writeCsv(file, exportData, includeMetadata);
      } else {
        final jsonData = {
          'exportedAt': DateTime.now().toIso8601String(),
          'totalImages': records.length,
          'includeMetadata': includeMetadata,
          'images': exportData,
        };
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(jsonData),
        );
      }

      // Final progress update
      onProgress?.call(
        current: records.length,
        total: records.length,
        currentItem: '',
        isComplete: true,
      );

      stopwatch.stop();
      AppLogger.i(
        'Bulk export completed: ${records.length} images exported to $fileName '
            'in ${stopwatch.elapsedMilliseconds}ms',
        'BulkOperationService',
      );

      return file;
    } catch (e) {
      AppLogger.e(
        'Bulk export failed',
        e,
        null,
        'BulkOperationService',
      );
      return null;
    }
  }

  /// Bulk edit metadata (add/remove tags)
  ///
  /// [imagePaths] List of image file paths to edit
  /// [tagsToAdd] Tags to add to each image
  /// [tagsToRemove] Tags to remove from each image
  /// [onProgress] Optional progress callback
  /// Returns operation result with success/failed counts and errors
  ///
  /// 批量编辑元数据（添加/删除标签）
  /// 返回操作结果（成功数、失败数、错误列表）
  Future<BulkOperationResult> bulkEditMetadata(
    List<String> imagePaths, {
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    int successCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
      AppLogger.w(
        'No tags to add or remove, skipping bulk metadata edit',
        'BulkOperationService',
      );
      return (
        success: 0,
        failed: 0,
        errors: <String>[],
      );
    }

    AppLogger.i(
      'Starting bulk metadata edit: ${imagePaths.length} images '
          '(add: ${tagsToAdd.length}, remove: ${tagsToRemove.length})',
      'BulkOperationService',
    );

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];

      // Report progress
      onProgress?.call(
        current: i,
        total: imagePaths.length,
        currentItem: imagePath,
        isComplete: false,
      );

      try {
        // Get current tags
        final currentTags = _galleryRepository.getTags(imagePath);

        // Add new tags (avoid duplicates)
        final updatedTags = List<String>.from(currentTags);
        for (final tag in tagsToAdd) {
          if (!updatedTags.contains(tag)) {
            updatedTags.add(tag);
          }
        }

        // Remove tags
        for (final tag in tagsToRemove) {
          updatedTags.remove(tag);
        }

        // Save updated tags
        await _galleryRepository.setTags(imagePath, updatedTags);
        successCount++;

        AppLogger.d(
          'Updated tags for $imagePath: ${currentTags.length} -> ${updatedTags.length} '
              '($successCount/${imagePaths.length})',
          'BulkOperationService',
        );
      } catch (e) {
        failedCount++;
        final error = 'Failed to edit metadata for $imagePath: $e';
        errors.add(error);
        AppLogger.e(
          'Metadata edit failed for $imagePath',
          e,
          null,
          'BulkOperationService',
        );
      }
    }

    // Final progress update
    onProgress?.call(
      current: imagePaths.length,
      total: imagePaths.length,
      currentItem: '',
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk metadata edit completed: $successCount succeeded, $failedCount failed '
          'in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return (
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// Bulk toggle favorite status
  ///
  /// [imagePaths] List of image file paths to toggle
  /// [isFavorite] Favorite status to set
  /// [onProgress] Optional progress callback
  /// Returns operation result with success/failed counts and errors
  ///
  /// 批量切换收藏状态
  /// 返回操作结果（成功数、失败数、错误列表）
  Future<BulkOperationResult> bulkToggleFavorite(
    List<String> imagePaths, {
    required bool isFavorite,
    BulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    int successCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    AppLogger.i(
      'Starting bulk toggle favorite: ${imagePaths.length} images -> $isFavorite',
      'BulkOperationService',
    );

    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];

      // Report progress
      onProgress?.call(
        current: i,
        total: imagePaths.length,
        currentItem: imagePath,
        isComplete: false,
      );

      try {
        await _galleryRepository.setFavorite(imagePath, isFavorite);
        successCount++;
        AppLogger.d(
          'Set favorite: $imagePath -> $isFavorite ($successCount/${imagePaths.length})',
          'BulkOperationService',
        );
      } catch (e) {
        failedCount++;
        final error = 'Failed to toggle favorite for $imagePath: $e';
        errors.add(error);
        AppLogger.e(
          'Toggle favorite failed for $imagePath',
          e,
          null,
          'BulkOperationService',
        );
      }
    }

    // Final progress update
    onProgress?.call(
      current: imagePaths.length,
      total: imagePaths.length,
      currentItem: '',
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk toggle favorite completed: $successCount succeeded, $failedCount failed '
          'in ${stopwatch.elapsedMilliseconds}ms',
      'BulkOperationService',
    );

    return (
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// Write export data to CSV format
  ///
  /// [file] Output file
  /// [data] Export data
  /// [includeMetadata] Whether to include metadata columns
  ///
  /// 将导出数据写入 CSV 格式
  Future<void> _writeCsv(
    File file,
    List<Map<String, dynamic>> data,
    bool includeMetadata,
  ) async {
    final buffer = StringBuffer();

    // CSV header
    final headers = [
      'fileName',
      'size',
      'modifiedAt',
      'isFavorite',
      'tags',
      'metadataStatus',
    ];

    if (includeMetadata) {
      headers.addAll([
        'prompt',
        'negativePrompt',
        'seed',
        'sampler',
        'steps',
        'scale',
        'width',
        'height',
        'model',
      ]);
    }

    buffer.writeln(headers.join(','));

    // CSV rows
    for (final row in data) {
      final values = [
        _escapeCsv(row['fileName'].toString()),
        row['size'].toString(),
        _escapeCsv(row['modifiedAt'].toString()),
        row['isFavorite'].toString(),
        _escapeCsv((row['tags'] as List).join('; ')),
        _escapeCsv(row['metadataStatus'].toString()),
      ];

      if (includeMetadata && row['metadata'] != null) {
        final meta = row['metadata'] as Map<String, dynamic>;
        values.addAll([
          _escapeCsv(meta['prompt']?.toString() ?? ''),
          _escapeCsv(meta['negativePrompt']?.toString() ?? ''),
          meta['seed']?.toString() ?? '',
          _escapeCsv(meta['sampler']?.toString() ?? ''),
          meta['steps']?.toString() ?? '',
          meta['scale']?.toString() ?? '',
          meta['width']?.toString() ?? '',
          meta['height']?.toString() ?? '',
          _escapeCsv(meta['model']?.toString() ?? ''),
        ]);
      } else if (includeMetadata) {
        values.addAll(['', '', '', '', '', '', '', '', '']);
      }

      buffer.writeln(values.join(','));
    }

    await file.writeAsString(buffer.toString());
  }

  /// Escape CSV value (wrap in quotes if contains comma, quote, or newline)
  ///
  /// 转义 CSV 值（如果包含逗号、引号或换行符则用引号包裹）
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

/// BulkOperationService Provider
@riverpod
BulkOperationService bulkOperationService(Ref ref) {
  return BulkOperationService();
}
