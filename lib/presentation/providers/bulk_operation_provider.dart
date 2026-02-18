import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/repositories/local_gallery_repository.dart'
    hide BulkOperationResult;
import '../../data/services/bulk_operation_service.dart';
import '../../core/utils/undo_redo_history.dart';
import 'collection_provider.dart';

part 'bulk_operation_provider.freezed.dart';
part 'bulk_operation_provider.g.dart';

/// Bulk operation type
enum BulkOperationType {
  delete,
  export,
  metadataEdit,
  addToCollection,
  removeFromCollection,
  toggleFavorite,
}

/// Bulk operation state
@freezed
class BulkOperationState with _$BulkOperationState {
  const factory BulkOperationState({
    /// Current operation type
    BulkOperationType? currentOperation,

    /// Whether an operation is in progress
    @Default(false) bool isOperationInProgress,

    /// Current progress (0 to total)
    @Default(0) int currentProgress,

    /// Total items to process
    @Default(0) int totalItems,

    /// Current item being processed (file path)
    String? currentItem,

    /// Last operation result
    BulkOperationResult? lastResult,

    /// Whether operation completed successfully
    @Default(false) bool isCompleted,

    /// Error message if operation failed
    String? error,

    /// Whether can undo
    @Default(false) bool canUndo,

    /// Whether can redo
    @Default(false) bool canRedo,
  }) = _BulkOperationState;

  const BulkOperationState._();

  /// Progress percentage (0-100)
  double get progressPercentage {
    if (totalItems == 0) return 0;
    return (currentProgress / totalItems * 100).clamp(0, 100);
  }

  /// Whether has error
  bool get hasError => error != null;

  /// Whether can perform undo/redo
  bool get canPerformUndoRedo => canUndo || canRedo;
}

/// Bulk delete command for undo/redo
class _BulkDeleteCommand extends HistoryCommand {
  // ignore: unused_field - Reserved for future undo support
  final LocalGalleryRepository _repository;
  final List<String> _imagePaths;

  _BulkDeleteCommand(
    super.description,
    this._repository,
    this._imagePaths,
  );

  @override
  Future<void> execute() async {
    for (final path in _imagePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        AppLogger.e('Failed to delete $path', e, null, '_BulkDeleteCommand');
      }
    }
  }

  @override
  Future<void> undo() async {
    // Cannot undo file deletion - files are permanently deleted
    // This is a limitation of the current implementation
    AppLogger.w(
      'Undo not supported for bulk delete - files are permanently deleted',
      '_BulkDeleteCommand',
    );
  }
}

/// Bulk metadata edit command for undo/redo
class _BulkMetadataEditCommand extends HistoryCommand {
  final LocalGalleryRepository _repository;
  final List<String> _imagePaths;
  final List<String> _tagsToAdd;
  final List<String> _tagsToRemove;
  final Map<String, List<String>> _originalTags;

  _BulkMetadataEditCommand(
    super.description,
    this._repository,
    this._imagePaths,
    this._tagsToAdd,
    this._tagsToRemove,
    this._originalTags,
  );

  @override
  Future<void> execute() async {
    // Apply the metadata changes
    for (final imagePath in _imagePaths) {
      try {
        final currentTags = await _repository.getTags(imagePath);
        final updatedTags = List<String>.from(currentTags);

        // Add new tags
        for (final tag in _tagsToAdd) {
          if (!updatedTags.contains(tag)) {
            updatedTags.add(tag);
          }
        }

        // Remove tags
        for (final tag in _tagsToRemove) {
          updatedTags.remove(tag);
        }

        await _repository.setTags(imagePath, updatedTags);
      } catch (e) {
        AppLogger.e(
          'Failed to edit metadata for $imagePath',
          e,
          null,
          '_BulkMetadataEditCommand',
        );
      }
    }
  }

  @override
  Future<void> undo() async {
    // Restore original tags
    for (final imagePath in _imagePaths) {
      try {
        final originalTags = _originalTags[imagePath];
        if (originalTags != null) {
          await _repository.setTags(imagePath, originalTags);
        }
      } catch (e) {
        AppLogger.e(
          'Failed to undo metadata edit for $imagePath',
          e,
          null,
          '_BulkMetadataEditCommand',
        );
      }
    }
  }
}

/// Bulk toggle favorite command for undo/redo
class _BulkToggleFavoriteCommand extends HistoryCommand {
  final LocalGalleryRepository _repository;
  final Map<String, bool> _originalFavoriteStates;
  final bool _newFavoriteState;

  _BulkToggleFavoriteCommand(
    super.description,
    this._repository,
    this._originalFavoriteStates,
    this._newFavoriteState,
  );

  @override
  Future<void> execute() async {
    for (final entry in _originalFavoriteStates.entries) {
      try {
        await _repository.setFavorite(entry.key, _newFavoriteState);
      } catch (e) {
        AppLogger.e(
          'Failed to toggle favorite for ${entry.key}',
          e,
          null,
          '_BulkToggleFavoriteCommand',
        );
      }
    }
  }

  @override
  Future<void> undo() async {
    // Restore original favorite states
    for (final entry in _originalFavoriteStates.entries) {
      try {
        await _repository.setFavorite(entry.key, entry.value);
      } catch (e) {
        AppLogger.e(
          'Failed to undo favorite toggle for ${entry.key}',
          e,
          null,
          '_BulkToggleFavoriteCommand',
        );
      }
    }
  }
}

/// Provider for BulkOperationService
@riverpod
BulkOperationService bulkOperationService(Ref ref) {
  return BulkOperationService();
}

/// Bulk operation notifier with undo/redo support
@Riverpod(keepAlive: true)
class BulkOperationNotifier extends _$BulkOperationNotifier {
  late final BulkOperationService _service;
  late final LocalGalleryRepository _galleryRepository;
  late final UndoRedoHistory _history;

  @override
  BulkOperationState build() {
    _service = ref.read(bulkOperationServiceProvider);
    _galleryRepository = LocalGalleryRepository.instance;
    _history = UndoRedoHistory(maxSize: 50);

    return const BulkOperationState();
  }

  /// Bulk delete images
  ///
  /// [imagePaths] List of image file paths to delete
  /// Returns operation result with success/failed counts and errors
  ///
  /// 批量删除图片
  /// 返回操作结果（成功数、失败数、错误列表）
  Future<BulkOperationResult> bulkDelete(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return (success: 0, failed: 0, errors: <String>[]);
    }

    state = state.copyWith(
      currentOperation: BulkOperationType.delete,
      isOperationInProgress: true,
      currentProgress: 0,
      totalItems: imagePaths.length,
      error: null,
      isCompleted: false,
    );

    try {
      final result = await _service.bulkDelete(
        imagePaths,
        onProgress: ({
          required current,
          required total,
          required currentItem,
          required isComplete,
        }) {
          state = state.copyWith(
            currentProgress: current,
            totalItems: total,
            currentItem: currentItem,
            isCompleted: isComplete,
          );
        },
      );

      // Add to history
      final command = _BulkDeleteCommand(
        'Delete ${imagePaths.length} images',
        _galleryRepository,
        imagePaths,
      );
      _history.push(command);

      state = state.copyWith(
        isOperationInProgress: false,
        lastResult: result,
        isCompleted: true,
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
      );

      AppLogger.i(
        'Bulk delete completed: ${result.success} succeeded, ${result.failed} failed',
        'BulkOperationNotifier',
      );

      return result;
    } catch (e) {
      final error = 'Bulk delete failed: $e';
      state = state.copyWith(
        isOperationInProgress: false,
        error: error,
      );
      AppLogger.e('Bulk delete failed', e, null, 'BulkOperationNotifier');
      rethrow;
    }
  }

  /// Bulk export image metadata
  ///
  /// [records] List of image records to export
  /// [outputFormat] Export format ('json' or 'csv')
  /// [includeMetadata] Whether to include full NAI metadata
  /// Returns the exported file path, or null if failed
  ///
  /// 批量导出图片元数据到文件
  /// 返回导出的文件路径，失败返回 null
  Future<File?> bulkExport(
    List<LocalImageRecord> records, {
    String outputFormat = 'json',
    bool includeMetadata = true,
  }) async {
    if (records.isEmpty) {
      state = state.copyWith(
        error: 'No images to export',
      );
      return null;
    }

    state = state.copyWith(
      currentOperation: BulkOperationType.export,
      isOperationInProgress: true,
      currentProgress: 0,
      totalItems: records.length,
      error: null,
      isCompleted: false,
    );

    try {
      final file = await _service.bulkExport(
        records,
        outputFormat: outputFormat,
        includeMetadata: includeMetadata,
        onProgress: ({
          required current,
          required total,
          required currentItem,
          required isComplete,
        }) {
          state = state.copyWith(
            currentProgress: current,
            totalItems: total,
            currentItem: currentItem,
            isCompleted: isComplete,
          );
        },
      );

      if (file != null) {
        // Export is not undoable - it creates a new file
        state = state.copyWith(
          isOperationInProgress: false,
          isCompleted: true,
        );

        AppLogger.i(
          'Bulk export completed: ${records.length} images exported to ${file.path}',
          'BulkOperationNotifier',
        );
      } else {
        state = state.copyWith(
          isOperationInProgress: false,
          error: 'Export failed',
        );
      }

      return file;
    } catch (e) {
      final error = 'Bulk export failed: $e';
      state = state.copyWith(
        isOperationInProgress: false,
        error: error,
      );
      AppLogger.e('Bulk export failed', e, null, 'BulkOperationNotifier');
      return null;
    }
  }

  /// Bulk edit metadata (add/remove tags)
  ///
  /// [imagePaths] List of image file paths to edit
  /// [tagsToAdd] Tags to add to each image
  /// [tagsToRemove] Tags to remove from each image
  /// Returns operation result with success/failed counts and errors
  ///
  /// 批量编辑元数据（添加/删除标签）
  /// 返回操作结果（成功数、失败数、错误列表）
  Future<BulkOperationResult> bulkEditMetadata(
    List<String> imagePaths, {
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
  }) async {
    if (imagePaths.isEmpty) {
      return (success: 0, failed: 0, errors: <String>[]);
    }

    if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
      state = state.copyWith(
        error: 'No tags to add or remove',
      );
      return (success: 0, failed: 0, errors: <String>[]);
    }

    state = state.copyWith(
      currentOperation: BulkOperationType.metadataEdit,
      isOperationInProgress: true,
      currentProgress: 0,
      totalItems: imagePaths.length,
      error: null,
      isCompleted: false,
    );

    try {
      // Store original tags for undo
      final originalTags = <String, List<String>>{};
      for (final path in imagePaths) {
        originalTags[path] = await _galleryRepository.getTags(path);
      }

      final result = await _service.bulkEditMetadata(
        imagePaths,
        tagsToAdd: tagsToAdd,
        tagsToRemove: tagsToRemove,
        onProgress: ({
          required current,
          required total,
          required currentItem,
          required isComplete,
        }) {
          state = state.copyWith(
            currentProgress: current,
            totalItems: total,
            currentItem: currentItem,
            isCompleted: isComplete,
          );
        },
      );

      // Add to history
      final command = _BulkMetadataEditCommand(
        'Edit metadata for ${imagePaths.length} images',
        _galleryRepository,
        imagePaths,
        tagsToAdd,
        tagsToRemove,
        originalTags,
      );
      _history.push(command);

      state = state.copyWith(
        isOperationInProgress: false,
        lastResult: result,
        isCompleted: true,
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
      );

      AppLogger.i(
        'Bulk metadata edit completed: ${result.success} succeeded, ${result.failed} failed',
        'BulkOperationNotifier',
      );

      return result;
    } catch (e) {
      final error = 'Bulk metadata edit failed: $e';
      state = state.copyWith(
        isOperationInProgress: false,
        error: error,
      );
      AppLogger.e(
        'Bulk metadata edit failed',
        e,
        null,
        'BulkOperationNotifier',
      );
      rethrow;
    }
  }

  /// Bulk toggle favorite status
  ///
  /// [imagePaths] List of image file paths to toggle
  /// [isFavorite] Favorite status to set
  /// Returns operation result with success/failed counts and errors
  ///
  /// 批量切换收藏状态
  /// 返回操作结果（成功数、失败数、错误列表）
  Future<BulkOperationResult> bulkToggleFavorite(
    List<String> imagePaths, {
    required bool isFavorite,
  }) async {
    if (imagePaths.isEmpty) {
      return (success: 0, failed: 0, errors: <String>[]);
    }

    state = state.copyWith(
      currentOperation: BulkOperationType.toggleFavorite,
      isOperationInProgress: true,
      currentProgress: 0,
      totalItems: imagePaths.length,
      error: null,
      isCompleted: false,
    );

    try {
      // Store original favorite states for undo
      final originalStates = <String, bool>{};
      for (final path in imagePaths) {
        originalStates[path] = await _galleryRepository.isFavorite(path);
      }

      final result = await _service.bulkToggleFavorite(
        imagePaths,
        isFavorite: isFavorite,
        onProgress: ({
          required current,
          required total,
          required currentItem,
          required isComplete,
        }) {
          state = state.copyWith(
            currentProgress: current,
            totalItems: total,
            currentItem: currentItem,
            isCompleted: isComplete,
          );
        },
      );

      // Add to history
      final command = _BulkToggleFavoriteCommand(
        'Toggle favorite for ${imagePaths.length} images to $isFavorite',
        _galleryRepository,
        originalStates,
        isFavorite,
      );
      _history.push(command);

      state = state.copyWith(
        isOperationInProgress: false,
        lastResult: result,
        isCompleted: true,
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
      );

      AppLogger.i(
        'Bulk toggle favorite completed: ${result.success} succeeded, ${result.failed} failed',
        'BulkOperationNotifier',
      );

      return result;
    } catch (e) {
      final error = 'Bulk toggle favorite failed: $e';
      state = state.copyWith(
        isOperationInProgress: false,
        error: error,
      );
      AppLogger.e(
        'Bulk toggle favorite failed',
        e,
        null,
        'BulkOperationNotifier',
      );
      rethrow;
    }
  }

  /// Bulk add images to collection
  ///
  /// [collectionId] Collection ID to add images to
  /// [imagePaths] List of image file paths to add
  /// Returns the number of images added
  ///
  /// 批量添加图片到集合
  /// 返回添加的图片数量
  Future<int> bulkAddToCollection(
    String collectionId,
    List<String> imagePaths,
  ) async {
    if (imagePaths.isEmpty) {
      state = state.copyWith(
        error: 'No images to add to collection',
      );
      return 0;
    }

    state = state.copyWith(
      currentOperation: BulkOperationType.addToCollection,
      isOperationInProgress: true,
      currentProgress: 0,
      totalItems: imagePaths.length,
      error: null,
      isCompleted: false,
    );

    try {
      final collectionNotifier = ref.read(collectionNotifierProvider.notifier);
      final addedCount = await collectionNotifier.addImagesToCollection(
        collectionId,
        imagePaths,
      );

      state = state.copyWith(
        isOperationInProgress: false,
        currentProgress: imagePaths.length,
        isCompleted: true,
      );

      AppLogger.i(
        'Bulk add to collection completed: $addedCount images added to $collectionId',
        'BulkOperationNotifier',
      );

      return addedCount;
    } catch (e) {
      final error = 'Bulk add to collection failed: $e';
      state = state.copyWith(
        isOperationInProgress: false,
        error: error,
      );
      AppLogger.e(
        'Bulk add to collection failed',
        e,
        null,
        'BulkOperationNotifier',
      );
      return 0;
    }
  }

  /// Undo last operation
  ///
  /// 撤销上一步操作
  Future<void> undo() async {
    if (!_history.canUndo) {
      state = state.copyWith(
        error: 'Cannot undo - no operation to undo',
      );
      return;
    }

    try {
      await _history.undo();

      state = state.copyWith(
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
        error: null,
      );

      AppLogger.i('Undo completed', 'BulkOperationNotifier');
    } catch (e) {
      final error = 'Undo failed: $e';
      state = state.copyWith(error: error);
      AppLogger.e('Undo failed', e, null, 'BulkOperationNotifier');
    }
  }

  /// Redo last undone operation
  ///
  /// 重做上一步撤销的操作
  Future<void> redo() async {
    if (!_history.canRedo) {
      state = state.copyWith(
        error: 'Cannot redo - no operation to redo',
      );
      return;
    }

    try {
      await _history.redo();

      state = state.copyWith(
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
        error: null,
      );

      AppLogger.i('Redo completed', 'BulkOperationNotifier');
    } catch (e) {
      final error = 'Redo failed: $e';
      state = state.copyWith(error: error);
      AppLogger.e('Redo failed', e, null, 'BulkOperationNotifier');
    }
  }

  /// Clear operation history
  ///
  /// 清空操作历史
  void clearHistory() {
    _history.clear();
    state = state.copyWith(
      canUndo: false,
      canRedo: false,
    );
    AppLogger.d('Operation history cleared', 'BulkOperationNotifier');
  }

  /// Clear error state
  ///
  /// 清除错误状态
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset state to idle
  ///
  /// 重置状态为空闲
  void reset() {
    state = const BulkOperationState();
  }
}
