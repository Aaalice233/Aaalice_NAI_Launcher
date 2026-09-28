import '../models/vibe/vibe_library_entry.dart';
import 'vibe_bulk_operation_types.dart';
import 'vibe_library_storage_service.dart';

/// Executes batch mutations for existing library entries.
class VibeBulkEntryService {
  VibeBulkEntryService(this._storage);

  final VibeLibraryStorageService _storage;

  Future<VibeBulkOperationResult> delete(
    List<String> ids, {
    VibeBulkProgressCallback? onProgress,
  }) => _run(
    ids,
    VibeBulkOperationType.delete,
    VibeBulkOperationErrorCode.deleteFailed,
    (id, _) => _storage.deleteEntry(id),
    onProgress,
  );

  Future<VibeBulkOperationResult> move(
    List<String> ids,
    String? categoryId, {
    VibeBulkProgressCallback? onProgress,
  }) => _run(
    ids,
    VibeBulkOperationType.move,
    VibeBulkOperationErrorCode.moveFailed,
    (id, _) async => await _storage.updateEntryCategory(id, categoryId) != null,
    onProgress,
  );

  Future<VibeBulkOperationResult> setFavorite(
    List<String> ids,
    bool favorite, {
    VibeBulkProgressCallback? onProgress,
  }) => _run(
    ids,
    VibeBulkOperationType.toggleFavorite,
    VibeBulkOperationErrorCode.favoriteFailed,
    (id, entry) async {
      if (entry == null) return false;
      if (entry.isFavorite == favorite) return true;
      return await _storage.toggleFavorite(id) != null;
    },
    onProgress,
  );

  Future<VibeBulkOperationResult> addTags(
    List<String> ids,
    List<String> tags, {
    VibeBulkProgressCallback? onProgress,
  }) => _editTags(
    ids,
    VibeBulkOperationType.addTags,
    VibeBulkOperationErrorCode.addTagsFailed,
    (current) => (Set<String>.of(current)..addAll(tags)).toList(),
    onProgress,
  );

  Future<VibeBulkOperationResult> removeTags(
    List<String> ids,
    List<String> tags, {
    VibeBulkProgressCallback? onProgress,
  }) => _editTags(
    ids,
    VibeBulkOperationType.removeTags,
    VibeBulkOperationErrorCode.removeTagsFailed,
    (current) => (Set<String>.of(current)..removeAll(tags)).toList(),
    onProgress,
  );

  Future<VibeBulkOperationResult> _editTags(
    List<String> ids,
    VibeBulkOperationType type,
    VibeBulkOperationErrorCode errorCode,
    List<String> Function(List<String>) transform,
    VibeBulkProgressCallback? progress,
  ) => _run(
    ids,
    type,
    errorCode,
    (id, entry) async =>
        entry != null &&
        await _storage.updateEntryTags(id, transform(entry.tags)) != null,
    progress,
  );

  Future<VibeBulkOperationResult> _run(
    List<String> ids,
    VibeBulkOperationType type,
    VibeBulkOperationErrorCode errorCode,
    Future<bool> Function(String id, VibeLibraryEntry? entry) operation,
    VibeBulkProgressCallback? progress,
  ) async {
    var success = 0;
    final errors = <VibeBulkOperationError>[];
    try {
      for (var index = 0; index < ids.length; index++) {
        final id = ids[index];
        var name = id;
        try {
          final entry = await _storage.getEntry(id);
          name = entry?.displayName ?? id;
          if (await operation(id, entry)) {
            success++;
          } else {
            errors.add(VibeBulkOperationError(errorCode, itemName: name));
          }
        } catch (error) {
          errors.add(
            VibeBulkOperationError(
              errorCode,
              itemName: name,
              details: error.toString(),
            ),
          );
        }
        progress?.call(
          current: index + 1,
          total: ids.length,
          currentItem: name,
          operationType: type,
          isComplete: false,
        );
      }
    } finally {
      progress?.call(
        current: ids.length,
        total: ids.length,
        currentItem: '',
        operationType: type,
        isComplete: true,
      );
    }
    return VibeBulkOperationResult.fromResult(
      success: success,
      failed: errors.length,
      errors: errors,
    );
  }
}
