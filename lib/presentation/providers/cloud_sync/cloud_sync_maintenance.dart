import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import 'cloud_sync_ui_provider.dart';

class CloudSyncMaintenanceUpdate {
  const CloudSyncMaintenanceUpdate({required this.message, this.warning});

  final String message;
  final String? warning;
}

/// Runs optional provider maintenance after a completed user data operation.
/// It is awaited, but intentionally cannot change that operation's outcome.
class CloudSyncMaintenance {
  CloudSyncMaintenance({
    required LocalStorageService localStorage,
    required CloudSyncUiState Function() readState,
    required void Function(CloudSyncUiState state) writeState,
    DateTime Function()? now,
  }) : _localStorage = localStorage,
       _readState = readState,
       _writeState = writeState,
       _now = now ?? DateTime.now;

  static const interval = Duration(days: 1);

  final LocalStorageService _localStorage;
  final CloudSyncUiState Function() _readState;
  final void Function(CloudSyncUiState state) _writeState;
  final DateTime Function() _now;
  bool _disposed = false;

  void dispose() => _disposed = true;

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

  Future<void> run(Object? backend) async {
    if (backend is! CloudSyncBackendMaintenance) return;
    try {
      final now = _now().toUtc();
      final lastMillis = _localStorage.getSetting<int>(
        StorageKeys.cloudSyncLastMaintenanceAt,
      );
      if (lastMillis != null &&
          now.difference(
                DateTime.fromMillisecondsSinceEpoch(lastMillis, isUtc: true),
              ) <
              interval) {
        return;
      }

      // Persist the attempt before network IO so repeated failures do not make
      // every foreground sync hammer a constrained WebDAV server.
      await _localStorage.setSetting(
        StorageKeys.cloudSyncLastMaintenanceAt,
        now.millisecondsSinceEpoch,
      );
      final result = await backend.cleanUnreferencedObjects();
      if (_disposed) return;
      final warning = result.warnings.isEmpty
          ? null
          : result.warnings.join('\n');
      _update(
        CloudSyncMaintenanceUpdate(
          message:
              'WebDAV maintenance: scanned ${result.scanned}, deleted ${result.deleted}, skipped ${result.skipped}.',
          warning: warning,
        ),
      );
    } catch (_) {
      if (_disposed) return;
      try {
        _update(
          const CloudSyncMaintenanceUpdate(
            message: 'WebDAV maintenance did not complete; sync remains valid.',
            warning: '远端维护暂未完成；同步数据不受影响，将在稍后重试。',
          ),
        );
      } catch (_) {
        // Maintenance state reporting must never invalidate a completed sync.
      }
    }
  }

  void _update(CloudSyncMaintenanceUpdate update) {
    final state = _readState();
    _writeState(
      state.copyWith(
        maintenanceWarning: update.warning,
        clearMaintenanceWarning: update.warning == null,
        logs: [
          ...state.logs,
          CloudSyncLogEntry(time: _now(), message: update.message),
        ],
      ),
    );
  }
}
