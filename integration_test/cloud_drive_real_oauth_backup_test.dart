import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/cloud_drive_provider_factory.dart';
import 'package:nai_launcher/core/cloud_sync/coordinator.dart';
import 'package:nai_launcher/core/cloud_sync/crypto.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/key_envelope_service.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/object_codec.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_config.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_factory.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_models.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/app_cloud_sync_data_source.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter_registry.dart';
import 'package:nai_launcher/data/cloud_sync/portable_sync_record.dart';

const _enabled = bool.fromEnvironment('RUN_REAL_CLOUD_DRIVE_E2E');
const _providerId = String.fromEnvironment('REAL_CLOUD_DRIVE_E2E_PROVIDER');
const _namespace = String.fromEnvironment('REAL_CLOUD_DRIVE_E2E_NAMESPACE');
const _cleanupConfirmed = bool.fromEnvironment(
  'REAL_CLOUD_DRIVE_E2E_CONFIRM_CLEANUP',
);
const _cleanupOnly = bool.fromEnvironment('REAL_CLOUD_DRIVE_E2E_CLEANUP_ONLY');
const _expectedAccountHash = String.fromEnvironment(
  'REAL_CLOUD_DRIVE_E2E_EXPECTED_ACCOUNT_SHA256',
);
const _namespacePrefix = 'aaalice-e2e-';
const _marker = 'aaalice-real-oauth-e2e-marker-v1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real OAuth encrypted cloud-drive backup round trip',
    skip: !_enabled,
    (tester) async {
      _validateInvocation();
      final providerId = CloudDriveOAuthProvider.parse(_providerId);
      final status = ValueNotifier<String>('准备安全的真实 OAuth 测试…');
      addTearDown(status.dispose);
      await tester.pumpWidget(_StatusApp(status: status));

      final oauthStorage = SecureStorageService(
        storage: const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          lOptions: LinuxOptions(),
          wOptions: WindowsOptions(),
          mOptions: MacOsOptions(useDataProtectionKeyChain: false),
        ),
        cloudDriveOAuthSessionPrefix:
            'aaalice.cloud-drive.e2e.oauth.v1.${sha256.convert(utf8.encode(_namespace))}.',
      );
      final oauthConfig = CloudDriveOAuthConfig.fromDartDefines();
      oauthConfig.requireProvider(providerId);
      final runtime = createCloudDriveOAuthRuntime(
        oauthStorage,
        config: oauthConfig,
      );
      final tokens = runtime.tokens;
      final provider = createCloudDriveProviderRegistry(
        runtime,
      ).require(providerId);

      CloudDriveOAuthSession? oauthSession;
      String? oauthAccountId;
      CloudSyncBackend? backend;
      final localRoots = <Directory>[];
      addTearDown(() async {
        Object? firstFailure;
        StackTrace? firstStack;
        try {
          if (backend != null) await _deleteAndVerifyNamespace(backend);
        } catch (error, stack) {
          firstFailure = error;
          firstStack = stack;
        }
        try {
          if (oauthSession != null) {
            await provider.disconnect(oauthSession.accountId);
          }
        } catch (error, stack) {
          firstFailure ??= error;
          firstStack ??= stack;
        }
        try {
          if (oauthAccountId != null) {
            await oauthStorage.deleteCloudDriveOAuthSession(
              providerId: providerId.id,
              accountId: oauthAccountId,
            );
            expect(
              await oauthStorage.getCloudDriveOAuthSession(
                providerId: providerId.id,
                accountId: oauthAccountId,
              ),
              isNull,
            );
          }
        } catch (error, stack) {
          firstFailure ??= error;
          firstStack ??= stack;
        }
        for (final root in localRoots) {
          try {
            if (await root.exists()) await root.delete(recursive: true);
          } catch (error, stack) {
            firstFailure ??= error;
            firstStack ??= stack;
          }
        }
        if (firstFailure != null) {
          Error.throwWithStackTrace(firstFailure, firstStack!);
        }
      });

      await _status(status, tester, '请在系统浏览器中登录专用测试账号…');
      final connectedSession = await provider.connect();
      oauthAccountId = connectedSession.accountId;
      final persistedSession = await tokens.readSession(
        providerId,
        connectedSession.accountId,
      );
      expect(persistedSession, isNotNull);
      expect(persistedSession!.provider == connectedSession.provider, isTrue);
      expect(persistedSession.accountId == connectedSession.accountId, isTrue);
      expect(
        persistedSession.displayIdentifier ==
            connectedSession.displayIdentifier,
        isTrue,
      );
      final actualAccountHash = sha256
          .convert(
            utf8.encode(
              connectedSession.displayIdentifier.trim().toLowerCase(),
            ),
          )
          .toString();
      expect(
        actualAccountHash,
        _expectedAccountHash,
        reason:
            'The selected OAuth account is not the confirmed test account. No cloud data was accessed and the local session will be deleted; revoke the unintended consent manually if it was newly granted.',
      );
      oauthSession = connectedSession;
      await _status(status, tester, 'OAuth 成功，正在验证隔离云端目录…');
      backend = provider.createBackend(
        accountId: oauthSession.accountId,
        namespace: _namespace,
      );

      if (_cleanupOnly) {
        await _deleteAndVerifyNamespace(backend);
        await _status(status, tester, '隔离测试目录已清理。');
        return;
      }

      final capability = await backend.testCapability();
      switch (providerId) {
        case CloudDriveOAuthProvider.googleDrive:
          expect(capability.mode, CloudBackendMode.manualBackupOnly);
        case CloudDriveOAuthProvider.oneDrive:
          expect(capability.mode, CloudBackendMode.bidirectional);
      }
      expect(capability.supportsDelete, isTrue);

      final password1 = _randomPassword();
      final password2 = _randomPassword();
      final password3 = _randomPassword();
      final keyStorageA = _EphemeralMasterKeyStorage();
      final keyServiceA = _keyService(
        backend: backend,
        storage: keyStorageA,
        provider: providerId,
        accountId: oauthSession.accountId,
      );
      final keyA = await keyServiceA.create(password1);
      expect(keyA.recoveryKey, isNotEmpty);
      final initialRemoteKey = await (backend as CloudKeyEnvelopeBackend)
          .readKeyEnvelope();
      expect(initialRemoteKey, isNotNull);
      final initialWrappedKey = WrappedMasterKey.decode(
        initialRemoteKey!.bytes,
      );
      await CloudCrypto().verifyEnvelope(keyA.masterKey, initialWrappedKey);
      expect(initialWrappedKey.recoveryBox, isNotNull);

      final adapterA = _SyntheticAdapter.initial();
      final rootA = await _localRoot('device-a', localRoots);
      final coordinatorA = _coordinator(
        backend: backend,
        adapter: adapterA,
        root: rootA,
        masterKey: keyA.masterKey,
      );
      await _status(status, tester, '正在上传加密合成备份…');
      final firstUpload = await coordinatorA.uploadLocal();
      expect(firstUpload.uploaded, isTrue);
      final firstDigest = await adapterA.digest();
      await _verifyRemoteObjectsAreEncrypted(
        backend: backend,
        expectedSnapshotId: firstUpload.snapshotId,
        codec: LegacyEncryptedCloudObjectCodec(
          crypto: CloudCrypto(),
          masterKey: keyA.masterKey,
        ),
      );

      final keyStorageB = _EphemeralMasterKeyStorage();
      final keyServiceB = _keyService(
        backend: backend,
        storage: keyStorageB,
        provider: providerId,
        accountId: oauthSession.accountId,
      );
      final keyB = await keyServiceB.recoverAndRotate(
        keyA.recoveryKey!,
        password2,
      );
      expect(keyB.recoveryKey, isNotEmpty);
      expect(keyB.recoveryKey, isNot(keyA.recoveryKey));
      expect(keyB.revision, isNot(keyA.revision));
      final unlockedB = await keyServiceB.unlock();
      await CloudCrypto().verifyEnvelope(
        unlockedB.masterKey,
        unlockedB.envelope,
      );
      final staleRecovery = _keyService(
        backend: backend,
        storage: _EphemeralMasterKeyStorage(),
        provider: providerId,
        accountId: oauthSession.accountId,
      );
      await expectLater(
        staleRecovery.recover(keyA.recoveryKey!, 'unused'),
        throwsA(isA<CloudCryptoException>()),
      );

      final adapterB = _SyntheticAdapter.empty();
      final rootB = await _localRoot('device-b', localRoots);
      final coordinatorB = _coordinator(
        backend: backend,
        adapter: adapterB,
        root: rootB,
        masterKey: keyB.masterKey,
      );
      await _status(status, tester, '正在模拟新设备拉取并解密…');
      await coordinatorB.downloadRemote();
      expect(await adapterB.digest(), await adapterA.digest());

      adapterB.updateForSecondBackup();
      await _status(status, tester, '正在上传第二版合成备份…');
      late String secondSnapshotId;
      if (capability.mode == CloudBackendMode.bidirectional) {
        final result = await coordinatorB.synchronize();
        expect(result.uploaded, isTrue);
        secondSnapshotId = result.snapshotId;
      } else {
        final result = await coordinatorB.uploadLocal();
        expect(result.uploaded, isTrue);
        secondSnapshotId = result.snapshotId;
      }

      final keyStorageC = _EphemeralMasterKeyStorage();
      final keyServiceC = _keyService(
        backend: backend,
        storage: keyStorageC,
        provider: providerId,
        accountId: oauthSession.accountId,
      );
      final keyC = await keyServiceC.recoverAndRotate(
        keyB.recoveryKey!,
        password3,
      );
      expect(keyC.revision, isNot(keyB.revision));
      final staleRecoveryB = _keyService(
        backend: backend,
        storage: _EphemeralMasterKeyStorage(),
        provider: providerId,
        accountId: oauthSession.accountId,
      );
      await expectLater(
        staleRecoveryB.recover(keyB.recoveryKey!, 'unused-again'),
        throwsA(isA<CloudCryptoException>()),
      );
      final adapterC = _SyntheticAdapter.empty();
      final rootC = await _localRoot('device-c', localRoots);
      final coordinatorC = _coordinator(
        backend: backend,
        adapter: adapterC,
        root: rootC,
        masterKey: keyC.masterKey,
      );
      await coordinatorC.downloadRemote();
      expect(await adapterC.digest(), await adapterB.digest());
      final history = await _waitForHistory(coordinatorC, {
        firstUpload.snapshotId,
        secondSnapshotId,
      });
      expect(
        history.map((entry) => entry.id).toSet(),
        containsAll({firstUpload.snapshotId, secondSnapshotId}),
      );

      final preview = await coordinatorC.previewRestore(firstUpload.snapshotId);
      expect(preview.changes, isNotEmpty);
      final restored = await coordinatorC.restore(firstUpload.snapshotId);
      expect(restored.uploaded, isTrue);
      expect(await adapterC.digest(), firstDigest);
      expect(
        firstDigest.any(
          (record) => (record['data']! as String).contains(_marker),
        ),
        isTrue,
      );
      await _verifyRemoteObjectsAreEncrypted(
        backend: backend,
        expectedSnapshotId: restored.snapshotId,
        codec: LegacyEncryptedCloudObjectCodec(
          crypto: CloudCrypto(),
          masterKey: keyC.masterKey,
        ),
      );
      final restoredHistory = await _waitForHistory(coordinatorC, {
        firstUpload.snapshotId,
        secondSnapshotId,
        restored.snapshotId,
      });
      expect(restoredHistory.length, greaterThanOrEqualTo(3));
      await _status(status, tester, '真实 OAuth 加密备份往返验证通过，正在清理…');
    },
  );
}

void _validateInvocation() {
  if (!_cleanupConfirmed) {
    throw StateError(
      'Isolated remote cleanup and OAuth disconnect not confirmed.',
    );
  }
  if (!_namespace.startsWith(_namespacePrefix) ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(_namespace)) {
    throw StateError('Refusing to use a non-E2E cloud namespace.');
  }
  if (_providerId != CloudDriveOAuthProvider.googleDrive.id &&
      _providerId != CloudDriveOAuthProvider.oneDrive.id) {
    throw StateError('Unsupported E2E provider.');
  }
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(_expectedAccountHash)) {
    throw StateError('Expected test-account hash is missing or invalid.');
  }
}

CloudKeyEnvelopeService _keyService({
  required CloudSyncBackend backend,
  required SecureStorageService storage,
  required CloudDriveOAuthProvider provider,
  required String accountId,
}) => CloudKeyEnvelopeService(
  backend: backend as CloudKeyEnvelopeBackend,
  secureStorage: storage,
  providerId: provider.id,
  accountId: accountId,
);

SyncCoordinator _coordinator({
  required CloudSyncBackend backend,
  required _SyntheticAdapter adapter,
  required Directory root,
  required SecretKey masterKey,
}) => SyncCoordinator(
  backend: backend,
  dataSource: AppCloudSyncDataSource(
    registry: CloudSyncDataAdapterRegistry([adapter]),
    root: root,
    chunkSize: 4,
  ),
  codec: LegacyEncryptedCloudObjectCodec(
    crypto: CloudCrypto(),
    masterKey: masterKey,
  ),
  journalStore: JournalStore(File('${root.path}/journal.json')),
);

Future<Directory> _localRoot(String suffix, List<Directory> roots) async {
  final root = await Directory.systemTemp.createTemp('aaalice-e2e-$suffix-');
  roots.add(root);
  return root;
}

Future<void> _deleteAndVerifyNamespace(CloudSyncBackend backend) async {
  await backend.deleteNamespace();
  final inspector = backend as CloudNamespaceInspectionBackend;
  for (var attempt = 0; attempt < 8; attempt++) {
    final head = await backend.readHead();
    final key = await (backend as CloudKeyEnvelopeBackend).readKeyEnvelope();
    final snapshots = await backend.listSnapshotIds(limit: 1);
    final namespaceEmpty = await inspector.isNamespaceEmpty();
    if (head == null && key == null && snapshots.isEmpty && namespaceEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError('The isolated cloud namespace was not fully deleted.');
}

Future<List<SnapshotHistoryEntry>> _waitForHistory(
  SyncCoordinator coordinator,
  Set<String> expectedIds,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  List<SnapshotHistoryEntry> history = const [];
  do {
    history = await coordinator.history();
    if (history.map((entry) => entry.id).toSet().containsAll(expectedIds)) {
      return history;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  } while (DateTime.now().isBefore(deadline));
  return history;
}

Future<void> _verifyRemoteObjectsAreEncrypted({
  required CloudSyncBackend backend,
  required CloudObjectCodec codec,
  required String expectedSnapshotId,
}) async {
  final headRead = await backend.readHead();
  expect(headRead, isNotNull);
  final head = SnapshotHead.decode(headRead!.bytes);
  expect(head.snapshotId, expectedSnapshotId);
  expect(head.encoding, CloudSnapshotEncoding.encrypted);
  final manifestRead = await backend.readSnapshotManifest(head.snapshotId);
  expect(manifestRead, isNotNull);
  expect(sha256.convert(manifestRead!.bytes).toString(), head.manifestSha256);
  final clearManifest = await codec.decode(
    manifestRead.bytes,
    objectId: head.snapshotId,
    kind: 'manifest',
  );
  expect(manifestRead.bytes, isNot(equals(clearManifest)));
  final manifest = SnapshotManifest.decode(clearManifest);
  expect(manifest.snapshotId, expectedSnapshotId);
  expect(manifest.encoding, CloudSnapshotEncoding.encrypted);

  final marker = utf8.encode(_marker);
  var foundMarkerAfterDecryption = false;
  for (final object in manifest.objects) {
    final remote = await backend.readObject(object.id);
    expect(remote, isNotNull);
    object.verify(remote!.bytes);
    expect(_containsBytes(remote.bytes, marker), isFalse);
    final clear = await codec.decode(
      remote.bytes,
      objectId: object.id,
      kind: object.kind,
    );
    expect(remote.bytes, isNot(equals(clear)));
    final record = CloudSyncRecord.decode(clear);
    expect(record.kind, object.kind);
    final bytes = record.bytes;
    if (bytes != null && _containsBytes(bytes, marker)) {
      foundMarkerAfterDecryption = true;
    }
  }
  expect(foundMarkerAfterDecryption, isTrue);
}

String _randomPassword() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
}

bool _containsBytes(List<int> source, List<int> target) {
  if (target.isEmpty) return true;
  for (var offset = 0; offset <= source.length - target.length; offset++) {
    var matches = true;
    for (var index = 0; index < target.length; index++) {
      if (source[offset + index] != target[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

Future<void> _status(
  ValueNotifier<String> status,
  WidgetTester tester,
  String value,
) async {
  status.value = value;
  await tester.pump();
}

class _StatusApp extends StatelessWidget {
  const _StatusApp({required this.status});

  final ValueListenable<String> status;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (context, value, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(value, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    const Text(
                      '不要在脚本或测试中输入、保存或输出密码和验证码。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EphemeralMasterKeyStorage extends SecureStorageService {
  final Map<String, String> _keys = {};

  String _key(String providerId, String accountId) => '$providerId:$accountId';

  @override
  Future<void> saveCloudDriveMasterKey({
    required String providerId,
    required String accountId,
    required String encodedKey,
  }) async {
    _keys[_key(providerId, accountId)] = encodedKey;
  }

  @override
  Future<String?> getCloudDriveMasterKey({
    required String providerId,
    required String accountId,
  }) async => _keys[_key(providerId, accountId)];

  @override
  Future<void> clearCloudDriveEncryptionSecrets({
    required String providerId,
    required String accountId,
  }) async {
    _keys.remove(_key(providerId, accountId));
  }
}

class _SyntheticAdapter extends ValidatingCloudSyncDataAdapter {
  _SyntheticAdapter._(this._records);

  factory _SyntheticAdapter.initial() => _SyntheticAdapter._([
    PortableSyncRecord(
      adapterId: _adapterId,
      id: 'settings',
      kind: 'settings',
      data: const {'locale': 'ja', 'theme': 'dark', 'revision': 1},
    ),
    PortableSyncRecord(
      adapterId: _adapterId,
      id: 'prompt',
      kind: 'prompt',
      data: const {'text': _marker, 'negative': 'lowres', 'revision': 1},
    ),
    _resourceRecord(Uint8List.fromList(const [1, 3, 3, 7, 9, 2, 6, 5])),
  ]);

  factory _SyntheticAdapter.empty() => _SyntheticAdapter._([]);

  static const _adapterId = 'e2e-synthetic';
  List<PortableSyncRecord> _records;

  @override
  String get id => _adapterId;

  @override
  Set<String> get allowedKinds => const {'settings', 'prompt', 'binary'};

  @override
  Stream<PortableSyncRecord> exportRecords() => Stream.fromIterable(_records);

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    final applied = <PortableSyncRecord>[];
    for (final record in records.where((record) => !record.deleted)) {
      Uint8List? bytes;
      final resource = record.resource;
      if (resource != null) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in resource.openRead()) {
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
        if (bytes.length != resource.length) {
          throw const CloudSyncPreflightException(
            'Synthetic resource length mismatch',
          );
        }
      }
      applied.add(
        PortableSyncRecord(
          adapterId: record.adapterId,
          id: record.id,
          kind: record.kind,
          data: record.data,
          resource: bytes == null ? null : _resource(bytes),
        ),
      );
    }
    _records = applied;
  }

  void updateForSecondBackup() {
    _records = [
      PortableSyncRecord(
        adapterId: _adapterId,
        id: 'settings',
        kind: 'settings',
        data: const {'locale': 'en', 'theme': 'dark', 'revision': 2},
      ),
      PortableSyncRecord(
        adapterId: _adapterId,
        id: 'prompt',
        kind: 'prompt',
        data: const {'text': '$_marker-updated', 'revision': 2},
      ),
      _resourceRecord(Uint8List.fromList(const [8, 6, 7, 5, 3, 0, 9])),
    ];
  }

  Future<List<Map<String, Object?>>> digest() async {
    final result = <Map<String, Object?>>[];
    for (final record in _records) {
      Uint8List? resourceBytes;
      if (record.resource != null) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in record.resource!.openRead()) {
          builder.add(chunk);
        }
        resourceBytes = builder.takeBytes();
      }
      result.add({
        'id': record.id,
        'kind': record.kind,
        'data': jsonEncode(record.data),
        'resourceSha256': resourceBytes == null
            ? null
            : sha256.convert(resourceBytes).toString(),
      });
    }
    result.sort(
      (left, right) =>
          (left['id']! as String).compareTo(right['id']! as String),
    );
    return result;
  }

  static PortableSyncRecord _resourceRecord(Uint8List bytes) =>
      PortableSyncRecord(
        adapterId: _adapterId,
        id: 'binary',
        kind: 'binary',
        data: const {'name': 'sample.bin', 'revision': 1},
        resource: _resource(bytes),
      );

  static PortableSyncResource _resource(Uint8List bytes) =>
      PortableSyncResource(
        relativePath: 'resources/sample.bin',
        length: bytes.length,
        openRead: () => Stream.value(Uint8List.fromList(bytes)),
      );
}
