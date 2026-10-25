import 'vibe_display_cache_repository.dart';
import 'vibe_file_storage_service.dart';
import 'vibe_library_storage_protocol.dart';

/// Reconciles file documents and Hive source entries as one application command.
class VibeLibrarySyncService {
  VibeLibrarySyncService(this._repository, this._files, this._displayCache);

  final VibeLibraryRepositoryProtocol _repository;
  final VibeFileStorageService _files;
  final VibeDisplayCacheRepository _displayCache;

  Future<VibeFolderSyncResult> synchronize({
    bool removeMissingEntries = true,
  }) async {
    final existingFilePathsById = <String, String>{};
    await _repository.forEachEntry((entry) async {
      final path = entry.filePath;
      if (path != null && path.isNotEmpty) {
        existingFilePathsById[entry.id] = path;
      }
    });
    final result = await _files.syncFolderToHive(
      existingFilePathsById: existingFilePathsById,
      loadExistingEntry: _repository.readEntry,
      onUpsertEntry: (entry) async {
        await _repository.putEntry(entry);
        await _displayCache.entryChanged(entry);
      },
      onUnchangedEntry: _displayCache.mirrorEntry,
      onDeleteEntry: removeMissingEntries
          ? (id) async {
              await _repository.deleteEntry(id);
              await _displayCache.entryDeleted(id);
            }
          : null,
    );
    final sourceIds = await _repository.readEntryIds();
    final displayIds = await _repository.readDisplayEntryIds();
    if (sourceIds.length != displayIds.length ||
        !sourceIds.containsAll(displayIds)) {
      await _displayCache.rebuild();
    }
    return result;
  }
}
