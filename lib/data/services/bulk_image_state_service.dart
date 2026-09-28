import 'dart:io';

import '../../core/utils/app_logger.dart';
import '../../core/utils/bulk_tag_edit_utils.dart';
import 'bulk_gallery_store.dart';
import 'bulk_operation_types.dart';

const String _logTag = 'BulkImageStateService';

/// 批量标签与收藏的原状态批读和按计划写入
///
/// 读取阶段按批次一次取回图片 ID 与原状态，写入阶段只按已确定的目标执行。
class BulkImageStateService {
  const BulkImageStateService(this._store);

  final BulkGalleryStore _store;

  /// 单批读取的图片数量，上限受 SQLite 变量数量约束
  static const int readBatchSize = 200;

  /// 批量增删标签，读回的原标签同时作为撤销快照与写入输入
  Future<BulkTagEditOutcome> editTags(
    List<String> imagePaths, {
    required List<String> tagsToAdd,
    required List<String> tagsToRemove,
    BulkProgressCallback? onProgress,
  }) async {
    final resolved = await _resolveImageIds(imagePaths);
    final currentTags = await _readInBatches(
      resolved.idsByPath.values.toList(),
      _store.getTagsByImageIds,
    );

    final planned = _plan<List<String>>(resolved, (path, imageId) {
      final failure = currentTags.failures[imageId];
      if (failure != null) return _PlannedItem<List<String>>.failed(failure);
      return _PlannedItem<List<String>>.target(
        imageId,
        applyBulkTagChanges(
          currentTags.values[imageId] ?? const <String>[],
          tagsToAdd: tagsToAdd,
          tagsToRemove: tagsToRemove,
        ),
      );
    });

    final result = await _writePlanned<List<String>>(
      orderedPaths: imagePaths,
      planned: planned,
      write: _store.setImageTags,
      describeFailure: _describeTagFailure,
      logLabel: 'Metadata edit',
      onProgress: onProgress,
    );

    final succeeded = result.successfulItems.toSet();
    return BulkTagEditOutcome(
      result: result,
      previous: [
        for (final path in succeeded)
          BulkTagAssignment(
            path: path,
            tags:
                currentTags.values[resolved.idsByPath[path]] ??
                const <String>[],
          ),
      ],
      applied: [
        for (final path in succeeded)
          BulkTagAssignment(path: path, tags: planned[path]!.target!),
      ],
    );
  }

  /// 按显式目标写入标签，供撤销/重做回放，不再读取当前标签
  Future<BulkOperationResult> applyTagAssignments(
    List<BulkTagAssignment> assignments, {
    BulkProgressCallback? onProgress,
  }) async {
    final orderedPaths = [for (final item in assignments) item.path];
    final targets = {for (final item in assignments) item.path: item.tags};

    final resolved = await _resolveImageIds(orderedPaths);
    final planned = _plan<List<String>>(
      resolved,
      (path, imageId) =>
          _PlannedItem<List<String>>.target(imageId, targets[path]!),
    );

    return _writePlanned<List<String>>(
      orderedPaths: orderedPaths,
      planned: planned,
      write: _store.setImageTags,
      describeFailure: _describeTagFailure,
      logLabel: 'Metadata edit',
      onProgress: onProgress,
    );
  }

  /// 批量设置收藏，读回的原状态同时作为撤销快照与切换依据
  Future<BulkFavoriteOutcome> setFavorites(
    List<String> imagePaths, {
    required bool isFavorite,
    BulkProgressCallback? onProgress,
  }) => _applyFavorites([
    for (final path in imagePaths)
      BulkFavoriteAssignment(path: path, isFavorite: isFavorite),
  ], onProgress: onProgress);

  /// 按显式目标写入收藏状态，供撤销/重做回放
  Future<BulkOperationResult> applyFavoriteAssignments(
    List<BulkFavoriteAssignment> assignments, {
    BulkProgressCallback? onProgress,
  }) async {
    final outcome = await _applyFavorites(assignments, onProgress: onProgress);
    return outcome.result;
  }

  Future<BulkFavoriteOutcome> _applyFavorites(
    List<BulkFavoriteAssignment> assignments, {
    BulkProgressCallback? onProgress,
  }) async {
    final orderedPaths = [for (final item in assignments) item.path];
    final targets = {
      for (final item in assignments) item.path: item.isFavorite,
    };

    final resolved = await _resolveImageIds(orderedPaths);
    final currentFavorites = await _readInBatches(
      resolved.idsByPath.values.toList(),
      _store.getFavoritesByImageIds,
    );

    final planned = _plan<bool>(resolved, (path, imageId) {
      final failure = currentFavorites.failures[imageId];
      if (failure != null) return _PlannedItem<bool>.failed(failure);
      return _PlannedItem<bool>.target(imageId, targets[path]!);
    });

    final result = await _writePlanned<bool>(
      orderedPaths: orderedPaths,
      planned: planned,
      write: (imageId, target) async {
        if ((currentFavorites.values[imageId] ?? false) != target) {
          await _store.toggleFavorite(imageId);
        }
      },
      describeFailure: _describeFavoriteFailure,
      logLabel: 'Toggle favorite',
      onProgress: onProgress,
    );

    final succeeded = result.successfulItems.toSet();
    return BulkFavoriteOutcome(
      result: result,
      previous: [
        for (final path in succeeded)
          BulkFavoriteAssignment(
            path: path,
            isFavorite:
                currentFavorites.values[resolved.idsByPath[path]] ?? false,
          ),
      ],
      applied: [
        for (final path in succeeded)
          BulkFavoriteAssignment(path: path, isFavorite: targets[path]!),
      ],
    );
  }

  Future<_ResolvedPaths> _resolveImageIds(List<String> paths) async {
    final idsByPath = <String, int>{};
    final failures = <String, Object>{};
    final unindexed = <String>[];

    for (final chunk in _chunk(paths.toSet().toList(), readBatchSize)) {
      try {
        final ids = await _store.getImageIdsByPaths(chunk);
        for (final path in chunk) {
          final id = ids[path];
          if (id == null) {
            unindexed.add(path);
          } else {
            idsByPath[path] = id;
          }
        }
      } catch (e) {
        for (final path in chunk) {
          failures[path] = e;
        }
      }
    }

    // 未索引图片必须先读取文件属性建立记录，这一步无法合批。
    for (final path in unindexed) {
      try {
        idsByPath[path] = await _indexImage(path);
      } catch (e) {
        failures[path] = e;
      }
    }

    return _ResolvedPaths(idsByPath: idsByPath, failures: failures);
  }

  Future<int> _indexImage(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final stat = await file.stat();
    return _store.upsertImage(
      filePath: path,
      fileName: path.split(Platform.pathSeparator).last,
      fileSize: stat.size,
      createdAt: stat.changed,
      modifiedAt: stat.modified,
    );
  }

  Future<_BatchRead<T>> _readInBatches<T>(
    List<int> imageIds,
    Future<Map<int, T>> Function(List<int> imageIds) read,
  ) async {
    final values = <int, T>{};
    final failures = <int, Object>{};

    for (final chunk in _chunk(imageIds, readBatchSize)) {
      try {
        values.addAll(await read(chunk));
      } catch (e) {
        for (final id in chunk) {
          failures[id] = e;
        }
      }
    }

    return _BatchRead(values: values, failures: failures);
  }

  Map<String, _PlannedItem<T>> _plan<T>(
    _ResolvedPaths resolved,
    _PlannedItem<T> Function(String path, int imageId) planItem,
  ) {
    return {
      for (final entry in resolved.idsByPath.entries)
        entry.key: planItem(entry.key, entry.value),
      for (final entry in resolved.failures.entries)
        entry.key: _PlannedItem<T>.failed(entry.value),
    };
  }

  Future<BulkOperationResult> _writePlanned<T>({
    required List<String> orderedPaths,
    required Map<String, _PlannedItem<T>> planned,
    required Future<void> Function(int imageId, T target) write,
    required String Function(String path, Object error) describeFailure,
    required String logLabel,
    BulkProgressCallback? onProgress,
  }) async {
    var success = 0;
    var failed = 0;
    final errors = <String>[];
    final successfulItems = <String>[];

    void recordFailure(String path, Object error) {
      failed++;
      errors.add(describeFailure(path, error));
      AppLogger.e('$logLabel failed for $path', error, null, _logTag);
    }

    for (var i = 0; i < orderedPaths.length; i++) {
      final path = orderedPaths[i];
      onProgress?.call(
        current: i,
        total: orderedPaths.length,
        currentItem: path,
        isComplete: false,
      );

      final item = planned[path];
      if (item == null || item.error != null) {
        recordFailure(path, item?.error ?? StateError('Unplanned $path'));
        continue;
      }

      try {
        await write(item.imageId!, item.target as T);
        success++;
        successfulItems.add(path);
        AppLogger.d(
          '$logLabel applied for $path ($success/${orderedPaths.length})',
          _logTag,
        );
      } catch (e) {
        recordFailure(path, e);
      }
    }

    onProgress?.call(
      current: orderedPaths.length,
      total: orderedPaths.length,
      currentItem: '',
      isComplete: true,
    );

    return (
      success: success,
      failed: failed,
      errors: errors,
      successfulItems: successfulItems,
    );
  }

  List<List<T>> _chunk<T>(List<T> values, int size) {
    return [
      for (var i = 0; i < values.length; i += size)
        values.sublist(i, (i + size).clamp(0, values.length)),
    ];
  }
}

String _describeTagFailure(String path, Object error) =>
    'Failed to edit metadata for $path: $error';

String _describeFavoriteFailure(String path, Object error) =>
    'Failed to toggle favorite for $path: $error';

/// 路径解析结果：已确定 imageId 的路径与解析失败的路径
class _ResolvedPaths {
  const _ResolvedPaths({required this.idsByPath, required this.failures});

  final Map<String, int> idsByPath;
  final Map<String, Object> failures;
}

/// 分批读取结果：单个批次失败只影响该批次内的图片
class _BatchRead<T> {
  const _BatchRead({required this.values, required this.failures});

  final Map<int, T> values;
  final Map<int, Object> failures;
}

/// 写入阶段的逐项计划：要么带着已确定的目标，要么带着读取阶段的失败原因
class _PlannedItem<T> {
  const _PlannedItem.target(this.imageId, this.target) : error = null;
  const _PlannedItem.failed(this.error) : imageId = null, target = null;

  final int? imageId;
  final T? target;
  final Object? error;
}
