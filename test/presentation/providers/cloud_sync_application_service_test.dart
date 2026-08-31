import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/coordinator.dart';
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
    expect(fixture.backend.keyEnvelope, isNull);
    expect(fixture.codecEncoding, CloudSnapshotEncoding.plain);
    expect(fixture.secure.credentials, contains('provider-secret'));
    expect(fixture.local.values[StorageKeys.cloudSyncConfiguration], isNotNull);
  });

  test(
    'legacy encrypted HEAD is ignored without replacing remote data',
    () async {
      final backend = _ApplicationBackend();
      backend.head = CloudHeadRead(
        bytes: Uint8List.fromList(
          SnapshotHead(
            snapshotId: 'legacy-encrypted-snapshot',
            manifestSha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            updatedAt: DateTime.utc(2025),
            encoding: CloudSnapshotEncoding.encrypted,
          ).encode(),
        ),
        revision: 'legacy-head',
      );
      final fixture = await _Fixture.create(backend: backend);
      addTearDown(fixture.dispose);
      const legacyOperationId = 'legacy-pending-operation';
      await fixture.source.stage(legacyOperationId, fixture.source.snapshot);
      await fixture.journal.write(
        SyncJournal(
          operationId: legacyOperationId,
          operation: JournalOperation.uploadLocal,
          phase: JournalPhase.prepared,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: 'legacy-pending-snapshot',
          targetFingerprint: await fixture.source.stagedFingerprint(
            legacyOperationId,
          ),
          expectedRevision: 'legacy-head',
          uploadRequired: true,
        ),
      );

      await fixture.service.connect(
        const CloudSyncConnectRequest(
          connection: _draft,
          dataKinds: {CloudSyncDataKind.settings},
        ),
      );

      final head = SnapshotHead.decode(backend.head!.bytes);
      expect(head.snapshotId, 'legacy-encrypted-snapshot');
      expect(head.encoding, CloudSnapshotEncoding.encrypted);
      expect(await fixture.journal.read(), isNull);
      expect(fixture.source.stages, isEmpty);
      expect(fixture.states.last.remoteExists, isFalse);
      expect(fixture.codecEncoding, CloudSnapshotEncoding.plain);
    },
  );

  test(
    'recovered initial upload is not followed by a duplicate snapshot',
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

      expect(
        SnapshotHead.decode(fixture.backend.head!.bytes).snapshotId,
        snapshotId,
      );
      expect(
        fixture.backend.events.where((event) => event == 'head'),
        hasLength(1),
      );
      expect(await fixture.journal.read(), isNull);
    },
  );

  test(
    'persisted fresh namespace remains connected for one-click retry',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final store = CloudSyncConnectionStore(
        localStorage: fixture.local,
        secureStorage: fixture.secure,
      );
      await store.save(_draft, {CloudSyncDataKind.settings});

      final restored = await fixture.service.restorePersisted();

      expect(restored, isTrue);
      expect(fixture.backend.head, isNull);
      expect(
        fixture.states.last.connectionStatus,
        CloudSyncConnectionStatus.connected,
      );
      expect(fixture.codecEncoding, CloudSnapshotEncoding.plain);
    },
  );

  test(
    'cloud drive encrypts data and requires recovery on another device',
    () async {
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

      final recoveryKey = first.states.last.pendingRecoveryKey;
      expect(recoveryKey, startsWith('AA1-'));
      expect(first.codecEncoding, CloudSnapshotEncoding.encrypted);
      expect(first.backend.keyEnvelope, isNotNull);
      expect(first.backend.head, isNull);
      expect(
        first.local.values[StorageKeys.cloudDriveConfiguration],
        isNotNull,
      );
      expect(first.local.values[StorageKeys.cloudSyncConfiguration], isNull);
      await expectLater(first.service.pushNow(), throwsStateError);

      await first.service.confirmCloudDriveRecoveryKeySaved();
      await first.service.pushNow();
      expect(
        SnapshotHead.decode(first.backend.head!.bytes).encoding,
        CloudSnapshotEncoding.encrypted,
      );
      expect(
        first.backend.objects.values.every(
          (value) => !utf8
              .decode(value.bytes, allowMalformed: true)
              .contains('{"theme":"dark"}'),
        ),
        isTrue,
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
      expect(second.states.last.recoveryRequired, isTrue);
      expect(second.codecEncoding, isNull);
      await expectLater(second.service.pullNow(), throwsStateError);

      await second.service.recoverCloudDriveEncryption(recoveryKey!);
      expect(second.states.last.pendingRecoveryKey, startsWith('AA1-'));
      expect(second.codecEncoding, CloudSnapshotEncoding.encrypted);
      await second.service.confirmCloudDriveRecoveryKeySaved();
      await second.service.pullNow();
      expect(second.states.last.lastSync, isNotNull);
    },
  );

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

      expect(first.backend.capabilityChecks, 2);
      expect(second.backend.head!.bytes, remoteBefore);
      expect(second.backend.head!.revision, revisionBefore);
      expect(second.states.last.remoteExists, isTrue);
      expect(second.states.last.conflicts, isEmpty);
      expect(second.states.last.pendingPreview, isNull);
      expect(second.states.last.lastSync, isNull);
    },
  );
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
    required this.codecEncodingReader,
  });

  final Directory directory;
  final _ApplicationBackend backend;
  final _MemoryLocalStorage local;
  final _MemorySecureStorage secure;
  final List<CloudSyncUiState> states;
  final _MemorySource source;
  final JournalStore journal;
  final CloudSyncApplicationService service;
  final CloudSnapshotEncoding? Function() codecEncodingReader;

  CloudSnapshotEncoding? get codecEncoding => codecEncodingReader();

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
    CloudSnapshotEncoding? codecEncoding;
    final service = CloudSyncApplicationService(
      backendFactory: (_) => effectiveBackend,
      coordinatorFactory: (_, codec, __, ___, ____) async {
        codecEncoding = codec.encoding;
        return SyncCoordinator(
          backend: effectiveBackend,
          dataSource: source,
          codec: codec,
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
      codecEncodingReader: () => codecEncoding,
    );
  }

  Future<void> dispose() async {
    service.dispose();
    await directory.delete(recursive: true);
  }
}

class _ApplicationBackend extends CoordinatorTestBackend
    implements CloudKeyEnvelopeBackend {
  CloudObjectRead? keyEnvelope;
  int capabilityChecks = 0;

  @override
  Future<CloudBackendCapability> testCapability() async {
    capabilityChecks++;
    return super.testCapability();
  }

  @override
  Future<CloudObjectRead?> readKeyEnvelope() async => keyEnvelope;

  @override
  Future<CloudCommitResult> commitKeyEnvelope(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    if (keyEnvelope?.revision != expectedRevision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'KEY CAS failed',
      );
    }
    keyEnvelope = CloudObjectRead(
      bytes: Uint8List.fromList(bytes),
      revision: 'key-${++revision}',
    );
    return CloudCommitResult(revision: keyEnvelope!.revision);
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
  CloudSyncSnapshotData? base;

  @override
  Future<CloudSyncSnapshotData> captureLocal() async => snapshot;
  @override
  Future<CloudSyncSnapshotData?> readBase() async => base;
  @override
  Future<void> stage(String operationId, CloudSyncSnapshotData value) async =>
      stages[operationId] = value;
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
  String? masterKey;
  final scopedMasterKeys = <String, String>{};
  final pendingRecoveryKeys = <String, String>{};

  String _scope(String providerId, String accountId) =>
      '$providerId:$accountId';

  @override
  Future<void> saveCloudSyncCredentials(String encodedCredentials) async =>
      credentials = encodedCredentials;
  @override
  Future<String?> getCloudSyncCredentials() async => credentials;
  @override
  Future<void> saveCloudSyncMasterKey(String encodedKey) async =>
      masterKey = encodedKey;
  @override
  Future<String?> getCloudSyncMasterKey() async => masterKey;
  @override
  Future<void> saveCloudDriveMasterKey({
    required String providerId,
    required String accountId,
    required String encodedKey,
  }) async => scopedMasterKeys[_scope(providerId, accountId)] = encodedKey;
  @override
  Future<String?> getCloudDriveMasterKey({
    required String providerId,
    required String accountId,
  }) async => scopedMasterKeys[_scope(providerId, accountId)];
  @override
  Future<void> saveCloudDrivePendingRecoveryKey({
    required String providerId,
    required String accountId,
    required String recoveryKey,
  }) async => pendingRecoveryKeys[_scope(providerId, accountId)] = recoveryKey;
  @override
  Future<String?> getCloudDrivePendingRecoveryKey({
    required String providerId,
    required String accountId,
  }) async => pendingRecoveryKeys[_scope(providerId, accountId)];
  @override
  Future<void> clearCloudDrivePendingRecoveryKey({
    required String providerId,
    required String accountId,
  }) async => pendingRecoveryKeys.remove(_scope(providerId, accountId));
  @override
  Future<void> clearCloudDriveEncryptionSecrets({
    required String providerId,
    required String accountId,
  }) async {
    scopedMasterKeys.remove(_scope(providerId, accountId));
    pendingRecoveryKeys.remove(_scope(providerId, accountId));
  }

  @override
  Future<void> clearCloudSyncSecrets() async {
    credentials = null;
    masterKey = null;
  }
}
