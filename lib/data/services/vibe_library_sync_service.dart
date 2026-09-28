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
    return _files.syncFolderToHive(
      existingEntries: await _repository.readAllEntries(),
      onUpsertEntry: (entry) async {
        await _repository.putEntry(entry);
        await _displayCache.entryChanged(entry);
      },
      onDeleteEntry: removeMissingEntries
          ? (entry) async {
              await _repository.deleteEntry(entry.id);
              await _displayCache.entryDeleted(entry.id);
            }
          : null,
    );
  }
}
