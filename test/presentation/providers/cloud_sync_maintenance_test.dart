import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_maintenance.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

void main() {
  test('WebDAV maintenance is awaited, warned, and throttled daily', () async {
    final local = _MemoryLocalStorage();
    var state = const CloudSyncUiState();
    final backend = _MaintenanceBackend(
      const CloudMaintenanceResult(
        scanned: 4,
        deleted: 1,
        skipped: 3,
        warnings: ['missing ETag'],
      ),
    );
    var now = DateTime.utc(2026, 3, 12, 12);
    final maintenance = CloudSyncMaintenance(
      localStorage: local,
      readState: () => state,
      writeState: (value) => state = value,
      now: () => now,
    );

    await maintenance.run(backend);
    await maintenance.run(backend);

    expect(backend.calls, 1);
    expect(state.maintenanceWarning, 'missing ETag');
    expect(state.logs.single.message, contains('deleted 1'));
    expect(
      local.values[StorageKeys.cloudSyncLastMaintenanceAt],
      now.millisecondsSinceEpoch,
    );

    now = now.add(const Duration(days: 1));
    await maintenance.run(backend);
    expect(backend.calls, 2);
  });

  test(
    'GitHub/non-maintenance backend never triggers GC or throttle',
    () async {
      final local = _MemoryLocalStorage();
      var state = const CloudSyncUiState();
      final maintenance = CloudSyncMaintenance(
        localStorage: local,
        readState: () => state,
        writeState: (value) => state = value,
      );

      await maintenance.run(Object());

      expect(local.values, isEmpty);
      expect(state.logs, isEmpty);
    },
  );

  test('maintenance storage failure is reported without escaping', () async {
    final local = _FailingLocalStorage();
    var state = const CloudSyncUiState();
    final maintenance = CloudSyncMaintenance(
      localStorage: local,
      readState: () => state,
      writeState: (value) => state = value,
    );

    await expectLater(
      maintenance.run(
        _MaintenanceBackend(
          const CloudMaintenanceResult(scanned: 0, deleted: 0, skipped: 0),
        ),
      ),
      completes,
    );

    expect(state.error, isNull);
    expect(state.maintenanceWarning, isNotNull);
  });

  test('disposed maintenance does not publish detached state', () async {
    final local = _MemoryLocalStorage();
    var state = const CloudSyncUiState();
    final backend = _MaintenanceBackend(
      const CloudMaintenanceResult(scanned: 1, deleted: 1, skipped: 0),
    );
    final maintenance = CloudSyncMaintenance(
      localStorage: local,
      readState: () => state,
      writeState: (value) => state = value,
    );
    maintenance.dispose();

    await maintenance.run(backend);

    expect(state.logs, isEmpty);
  });
}

class _MaintenanceBackend implements CloudSyncBackendMaintenance {
  _MaintenanceBackend(this.result);

  final CloudMaintenanceResult result;
  int calls = 0;

  @override
  Future<CloudMaintenanceResult> cleanUnreferencedObjects() async {
    calls++;
    return result;
  }
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

class _FailingLocalStorage extends _MemoryLocalStorage {
  @override
  Future<void> setSetting<T>(String key, T value) =>
      Future.error(StateError('local failure'));
}
