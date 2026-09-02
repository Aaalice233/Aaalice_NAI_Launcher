import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import 'cloud_sync_ui_provider.dart';

class CloudSyncPendingIntentStore {
  const CloudSyncPendingIntentStore({
    required LocalStorageService localStorage,
    required CloudSyncUiState Function() readState,
    required void Function(CloudSyncUiState state) writeState,
  }) : _localStorage = localStorage,
       _readState = readState,
       _writeState = writeState;

  final LocalStorageService _localStorage;
  final CloudSyncUiState Function() _readState;
  final void Function(CloudSyncUiState state) _writeState;

  bool readPendingFfdkjIntent() =>
      _localStorage.getSetting<bool>(
        StorageKeys.cloudSyncPendingFfdkjInstall,
        defaultValue: false,
      ) ??
      false;

  Future<void> clearFfdkjIntent() async {
    await _localStorage.deleteSetting(StorageKeys.cloudSyncPendingFfdkjInstall);
    _writeState(_readState().copyWith(pendingFfdkjInstall: false));
  }
}
