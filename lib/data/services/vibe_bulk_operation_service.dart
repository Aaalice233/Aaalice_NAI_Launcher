import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/vibe/vibe_export_format.dart';
import '../models/vibe/vibe_export_options.dart';
import '../models/vibe/vibe_library_entry.dart';
import 'vibe_export_service.dart';
import 'vibe_library_storage_service.dart';

part 'vibe_bulk_operation_service.g.dart';

/// Vibe 批量操作类型
enum VibeBulkOperationType {
  /// 删除条目
  delete,

  /// 移动条目到指定分类
  move,

  /// 切换收藏状态
  toggleFavorite,

  /// 添加标签
  addTags,

  /// 移除标签
  removeTags,

  /// 导出条目
  export,
}

/// Vibe 批量操作结果
class VibeBulkOperationResult {
  const VibeBulkOperationResult({
    required this.successCount,
    required this.failedCount,
    required this.errors,
    this.exportedFilePath,
  });

  /// 成功数量
  final int successCount;

  /// 失败数量
  final int failedCount;

  /// 错误信息列表
  final List<String> errors;

  /// 导出文件路径（仅在导出操作时有值）
  final String? exportedFilePath;

  /// 操作总数
  int get totalCount => successCount + failedCount;

  /// 是否全部成功
  bool get isAllSuccess => failedCount == 0;

  /// 是否全部失败
  bool get isAllFailed => successCount == 0;

  /// 是否有错误
  bool get hasErrors => errors.isNotEmpty;

  factory VibeBulkOperationResult.success() {
    return const VibeBulkOperationResult(
      successCount: 0,
      failedCount: 0,
      errors: [],
    );
  }

  factory VibeBulkOperationResult.fromResult({
    required int success,
    required int failed,
    required List<String> errors,
    String? exportedFilePath,
  }) {
    return VibeBulkOperationResult(
      successCount: success,
      failedCount: failed,
      errors: errors,
      exportedFilePath: exportedFilePath,
    );
  }
}

/// 批量操作进度回调
///
/// [current] - 当前处理数量
/// [total] - 总数
/// [currentItem] - 当前处理的条目名称
/// [operationType] - 当前操作类型
/// [isComplete] - 是否完成
typedef VibeBulkProgressCallback = void Function({
  required int current,
  required int total,
  required String currentItem,
  required VibeBulkOperationType operationType,
  required bool isComplete,
});

/// Vibe 批量操作服务
///
/// 提供对 Vibe 库条目的批量操作功能，包括：
/// - 批量删除
/// - 批量移动分类
/// - 批量切换收藏
/// - 批量编辑标签
/// - 批量导出
class VibeBulkOperationService {
  final VibeLibraryStorageService _storageService;
  final VibeExportService _exportService;

  VibeBulkOperationService({
    VibeLibraryStorageService? storageService,
    VibeExportService? exportService,
  })  : _storageService = storageService ?? VibeLibraryStorageService(),
        _exportService = exportService ?? VibeExportService();

  static const String _tag = 'VibeBulkOperation';

  /// 批量删除 Vibe 条目
  ///
  /// [entryIds] - 要删除的条目 ID 列表
  /// [onProgress] - 进度回调
  Future<VibeBulkOperationResult> bulkDelete(
    List<String> entryIds, {
    VibeBulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    AppLogger.i('Starting bulk delete: ${entryIds.length} entries', _tag);

    for (var i = 0; i < entryIds.length; i++) {
      final entryId = entryIds[i];
      final entry = await _storageService.getEntry(entryId);
      final entryName = entry?.displayName ?? entryId;

      onProgress?.call(
        current: i,
        total: entryIds.length,
        currentItem: entryName,
        operationType: VibeBulkOperationType.delete,
        isComplete: false,
      );

      try {
        final deleted = await _storageService.deleteEntry(entryId);
        if (deleted) {
          successCount++;
          AppLogger.d('Deleted: $entryName ($successCount/${entryIds.length})', _tag);
        } else {
          failedCount++;
          errors.add('Entry not found or delete failed: $entryName');
          AppLogger.w('Delete failed: $entryName', _tag);
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to delete $entryName: $e');
        AppLogger.e('Delete failed for $entryName', e, null, _tag);
      }
    }

    onProgress?.call(
      current: entryIds.length,
      total: entryIds.length,
      currentItem: '',
      operationType: VibeBulkOperationType.delete,
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk delete completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      _tag,
    );

    return VibeBulkOperationResult.fromResult(
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// 批量移动条目到指定分类
  ///
  /// [entryIds] - 要移动的条目 ID 列表
  /// [targetCategoryId] - 目标分类 ID（null 表示移动到根级）
  /// [onProgress] - 进度回调
  Future<VibeBulkOperationResult> bulkMoveToCategory(
    List<String> entryIds, {
    required String? targetCategoryId,
    VibeBulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    AppLogger.i(
      'Starting bulk move: ${entryIds.length} entries to category ${targetCategoryId ?? "root"}',
      _tag,
    );

    for (var i = 0; i < entryIds.length; i++) {
      final entryId = entryIds[i];
      final entry = await _storageService.getEntry(entryId);
      final entryName = entry?.displayName ?? entryId;

      onProgress?.call(
        current: i,
        total: entryIds.length,
        currentItem: entryName,
        operationType: VibeBulkOperationType.move,
        isComplete: false,
      );

      try {
        final updatedEntry = await _storageService.updateEntryCategory(
          entryId,
          targetCategoryId,
        );
        if (updatedEntry != null) {
          successCount++;
          AppLogger.d('Moved: $entryName ($successCount/${entryIds.length})', _tag);
        } else {
          failedCount++;
          errors.add('Entry not found: $entryName');
          AppLogger.w('Move failed - entry not found: $entryName', _tag);
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to move $entryName: $e');
        AppLogger.e('Move failed for $entryName', e, null, _tag);
      }
    }

    onProgress?.call(
      current: entryIds.length,
      total: entryIds.length,
      currentItem: '',
      operationType: VibeBulkOperationType.move,
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk move completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      _tag,
    );

    return VibeBulkOperationResult.fromResult(
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// 批量切换收藏状态
  ///
  /// [entryIds] - 要切换的条目 ID 列表
  /// [isFavorite] - 目标收藏状态
  /// [onProgress] - 进度回调
  Future<VibeBulkOperationResult> bulkToggleFavorite(
    List<String> entryIds, {
    required bool isFavorite,
    VibeBulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    AppLogger.i(
      'Starting bulk favorite toggle: ${entryIds.length} entries -> $isFavorite',
      _tag,
    );

    for (var i = 0; i < entryIds.length; i++) {
      final entryId = entryIds[i];
      final entry = await _storageService.getEntry(entryId);
      final entryName = entry?.displayName ?? entryId;

      onProgress?.call(
        current: i,
        total: entryIds.length,
        currentItem: entryName,
        operationType: VibeBulkOperationType.toggleFavorite,
        isComplete: false,
      );

      try {
        final currentEntry = await _storageService.getEntry(entryId);
        if (currentEntry == null) {
          failedCount++;
          errors.add('Entry not found: $entryName');
          continue;
        }

        // 如果当前状态与目标状态相同，跳过
        if (currentEntry.isFavorite == isFavorite) {
          successCount++;
          continue;
        }

        final updatedEntry = await _storageService.toggleFavorite(entryId);
        if (updatedEntry != null) {
          successCount++;
          AppLogger.d('Favorite toggled: $entryName ($successCount/${entryIds.length})', _tag);
        } else {
          failedCount++;
          errors.add('Failed to toggle favorite: $entryName');
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to toggle favorite for $entryName: $e');
        AppLogger.e('Toggle favorite failed for $entryName', e, null, _tag);
      }
    }

    onProgress?.call(
      current: entryIds.length,
      total: entryIds.length,
      currentItem: '',
      operationType: VibeBulkOperationType.toggleFavorite,
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk favorite toggle completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      _tag,
    );

    return VibeBulkOperationResult.fromResult(
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// 批量添加标签
  ///
  /// [entryIds] - 要添加标签的条目 ID 列表
  /// [tags] - 要添加的标签列表
  /// [onProgress] - 进度回调
  Future<VibeBulkOperationResult> bulkAddTags(
    List<String> entryIds, {
    required List<String> tags,
    VibeBulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    if (tags.isEmpty) {
      AppLogger.w('No tags to add, skipping bulk add tags', _tag);
      return VibeBulkOperationResult.success();
    }

    AppLogger.i(
      'Starting bulk add tags: ${entryIds.length} entries, tags: ${tags.join(", ")}',
      _tag,
    );

    for (var i = 0; i < entryIds.length; i++) {
      final entryId = entryIds[i];
      final entry = await _storageService.getEntry(entryId);
      final entryName = entry?.displayName ?? entryId;

      onProgress?.call(
        current: i,
        total: entryIds.length,
        currentItem: entryName,
        operationType: VibeBulkOperationType.addTags,
        isComplete: false,
      );

      try {
        final currentEntry = await _storageService.getEntry(entryId);
        if (currentEntry == null) {
          failedCount++;
          errors.add('Entry not found: $entryName');
          continue;
        }

        // 合并现有标签和新标签（去重）
        final updatedTags = <String>{...currentEntry.tags, ...tags}.toList();
        final updatedEntry = await _storageService.updateEntryTags(
          entryId,
          updatedTags,
        );

        if (updatedEntry != null) {
          successCount++;
          AppLogger.d('Tags added: $entryName ($successCount/${entryIds.length})', _tag);
        } else {
          failedCount++;
          errors.add('Failed to add tags: $entryName');
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to add tags for $entryName: $e');
        AppLogger.e('Add tags failed for $entryName', e, null, _tag);
      }
    }

    onProgress?.call(
      current: entryIds.length,
      total: entryIds.length,
      currentItem: '',
      operationType: VibeBulkOperationType.addTags,
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk add tags completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      _tag,
    );

    return VibeBulkOperationResult.fromResult(
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// 批量移除标签
  ///
  /// [entryIds] - 要移除标签的条目 ID 列表
  /// [tags] - 要移除的标签列表
  /// [onProgress] - 进度回调
  Future<VibeBulkOperationResult> bulkRemoveTags(
    List<String> entryIds, {
    required List<String> tags,
    VibeBulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    if (tags.isEmpty) {
      AppLogger.w('No tags to remove, skipping bulk remove tags', _tag);
      return VibeBulkOperationResult.success();
    }

    AppLogger.i(
      'Starting bulk remove tags: ${entryIds.length} entries, tags: ${tags.join(", ")}',
      _tag,
    );

    for (var i = 0; i < entryIds.length; i++) {
      final entryId = entryIds[i];
      final entry = await _storageService.getEntry(entryId);
      final entryName = entry?.displayName ?? entryId;

      onProgress?.call(
        current: i,
        total: entryIds.length,
        currentItem: entryName,
        operationType: VibeBulkOperationType.removeTags,
        isComplete: false,
      );

      try {
        final currentEntry = await _storageService.getEntry(entryId);
        if (currentEntry == null) {
          failedCount++;
          errors.add('Entry not found: $entryName');
          continue;
        }

        // 移除指定标签
        final updatedTags = currentEntry.tags.where((t) => !tags.contains(t)).toList();
        final updatedEntry = await _storageService.updateEntryTags(
          entryId,
          updatedTags,
        );

        if (updatedEntry != null) {
          successCount++;
          AppLogger.d('Tags removed: $entryName ($successCount/${entryIds.length})', _tag);
        } else {
          failedCount++;
          errors.add('Failed to remove tags: $entryName');
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to remove tags for $entryName: $e');
        AppLogger.e('Remove tags failed for $entryName', e, null, _tag);
      }
    }

    onProgress?.call(
      current: entryIds.length,
      total: entryIds.length,
      currentItem: '',
      operationType: VibeBulkOperationType.removeTags,
      isComplete: true,
    );

    stopwatch.stop();
    AppLogger.i(
      'Bulk remove tags completed: $successCount succeeded, $failedCount failed in ${stopwatch.elapsedMilliseconds}ms',
      _tag,
    );

    return VibeBulkOperationResult.fromResult(
      success: successCount,
      failed: failedCount,
      errors: errors,
    );
  }

  /// 批量导出 Vibe 条目
  ///
  /// [entries] - 要导出的条目列表
  /// [options] - 导出选项
  /// [onProgress] - 进度回调
  Future<VibeBulkOperationResult> bulkExport(
    List<VibeLibraryEntry> entries, {
    required VibeExportOptions options,
    VibeBulkProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    AppLogger.i(
      'Starting bulk export: ${entries.length} entries as ${options.format.displayName}',
      _tag,
    );

    try {
      String? exportedFilePath;

      // 根据导出格式执行不同的导出逻辑
      switch (options.format) {
        case VibeExportFormat.bundle:
          exportedFilePath = await _exportService.exportAsBundle(
            entries,
            options: options,
            onProgress: (current, total, currentItem) {
              onProgress?.call(
                current: current,
                total: total,
                currentItem: currentItem,
                operationType: VibeBulkOperationType.export,
                isComplete: false,
              );
            },
          );
          break;
        case VibeExportFormat.embeddedImage:
          // 嵌入图片格式暂不支持批量导出，导出第一个
          if (entries.isNotEmpty) {
            exportedFilePath = await _exportService.exportAsEmbeddedImage(
              entries.first,
              options: options,
            );
          }
          break;
        case VibeExportFormat.encoding:
          exportedFilePath = await _exportService.exportAsEncoding(
            entries,
            options: options,
            onProgress: (current, total, currentItem) {
              onProgress?.call(
                current: current,
                total: total,
                currentItem: currentItem,
                operationType: VibeBulkOperationType.export,
                isComplete: false,
              );
            },
          );
          break;
      }

      onProgress?.call(
        current: entries.length,
        total: entries.length,
        currentItem: '',
        operationType: VibeBulkOperationType.export,
        isComplete: true,
      );

      stopwatch.stop();

      if (exportedFilePath != null) {
        AppLogger.i(
          'Bulk export completed: ${entries.length} entries exported to $exportedFilePath in ${stopwatch.elapsedMilliseconds}ms',
          _tag,
        );
        return VibeBulkOperationResult.fromResult(
          success: entries.length,
          failed: 0,
          errors: [],
          exportedFilePath: exportedFilePath,
        );
      } else {
        AppLogger.e('Bulk export failed: no file was created', null, null, _tag);
        return VibeBulkOperationResult.fromResult(
          success: 0,
          failed: entries.length,
          errors: ['Export failed: no file was created'],
        );
      }
    } catch (e) {
      stopwatch.stop();
      AppLogger.e('Bulk export failed', e, null, _tag);
      return VibeBulkOperationResult.fromResult(
        success: 0,
        failed: entries.length,
        errors: ['Export failed: $e'],
      );
    }
  }

  /// 组合批量操作
  ///
  /// 在单个方法调用中执行多个批量操作
  /// [operations] - 操作配置列表
  Future<List<VibeBulkOperationResult>> executeMultiple(
    List<BulkOperationConfig> operations, {
    void Function(int current, int total, VibeBulkOperationType type)? onOperationStart,
  }) async {
    final results = <VibeBulkOperationResult>[];

    for (var i = 0; i < operations.length; i++) {
      final config = operations[i];
      onOperationStart?.call(i, operations.length, config.type);

      final result = switch (config.type) {
        VibeBulkOperationType.delete => await bulkDelete(config.entryIds),
        VibeBulkOperationType.move => await bulkMoveToCategory(
            config.entryIds,
            targetCategoryId: config.targetCategoryId,
          ),
        VibeBulkOperationType.toggleFavorite => await bulkToggleFavorite(
            config.entryIds,
            isFavorite: config.boolValue ?? true,
          ),
        VibeBulkOperationType.addTags => await bulkAddTags(
            config.entryIds,
            tags: config.tags ?? [],
          ),
        VibeBulkOperationType.removeTags => await bulkRemoveTags(
            config.entryIds,
            tags: config.tags ?? [],
          ),
        VibeBulkOperationType.export => throw UnsupportedError(
            'Export operation is not supported in executeMultiple, use bulkExport instead',
          ),
      };

      results.add(result);
    }

    return results;
  }
}

/// 批量操作配置
///
/// 用于组合多个批量操作的配置类
class BulkOperationConfig {
  const BulkOperationConfig({
    required this.type,
    required this.entryIds,
    this.targetCategoryId,
    this.boolValue,
    this.tags,
  });

  /// 操作类型
  final VibeBulkOperationType type;

  /// 条目 ID 列表
  final List<String> entryIds;

  /// 目标分类 ID（用于 move 操作）
  final String? targetCategoryId;

  /// 布尔值（用于 toggleFavorite 操作）
  final bool? boolValue;

  /// 标签列表（用于 addTags/removeTags 操作）
  final List<String>? tags;

  /// 创建删除操作配置
  factory BulkOperationConfig.delete(List<String> entryIds) {
    return BulkOperationConfig(
      type: VibeBulkOperationType.delete,
      entryIds: entryIds,
    );
  }

  /// 创建移动操作配置
  factory BulkOperationConfig.move(
    List<String> entryIds, {
    required String? targetCategoryId,
  }) {
    return BulkOperationConfig(
      type: VibeBulkOperationType.move,
      entryIds: entryIds,
      targetCategoryId: targetCategoryId,
    );
  }

  /// 创建切换收藏操作配置
  factory BulkOperationConfig.toggleFavorite(
    List<String> entryIds, {
    required bool isFavorite,
  }) {
    return BulkOperationConfig(
      type: VibeBulkOperationType.toggleFavorite,
      entryIds: entryIds,
      boolValue: isFavorite,
    );
  }

  /// 创建添加标签操作配置
  factory BulkOperationConfig.addTags(
    List<String> entryIds, {
    required List<String> tags,
  }) {
    return BulkOperationConfig(
      type: VibeBulkOperationType.addTags,
      entryIds: entryIds,
      tags: tags,
    );
  }

  /// 创建移除标签操作配置
  factory BulkOperationConfig.removeTags(
    List<String> entryIds, {
    required List<String> tags,
  }) {
    return BulkOperationConfig(
      type: VibeBulkOperationType.removeTags,
      entryIds: entryIds,
      tags: tags,
    );
  }
}

/// VibeBulkOperationService Provider
@riverpod
VibeBulkOperationService vibeBulkOperationService(Ref ref) {
  final storageService = ref.watch(vibeLibraryStorageServiceProvider);
  return VibeBulkOperationService(storageService: storageService);
}
