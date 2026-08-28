import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_application_service.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_connection_store.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

void main() {
  test(
    'service construction does not persist device id synchronously',
    () async {
      final local = _MemoryLocalStorage();
      final service = CloudSyncApplicationService(
        backendFactory: (_) => throw UnimplementedError(),
        coordinatorFactory: (_, __, ___) => throw UnimplementedError(),
        secureStorage: _MemorySecureStorage(),
        localStorage: local,
        onState: (_) {},
        deviceIdFactory: () => 'test-device',
      );

      expect(local.writes, 0);
      await service.initialize();
      expect(local.writes, 1);
      expect(local.values.values, contains('test-device'));
    },
  );

  test('persisted WebDAV policy keeps explicit insecure HTTP choice', () async {
    final local = _MemoryLocalStorage();
    final secure = _MemorySecureStorage();
    final store = CloudSyncConnectionStore(
      localStorage: local,
      secureStorage: secure,
    );
    const draft = CloudSyncConnectionDraft(
      backend: CloudSyncBackendKind.webDav,
      serverUrl: 'http://dav.test/root',
      username: 'user',
      secret: 'secret',
      path: 'namespace',
      allowInsecureHttp: true,
    );

    await store.save(draft, {CloudSyncDataKind.settings});
    final syncedAt = DateTime.utc(2026, 3, 14, 9, 30);
    await store.saveSyncState(remoteRevision: 'revision-7', lastSync: syncedAt);
    final restored = await store.load();

    expect(restored!.draft.allowInsecureHttp, isTrue);
    expect(restored.draft.serverUrl, draft.serverUrl);
    expect(restored.dataKinds, {CloudSyncDataKind.settings});
    expect(restored.remoteRevision, 'revision-7');
    expect(restored.lastSync, syncedAt);
    expect(secure.credentialWrites, 1);
    final public =
        jsonDecode(local.values[StorageKeys.cloudSyncConfiguration] as String)
            as Map<String, dynamic>;
    expect(public['version'], 2);
    await store.clear();
    expect(await store.load(), isNull);
    expect(secure.cleared, isTrue);
  });

  test(
    'legacy connection configuration migrates without rewriting secrets',
    () async {
      final local = _MemoryLocalStorage();
      final secure = _MemorySecureStorage()
        ..credentials = jsonEncode({'username': 'legacy', 'secret': 'private'});
      local.values[StorageKeys.cloudSyncConfiguration] = jsonEncode({
        'backend': 'webDav',
        'serverUrl': 'https://dav.test',
        'path': 'legacy-space',
        'dataKinds': ['settings'],
      });
      final store = CloudSyncConnectionStore(
        localStorage: local,
        secureStorage: secure,
      );

      final restored = await store.load();

      expect(restored!.draft.username, 'legacy');
      expect(restored.draft.secret, 'private');
      expect(secure.credentialWrites, 0);
      final migrated =
          jsonDecode(local.values[StorageKeys.cloudSyncConfiguration] as String)
              as Map<String, dynamic>;
      expect(migrated['version'], 2);
    },
  );
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> values = {};
  int writes = 0;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async => values.remove(key);
}

class _MemorySecureStorage extends SecureStorageService {
  String? credentials;
  bool cleared = false;
  int credentialWrites = 0;

  @override
  Future<void> saveCloudSyncCredentials(String encodedCredentials) async {
    credentialWrites++;
    credentials = encodedCredentials;
  }

  @override
  Future<String?> getCloudSyncCredentials() async => credentials;

  @override
  Future<void> clearCloudSyncSecrets() async {
    credentials = null;
    cleared = true;
  }
}
