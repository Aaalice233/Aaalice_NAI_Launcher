import 'dart:io';

import '../models/vibe/vibe_library_entry.dart';
import 'vibe_bulk_operation_types.dart';
import 'vibe_library_storage_service.dart';

/// Executes multi-entry library commands outside Riverpod state reduction.
class VibeLibraryCommandService {
  VibeLibraryCommandService(this._storage);

  final VibeLibraryStorageService _storage;

  Future<int> toggleFavorites(Iterable<String> ids) async {
    var count = 0;
    for (final id in ids) {
      if (await _storage.toggleFavorite(id) != null) count++;
    }
    return count;
  }

  Future<VibeBulkOperationResult> updateEncodingModel(
    Iterable<String> ids,
    String model,
  ) async {
    var successCount = 0;
    final errors = <VibeBulkOperationError>[];
    for (final id in ids) {
      try {
        if (await _storage.updateEntryEncodingModel(id, model) != null) {
          successCount++;
        } else {
          errors.add(
            VibeBulkOperationError(
              VibeBulkOperationErrorCode.processFileFailed,
              itemName: id,
            ),
          );
        }
      } catch (error) {
        errors.add(
          VibeBulkOperationError(
            VibeBulkOperationErrorCode.processFileFailed,
            itemName: id,
            details: error.toString(),
          ),
        );
      }
    }
    return VibeBulkOperationResult.fromResult(
      success: successCount,
      failed: errors.length,
      errors: errors,
    );
  }

  Future<int> deleteEntries(
    Iterable<String> ids, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final entryIds = ids.toList(growable: false);
    var count = 0;
    for (var index = 0; index < entryIds.length; index++) {
      if (await _storage.deleteEntry(entryIds[index])) count++;
      onProgress?.call(index + 1, entryIds.length);
      if ((index + 1) % 10 == 0) await Future<void>.delayed(Duration.zero);
    }
    return count;
  }

  Future<int> moveToCategory(
    Iterable<String> ids,
    String? categoryId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final entryIds = ids.toList(growable: false);
    var count = 0;
    for (var index = 0; index < entryIds.length; index++) {
      if (await _storage.updateEntryCategory(entryIds[index], categoryId) !=
          null) {
        count++;
      }
      onProgress?.call(index + 1, entryIds.length);
      if ((index + 1) % 10 == 0) await Future<void>.delayed(Duration.zero);
    }
    return count;
  }

  Future<List<String>> exportEntries(
    Iterable<VibeLibraryEntry> entries, {
    String? exportDirectory,
    void Function(int completed, int total)? onProgress,
  }) async {
    final sourceEntries = entries.toList(growable: false);
    final paths = <String>[];
    for (var index = 0; index < sourceEntries.length; index++) {
      final path = sourceEntries[index].filePath;
      if (path != null && path.isNotEmpty) {
        if (exportDirectory == null || exportDirectory.isEmpty) {
          paths.add(path);
        } else {
          final source = File(path);
          if (await source.exists()) {
            final target =
                '$exportDirectory${Platform.pathSeparator}'
                '${path.split(RegExp(r'[/\\]')).last}';
            await source.copy(target);
            paths.add(target);
          }
        }
      }
      onProgress?.call(index + 1, sourceEntries.length);
      if ((index + 1) % 5 == 0) await Future<void>.delayed(Duration.zero);
    }
    return paths;
  }

  Future<int> editTags(
    Iterable<VibeLibraryEntry> entries, {
    List<String> tagsToAdd = const [],
    List<String> tagsToRemove = const [],
    bool replaceAll = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    final sourceEntries = entries.toList(growable: false);
    var count = 0;
    for (var index = 0; index < sourceEntries.length; index++) {
      final entry = sourceEntries[index];
      final tags = replaceAll
          ? List<String>.of(tagsToAdd)
          : (Set<String>.of(entry.tags)
                  ..addAll(tagsToAdd)
                  ..removeAll(tagsToRemove))
                .toList();
      if (await _storage.updateEntryTags(entry.id, tags) != null) count++;
      onProgress?.call(index + 1, sourceEntries.length);
      if ((index + 1) % 10 == 0) await Future<void>.delayed(Duration.zero);
    }
    return count;
  }
}
