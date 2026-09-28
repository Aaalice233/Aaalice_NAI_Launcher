import '../../core/cloud_sync/content_selection.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

class CloudSyncContentSelectionStore {
  const CloudSyncContentSelectionStore(this._storage);

  final LocalStorageService _storage;

  CloudSyncContentSelection load() {
    final raw = _storage.getSetting<String>(
      StorageKeys.cloudSyncContentSelection,
    );
    if (raw == null || raw.isEmpty) return const CloudSyncContentSelection();
    return CloudSyncContentSelection.decode(raw);
  }

  Future<void> save(CloudSyncContentSelection selection) => _storage.setSetting(
    StorageKeys.cloudSyncContentSelection,
    selection.encode(),
  );
}
