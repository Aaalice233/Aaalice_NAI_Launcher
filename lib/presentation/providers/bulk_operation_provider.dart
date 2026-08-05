import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/database/datasources/gallery_data_source.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/services/bulk_operation_service.dart';
import '../../core/utils/undo_redo_history.dart';
import '../../l10n/app_localizations.dart';
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

enum BulkOperationErrorCode {
  deleteFailed,
  noImagesToExport,
  exportFailed,
  noMetadataChanges,
  metadataEditFailed,
  favoriteFailed,
  noImagesForCollection,
  addToCollectionFailed,
  nothingToUndo,
  undoFailed,
  nothingToRedo,
  redoFailed,
}

class BulkOperationError {
  const BulkOperationError(this.code, {this.details});

  final BulkOperationErrorCode code;
  final String? details;

  String localized(AppLocalizations l10n) {
    final errorDetails = details ?? '';
    return switch (code) {
      BulkOperationErrorCode.deleteFailed =>
        l10n.bulkProgress_errorDeleteFailed(errorDetails),
      BulkOperationErrorCode.noImagesToExport =>
        l10n.bulkProgress_errorNoImagesToExport,
      BulkOperationErrorCode.exportFailed =>
        details == null
            ? l10n.bulkProgress_errorExportFailed
            : l10n.bulkProgress_errorExportFailedWithDetails(errorDetails),
      BulkOperationErrorCode.noMetadataChanges =>
        l10n.bulkProgress_errorNoMetadataChanges,
      BulkOperationErrorCode.metadataEditFailed =>
        l10n.bulkProgress_errorMetadataEditFailed(errorDetails),
      BulkOperationErrorCode.favoriteFailed =>
        l10n.bulkProgress_errorFavoriteFailed(errorDetails),
      BulkOperationErrorCode.noImagesForCollection =>
        l10n.bulkProgress_errorNoImagesForCollection,
      BulkOperationErrorCode.addToCollectionFailed =>
        l10n.bulkProgress_errorAddToCollectionFailed(errorDetails),
      BulkOperationErrorCode.nothingToUndo =>
        l10n.bulkProgress_errorNothingToUndo,
      BulkOperationErrorCode.undoFailed => l10n.bulkProgress_errorUndoFailed(
        errorDetails,
      ),
      BulkOperationErrorCode.nothingToRedo =>
        l10n.bulkProgress_errorNothingToRedo,
      BulkOperationErrorCode.redoFailed => l10n.bulkProgress_errorRedoFailed(
        errorDetails,
      ),
    };
  }
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
    BulkOperationError? error,

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
  final List<String> _imagePaths;

  _BulkDeleteCommand(super.description, this._imagePaths);

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
  final Ref _ref;
  final List<String> _imagePaths;
  final List<String> _tagsToAdd;
  final List<String> _tagsToRemove;
  final Map<String, List<String>> _originalTags;

  _BulkMetadataEditCommand(
    super.description,
    this._ref,
    this._imagePaths,
    this._tagsToAdd,
    this._tagsToRemove,
    this._originalTags,
  );

  Future<GalleryDataSource> _getDataSource() async {
    final dbManager = await _ref.read(databaseManagerProvider.future);
    final dataSource = dbManager.getDataSource<GalleryDataSource>('gallery');
    if (dataSource == null) {
      throw StateError('GalleryDataSource not found');
    }
    return dataSource;
  }

  @override
  Future<void> execute() async {
    final dataSource = await _getDataSource();

    // Apply the metadata changes
    for (final imagePath in _imagePaths) {
      try {
        var imageId = await dataSource.getImageIdByPath(imagePath);

        // If image not in database, index it first
        if (imageId == null) {
          final file = File(imagePath);
          if (await file.exists()) {
            final stat = await file.stat();
            final fileName = imagePath.split(Platform.pathSeparator).last;
            imageId = await dataSource.upsertImage(
              filePath: imagePath,
              fileName: fileName,
              fileSize: stat.size,
              createdAt: stat.changed,
              modifiedAt: stat.modified,
            );
          } else {
            continue;
          }
        }

        final currentTags = await dataSource.getImageTags(imageId);
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

        await dataSource.setImageTags(imageId, updatedTags);
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
    final dataSource = await _getDataSource();

    // Restore original tags
    for (final imagePath in _imagePaths) {
      try {
        final originalTags = _originalTags[imagePath];
        if (originalTags != null) {
          var imageId = await dataSource.getImageIdByPath(imagePath);

          if (imageId == null) {
            final file = File(imagePath);
            if (await file.exists()) {
              final stat = await file.stat();
              final fileName = imagePath.split(Platform.pathSeparator).last;
              imageId = await dataSource.upsertImage(
                filePath: imagePath,
                fileName: fileName,
                fileSize: stat.size,
                createdAt: stat.changed,
                modifiedAt: stat.modified,
              );
            } else {
              continue;
            }
          }

          await dataSource.setImageTags(imageId, originalTags);
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
  final Ref _ref;
  final Map<String, bool> _originalFavoriteStates;
  final bool _newFavoriteState;

  _BulkToggleFavoriteCommand(
    super.description,
    this._ref,
    this._originalFavoriteStates,
    this._newFavoriteState,
  );

  Future<GalleryDataSource> _getDataSource() async {
    final dbManager = await _ref.read(databaseManagerProvider.future);
    final dataSource = dbManager.getDataSource<GalleryDataSource>('gallery');
    if (dataSource == null) {
      throw StateError('GalleryDataSource not found');
    }
    return dataSource;
  }

  @override
  Future<void> execute() async {
    final dataSource = await _getDataSource();

    for (final entry in _originalFavoriteStates.entries) {
      try {
        var imageId = await dataSource.getImageIdByPath(entry.key);

        // If image not in database, index it first
        if (imageId == null) {
          final file = File(entry.key);
          if (await file.exists()) {
            final stat = await file.stat();
            final fileName = entry.key.split(Platform.pathSeparator).last;
            imageId = await dataSource.upsertImage(
              filePath: entry.key,
              fileName: fileName,
              fileSize: stat.size,
              createdAt: stat.changed,
              modifiedAt: stat.modified,
            );
          } else {
            continue;
          }
        }

        final currentlyFavorite = await dataSource.isFavorite(imageId);
        if (currentlyFavorite != _newFavoriteState) {
          await dataSource.toggleFavorite(imageId);
        }
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
    final dataSource = await _getDataSource();

    // Restore original favorite states
    for (final entry in _originalFavoriteStates.entries) {
      try {
        var imageId = await dataSource.getImageIdByPath(entry.key);

        if (imageId == null) {
          final file = File(entry.key);
          if (await file.exists()) {
            final stat = await file.stat();
            final fileName = entry.key.split(Platform.pathSeparator).last;
            imageId = await dataSource.upsertImage(
              filePath: entry.key,
              fileName: fileName,
              fileSize: stat.size,
              createdAt: stat.changed,
              modifiedAt: stat.modified,
            );
          } else {
            continue;
          }
        }

        final currentlyFavorite = await dataSource.isFavorite(imageId);
        if (currentlyFavorite != entry.value) {
          await dataSource.toggleFavorite(imageId);
        }
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
  return BulkOperationService(ref: ref);
}

/// Bulk operation notifier with undo/redo support
@Riverpod(keepAlive: true)
class BulkOperationNotifier extends _$BulkOperationNotifier {
  late final BulkOperationService _service;
  late final UndoRedoHistory _history;

  @override
  BulkOperationState build() {
    _service = ref.read(bulkOperationServiceProvider);
    _history = UndoRedoHistory(maxSize: 50);

    return const BulkOperationState();
  }

  /// 获取 GalleryDataSource
  Future<GalleryDataSource> _getDataSource() async {
    final dbManager = await ref.read(databaseManagerProvider.future);
    final dataSource = dbManager.getDataSource<GalleryDataSource>('gallery');
    if (dataSource == null) {
      throw StateError('GalleryDataSource not found');
    }
    return dataSource;
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
        onProgress:
            ({
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
      state = state.copyWith(
        isOperationInProgress: false,
        error: BulkOperationError(
          BulkOperationErrorCode.deleteFailed,
          details: '$e',
        ),
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
        error: const BulkOperationError(
          BulkOperationErrorCode.noImagesToExport,
        ),
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
        onProgress:
            ({
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
        state = state.copyWith(isOperationInProgress: false, isCompleted: true);

        AppLogger.i(
          'Bulk export completed: ${records.length} images exported to ${file.path}',
          'BulkOperationNotifier',
        );
      } else {
        state = state.copyWith(
          isOperationInProgress: false,
          error: const BulkOperationError(BulkOperationErrorCode.exportFailed),
        );
      }

      return file;
    } catch (e) {
      state = state.copyWith(
        isOperationInProgress: false,
        error: BulkOperationError(
          BulkOperationErrorCode.exportFailed,
          details: '$e',
        ),
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
        error: const BulkOperationError(
          BulkOperationErrorCode.noMetadataChanges,
        ),
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
      final dataSource = await _getDataSource();
      final originalTags = <String, List<String>>{};
      for (final path in imagePaths) {
        final imageId = await dataSource.getImageIdByPath(path);
        if (imageId != null) {
          originalTags[path] = await dataSource.getImageTags(imageId);
        } else {
          originalTags[path] = [];
        }
      }

      final result = await _service.bulkEditMetadata(
        imagePaths,
        tagsToAdd: tagsToAdd,
        tagsToRemove: tagsToRemove,
        onProgress:
            ({
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
        ref,
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
      state = state.copyWith(
        isOperationInProgress: false,
        error: BulkOperationError(
          BulkOperationErrorCode.metadataEditFailed,
          details: '$e',
        ),
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
      final dataSource = await _getDataSource();
      final originalStates = <String, bool>{};
      for (final path in imagePaths) {
        final imageId = await dataSource.getImageIdByPath(path);
        if (imageId != null) {
          originalStates[path] = await dataSource.isFavorite(imageId);
        } else {
          originalStates[path] = false;
        }
      }

      final result = await _service.bulkToggleFavorite(
        imagePaths,
        isFavorite: isFavorite,
        onProgress:
            ({
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
        ref,
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
      state = state.copyWith(
        isOperationInProgress: false,
        error: BulkOperationError(
          BulkOperationErrorCode.favoriteFailed,
          details: '$e',
        ),
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
        error: const BulkOperationError(
          BulkOperationErrorCode.noImagesForCollection,
        ),
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
      state = state.copyWith(
        isOperationInProgress: false,
        error: BulkOperationError(
          BulkOperationErrorCode.addToCollectionFailed,
          details: '$e',
        ),
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
        error: const BulkOperationError(BulkOperationErrorCode.nothingToUndo),
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
      state = state.copyWith(
        error: BulkOperationError(
          BulkOperationErrorCode.undoFailed,
          details: '$e',
        ),
      );
      AppLogger.e('Undo failed', e, null, 'BulkOperationNotifier');
    }
  }

  /// Redo last undone operation
  ///
  /// 重做上一步撤销的操作
  Future<void> redo() async {
    if (!_history.canRedo) {
      state = state.copyWith(
        error: const BulkOperationError(BulkOperationErrorCode.nothingToRedo),
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
      state = state.copyWith(
        error: BulkOperationError(
          BulkOperationErrorCode.redoFailed,
          details: '$e',
        ),
      );
      AppLogger.e('Redo failed', e, null, 'BulkOperationNotifier');
    }
  }

  /// Clear operation history
  ///
  /// 清空操作历史
  void clearHistory() {
    _history.clear();
    state = state.copyWith(canUndo: false, canRedo: false);
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
