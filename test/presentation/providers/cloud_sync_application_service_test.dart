import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/coordinator.dart';
import 'package:nai_launcher/core/cloud_sync/content_selection.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_application_service.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_connection_store.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

import '../../core/cloud_sync/coordinator_test_backend.dart';

void main() {
  test('new connection only saves configuration and does not upload', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    await fixture.service.connect(
      const CloudSyncConnectRequest(
        connection: _draft,
        dataKinds: {CloudSyncDataKind.settings},
      ),
    );

    expect(
      fixture.states.last.connectionStatus,
      CloudSyncConnectionStatus.connected,
    );
    expect(fixture.backend.head, isNull);
    expect(fixture.backend.readOnlyValidationChecks, 1);
    expect(fixture.backend.capabilityChecks, 0);
    expect(
      fixture.states.last.capabilityMode,
      CloudSyncCapabilityMode.manualBackupOnly,
    );
    expect(fixture.secure.credentials, contains('provider-secret'));
    expect(fixture.local.values[StorageKeys.cloudSyncConfiguration], isNotNull);
  });

  test(
    'explicit WebDAV probe is retained by the backend saved read-only',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      final tested = await fixture.service.testConnection(_draft);
      await fixture.service.connect(
        const CloudSyncConnectRequest(
          connection: _draft,
          dataKinds: {CloudSyncDataKind.settings},
        ),
      );

      expect(tested.mode, CloudSyncCapabilityMode.bidirectional);
      expect(fixture.backend.capabilityChecks, 1);
      expect(fixture.backend.readOnlyValidationChecks, 0);
      expect(
        fixture.states.last.capabilityMode,
        CloudSyncCapabilityMode.bidirectional,
      );
      expect(fixture.backend.head, isNull);
    },
  );

  test('probe is not reused after WebDAV draft changes', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    const changed = CloudSyncConnectionDraft(
      backend: CloudSyncBackendKind.webDav,
      serverUrl: 'https://other-dav.test',
      username: 'user',
      secret: 'provider-secret',
      path: 'backup',
    );

    await fixture.service.testConnection(_draft);
    await fixture.service.connect(
      const CloudSyncConnectRequest(
        connection: changed,
        dataKinds: {CloudSyncDataKind.settings},
      ),
    );

    expect(fixture.backend.capabilityChecks, 1);
    expect(fixture.backend.readOnlyValidationChecks, 1);
    expect(
      fixture.states.last.capabilityMode,
      CloudSyncCapabilityMode.manualBackupOnly,
    );
  });

  test(
    'saving connection preserves pending work without touching local or remote data',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      const operationId = 'pending-initial-upload';
      const snapshotId = 'pending-initial-snapshot';
      await fixture.source.stage(operationId, fixture.source.snapshot);
      await fixture.journal.write(
        SyncJournal(
          operationId: operationId,
          operation: JournalOperation.uploadLocal,
          phase: JournalPhase.prepared,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: snapshotId,
          targetFingerprint: await fixture.source.stagedFingerprint(
            operationId,
          ),
          expectedRevision: null,
          uploadRequired: true,
        ),
      );

      await fixture.service.connect(
        const CloudSyncConnectRequest(
          connection: _draft,
          dataKinds: {CloudSyncDataKind.settings},
        ),
      );

      expect(fixture.backend.head, isNull);
      expect(fixture.backend.events.where((event) => event == 'head'), isEmpty);
      expect((await fixture.journal.read())?.operationId, operationId);
      expect(fixture.source.stages, contains(operationId));
    },
  );

  test(
    'restoring saved settings preserves pending work without syncing',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final store = CloudSyncConnectionStore(
        localStorage: fixture.local,
        secureStorage: fixture.secure,
      );
      await store.save(_draft, {CloudSyncDataKind.settings});
      const operationId = 'pending-restored-upload';
      await fixture.source.stage(operationId, fixture.source.snapshot);
      await fixture.journal.write(
        SyncJournal(
          operationId: operationId,
          operation: JournalOperation.uploadLocal,
          phase: JournalPhase.prepared,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: 'pending-restored-snapshot',
          targetFingerprint: await fixture.source.stagedFingerprint(
            operationId,
          ),
          expectedRevision: null,
          uploadRequired: true,
        ),
      );

      final restored = await fixture.service.restorePersisted();

      expect(restored, isTrue);
      expect(fixture.backend.head, isNull);
      expect((await fixture.journal.read())?.operationId, operationId);
      expect(fixture.source.stages, contains(operationId));
      expect(
        fixture.states.last.connectionStatus,
        CloudSyncConnectionStatus.connected,
      );
    },
  );

  test(
    'push does not block on history and explicit refresh loads it',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      await fixture.service.connect(
        const CloudSyncConnectRequest(
          connection: CloudSyncConnectionDraft(
            backend: CloudSyncBackendKind.oneDrive,
            accountId: 'history-test-account',
            path: 'aaalice-sync',
          ),
          dataKinds: {CloudSyncDataKind.settings},
        ),
      );

      await fixture.service.pushNow();

      expect(fixture.backend.historyListCalls, 0);
      expect(fixture.states.last.snapshots, hasLength(1));
      final pushedRevision = fixture.states.last.remoteRevision;
      final pushedAt = fixture.states.last.lastSync;

      await fixture.service.refreshHistory();

      expect(fixture.backend.historyListCalls, 1);
      expect(fixture.states.last.snapshots, hasLength(1));
      expect(fixture.states.last.remoteRevision, pushedRevision);
      expect(fixture.states.last.lastSync, pushedAt);
    },
  );

  test('cloud drives use plain snapshots without a key workflow', () async {
    const driveDraft = CloudSyncConnectionDraft(
      backend: CloudSyncBackendKind.oneDrive,
      accountId: 'tenant:account-a',
      accountLabel: 'user@example.test',
      path: 'aaalice-sync',
    );
    final first = await _Fixture.create();
    addTearDown(first.dispose);

    await first.service.connect(
      const CloudSyncConnectRequest(
        connection: driveDraft,
        dataKinds: {CloudSyncDataKind.settings},
      ),
    );

    expect(first.backend.head, isNull);
    expect(first.local.values[StorageKeys.cloudDriveConfiguration], isNotNull);
    expect(first.local.values[StorageKeys.cloudSyncConfiguration], isNull);

    await first.service.pushNow();
    expect(
      SnapshotHead.decode(first.backend.head!.bytes).version,
      cloudSyncSchemaVersion,
    );

    final second = await _Fixture.create(
      backend: first.backend,
      theme: 'light',
    );
    addTearDown(second.dispose);
    await second.service.connect(
      const CloudSyncConnectRequest(
        connection: driveDraft,
        dataKinds: {CloudSyncDataKind.settings},
      ),
    );
    await second.service.pullNow();
    expect(second.states.last.lastSync, isNotNull);
  });

  test(
    'second device connection detects backup without changing remote data',
    () async {
      final first = await _Fixture.create();
      addTearDown(first.dispose);
      await first.service.connect(
        const CloudSyncConnectRequest(
          connection: _draft,
          dataKinds: {CloudSyncDataKind.settings},
        ),
      );
      await first.service.pushNow();
      final remoteBefore = Uint8List.fromList(first.backend.head!.bytes);
      final revisionBefore = first.backend.head!.revision;
      final second = await _Fixture.create(
        backend: first.backend,
        theme: 'light',
      );
      addTearDown(second.dispose);

      await second.service.connect(
        const CloudSyncConnectRequest(
          connection: _draft,
          dataKinds: {CloudSyncDataKind.settings},
        ),
      );

      expect(first.backend.readOnlyValidationChecks, 2);
      expect(first.backend.capabilityChecks, 0);
      expect(second.backend.head!.bytes, remoteBefore);
      expect(second.backend.head!.revision, revisionBefore);
      expect(second.states.last.remoteExists, isTrue);
      expect(second.states.last.conflicts, isEmpty);
      expect(second.states.last.pendingPreview, isNull);
      expect(second.states.last.lastSync, isNull);
    },
  );

  test('updating backup contents only persists configuration', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    await fixture.service.connect(
      const CloudSyncConnectRequest(
        connection: _draft,
        dataKinds: cloudSyncSelectableDataKinds,
      ),
    );
    const selection = CloudSyncContentSelection(
      includeGalleryAlbums: false,
      includeVibes: true,
    );

    await fixture.service.updateContentSelection(selection);

    expect(fixture.backend.head, isNull);
    expect(fixture.backend.events, isEmpty);
    expect(fixture.states.last.contentSelection.includeGalleryAlbums, isFalse);
    expect(fixture.states.last.contentSelection.includeVibes, isTrue);
    final stored = await CloudSyncConnectionStore(
      localStorage: fixture.local,
      secureStorage: fixture.secure,
    ).load();
    expect(stored?.contentSelection.includeGalleryAlbums, isFalse);
    expect(stored?.contentSelection.includeVibes, isTrue);
  });

  test('explicit compact rebuild clears the namespace then uploads', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    await fixture.service.testConnection(_draft);
    await fixture.service.connect(
      const CloudSyncConnectRequest(
        connection: _draft,
        dataKinds: cloudSyncSelectableDataKinds,
      ),
    );
    await fixture.service.pushNow();
    final previousHead = fixture.backend.head;

    await fixture.service.rebuildCompactBackup();

    expect(fixture.backend.deleteCalls, 1);
    expect(fixture.backend.head, isNotNull);
    expect(fixture.backend.head!.revision, isNot(previousHead!.revision));
    expect(fixture.states.last.remoteExists, isTrue);
  });
}

const _draft = CloudSyncConnectionDraft(
  backend: CloudSyncBackendKind.webDav,
  serverUrl: 'https://dav.test',
  username: 'user',
  secret: 'provider-secret',
  path: 'backup',
);

class _Fixture {
  _Fixture({
    required this.directory,
    required this.backend,
    required this.local,
    required this.secure,
    required this.states,
    required this.source,
    required this.journal,
    required this.service,
  });

  final Directory directory;
  final _ApplicationBackend backend;
  final _MemoryLocalStorage local;
  final _MemorySecureStorage secure;
  final List<CloudSyncUiState> states;
  final _MemorySource source;
  final JournalStore journal;
  final CloudSyncApplicationService service;

  static Future<_Fixture> create({
    _ApplicationBackend? backend,
    String theme = 'dark',
  }) async {
    final directory = await Directory.systemTemp.createTemp('cloud-sync-app-');
    final effectiveBackend = backend ?? _ApplicationBackend();
    final local = _MemoryLocalStorage();
    final secure = _MemorySecureStorage();
    final states = <CloudSyncUiState>[];
    final source = _MemorySource(theme);
    final journal = JournalStore(File('${directory.path}/journal.json'));
    final service = CloudSyncApplicationService(
      backendFactory: (_) => effectiveBackend,
      coordinatorFactory: (_, __, ___, ____) async {
        return SyncCoordinator(
          backend: effectiveBackend,
          dataSource: source,
          journalStore: journal,
        );
      },
      secureStorage: secure,
      localStorage: local,
      onState: states.add,
      deviceIdFactory: () => 'test-device',
    );
    return _Fixture(
      directory: directory,
      backend: effectiveBackend,
      local: local,
      secure: secure,
      states: states,
      source: source,
      journal: journal,
      service: service,
    );
  }

  Future<void> dispose() async {
    service.dispose();
    await directory.delete(recursive: true);
  }
}

class _ApplicationBackend extends CoordinatorTestBackend
    implements ReadOnlyCloudSyncBackendValidation {
  int capabilityChecks = 0;
  int readOnlyValidationChecks = 0;
  int historyListCalls = 0;
  int deleteCalls = 0;

  @override
  Future<CloudBackendCapability> testCapability() async {
    capabilityChecks++;
    return super.testCapability();
  }

  @override
  Future<void> validateConnectionReadOnly() async {
    readOnlyValidationChecks++;
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) {
    historyListCalls++;
    return super.listSnapshotIds(limit: limit);
  }

  @override
  Future<void> deleteNamespace() async {
    deleteCalls++;
    await super.deleteNamespace();
  }
}

class _MemorySource implements CloudSyncDataSource {
  _MemorySource(String theme)
    : snapshot = CloudSyncSnapshotData([
        CloudSyncRecord(
          id: 'settings',
          kind: 'settings',
          binary: false,
          deleted: false,
          bytes: Uint8List.fromList(utf8.encode('{"theme":"$theme"}')),
        ),
      ]);

  final CloudSyncSnapshotData snapshot;
  final Map<String, CloudSyncSnapshotData> stages = {};
  final Map<String, Uint8List> artifacts = {};
  final Map<String, CloudSyncSnapshotData?> baseRecoveryPoints = {};
  CloudSyncSnapshotData? base;

  @override
  Future<CloudSyncSnapshotData> captureLocal() async => snapshot;
  @override
  Future<CloudSyncSnapshotData?> readBase() async => base;
  @override
  Future<void> stage(
    String operationId,
    CloudSyncSnapshotData value, {
    CloudSyncSnapshotData? recoveryPoint,
  }) async {
    stages[operationId] = value;
    baseRecoveryPoints[operationId] = base;
  }

  @override
  Future<CloudSyncSnapshotData> readStaged(String operationId) async =>
      stages[operationId]!;
  @override
  Future<String> stagedFingerprint(String operationId) async =>
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  @override
  Future<void> apply(String operationId) async {}
  @override
  Future<void> rollback(String operationId) async => stages.remove(operationId);
  @override
  Future<void> rollbackForRecovery(String operationId) async {}
  @override
  Future<void> restoreBaseForRecovery(String operationId) async {
    if (!baseRecoveryPoints.containsKey(operationId)) {
      throw StateError('base recovery state is missing');
    }
    base = baseRecoveryPoints[operationId];
  }

  @override
  Future<void> saveBase(CloudSyncSnapshotData value, String snapshotId) async =>
      base = value;
  @override
  Future<void> writeUploadArtifact(
    String operationId,
    String name,
    List<int> bytes,
  ) async => artifacts['$operationId/$name'] = Uint8List.fromList(bytes);
  @override
  Future<List<int>?> readUploadArtifact(
    String operationId,
    String name,
  ) async => artifacts['$operationId/$name'];
  @override
  Future<void> deleteUploadArtifact(String operationId, String name) async =>
      artifacts.remove('$operationId/$name');
  @override
  Future<void> completeOperation(String operationId) async {
    stages.remove(operationId);
    baseRecoveryPoints.remove(operationId);
    artifacts.removeWhere((key, _) => key.startsWith('$operationId/'));
  }
}

class _MemoryLocalStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async => values[key] = value;

  @override
  Future<void> deleteSetting(String key) async => values.remove(key);
}

class _MemorySecureStorage extends SecureStorageService {
  String? credentials;

  @override
  Future<void> saveCloudSyncCredentials(String encodedCredentials) async =>
      credentials = encodedCredentials;
  @override
  Future<String?> getCloudSyncCredentials() async => credentials;
  @override
  Future<void> clearCloudSyncSecrets() async {
    credentials = null;
  }
}
