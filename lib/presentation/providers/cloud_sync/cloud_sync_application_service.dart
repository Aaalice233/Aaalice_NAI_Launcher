import 'dart:convert';
import 'dart:math';

import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/cloud_drive_provider.dart';
import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/crypto.dart';
import '../../../core/cloud_sync/key_envelope_service.dart';
import '../../../core/cloud_sync/models.dart';
import '../../../core/cloud_sync/object_codec.dart';
import '../../../core/cloud_sync/operation.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import 'cloud_sync_connection_store.dart';
import 'cloud_sync_capability_mapper.dart';
import 'cloud_sync_conflict_selections.dart';
import 'cloud_sync_ui_provider.dart';
import 'cloud_sync_factories.dart';
import 'cloud_sync_error_reporter.dart';
import 'cloud_sync_flight_gate.dart';
import 'cloud_sync_head_reader.dart';
import 'cloud_sync_maintenance.dart';
import 'cloud_sync_operation_runner.dart';
import 'cloud_sync_progress_mapper.dart';

bool _isLegacyEncryptedHead(CloudHeadRead? head) =>
    head != null &&
    SnapshotHead.decode(head.bytes).encoding == CloudSnapshotEncoding.encrypted;

class CloudSyncApplicationService implements CloudSyncUiPort {
  CloudSyncApplicationService({
    required CloudBackendFactory backendFactory,
    required CloudCoordinatorFactory coordinatorFactory,
    required SecureStorageService secureStorage,
    required LocalStorageService localStorage,
    required void Function(CloudSyncUiState state) onState,
    Future<void> Function()? installFfdkjDictionary,
    CloudDriveProviderRegistry? cloudDriveProviders,
    String Function()? deviceIdFactory,
  }) : _backendFactory = backendFactory,
       _cloudDriveProviders = cloudDriveProviders,
       _secureStorage = secureStorage,
       _coordinatorFactory = coordinatorFactory,
       _installFfdkjDictionary =
           installFfdkjDictionary ??
           (() => Future.error(StateError('ffdkj installer is unavailable.'))),
       _onState = onState,
       _connectionStore = CloudSyncConnectionStore(
         localStorage: localStorage,
         secureStorage: secureStorage,
         deviceIdFactory: deviceIdFactory,
       ) {
    _maintenance = CloudSyncMaintenance(
      localStorage: localStorage,
      readState: () => _state,
      writeState: _set,
    );
    _errorReporter = CloudSyncErrorReporter(
      readState: () => _state,
      writeState: _set,
    );
    _operations = CloudSyncOperationRunner(
      coordinator: () => _coordinator,
      readState: () => _state,
      writeState: _set,
      recordError: _errorReporter.record,
      readPendingFfdkjIntent: _maintenance.readPendingFfdkjIntent,
      afterSuccessfulWrite: () => _maintenance.run(_backend),
      persistSyncState: (revision, lastSync) => _connectionStore.saveSyncState(
        remoteRevision: revision,
        lastSync: lastSync,
      ),
    );
  }

  final CloudBackendFactory _backendFactory;
  final CloudCoordinatorFactory _coordinatorFactory;
  final CloudDriveProviderRegistry? _cloudDriveProviders;
  final SecureStorageService _secureStorage;
  final Future<void> Function() _installFfdkjDictionary;
  final void Function(CloudSyncUiState state) _onState;
  final CloudSyncConnectionStore _connectionStore;
  CloudSyncUiState _state = const CloudSyncUiState();
  CloudSyncBackend? _backend;
  SyncCoordinator? _coordinator;
  CloudKeyEnvelopeService? _keys;
  CloudKeyEnvelopeSession? _keySession;
  bool _remoteKeyExists = false;
  bool _legacyRemoteIgnored = false;
  final CloudSyncFlightGate _gate = CloudSyncFlightGate();
  late final CloudSyncOperationRunner _operations;
  late final CloudSyncMaintenance _maintenance;
  late final CloudSyncErrorReporter _errorReporter;
  final CloudSyncConflictSelections _conflictSelections =
      CloudSyncConflictSelections();

  void dispose() => _maintenance.dispose();

  Future<void> initialize() async {
    if (_state.deviceName != null) return;
    _set(await _connectionStore.initializeState(_state));
  }

  void _set(CloudSyncUiState value) {
    _state = value;
    _onState(value);
  }

  @override
  Future<CloudSyncCapabilityResult> testConnection(
    CloudSyncConnectionDraft connection,
  ) => _gate.run((_) async {
    try {
      final capability = await _backendFactory(connection).testCapability();
      _set(_state.copyWith(clearError: true));
      return mapCloudSyncCapability(connection, capability);
    } catch (error) {
      _errorReporter.record(error);
      rethrow;
    }
  });

  @override
  Future<void> detectRemote(CloudSyncConnectionDraft connection) =>
      _gate.run((_) => _detectRemote(connection));

  Future<void> _detectRemote(CloudSyncConnectionDraft connection) async {
    try {
      _backend = null;
      _coordinator = null;
      _keys = null;
      _keySession = null;
      _remoteKeyExists = false;
      _legacyRemoteIgnored = false;
      final backend = _backendFactory(connection);
      final capability = await backend.testCapability();
      final head = await backend.readHead();
      var remoteExists = head != null;
      var remoteRevision = cloudSyncSnapshotId(head);
      var recoveryRequired = false;
      String? pendingRecoveryKey;
      if (connection.backend.usesOAuth) {
        final keyBackend = backend as CloudKeyEnvelopeBackend;
        final envelope = await keyBackend.readKeyEnvelope();
        final encoding = head == null
            ? null
            : SnapshotHead.decode(head.bytes).encoding;
        if (head != null && envelope == null) {
          throw StateError(
            'Encrypted cloud-drive HEAD exists without KEY.json.',
          );
        }
        if (encoding == CloudSnapshotEncoding.plain) {
          throw StateError(
            'This cloud-drive namespace contains an unsupported unencrypted snapshot.',
          );
        }
        _remoteKeyExists = envelope != null;
        _keys = CloudKeyEnvelopeService(
          backend: keyBackend,
          secureStorage: _secureStorage,
          providerId: connection.backend.oauthProvider.id,
          accountId: connection.accountId,
        );
        final localKey = await _secureStorage.getCloudDriveMasterKey(
          providerId: connection.backend.oauthProvider.id,
          accountId: connection.accountId,
        );
        pendingRecoveryKey = await _secureStorage
            .getCloudDrivePendingRecoveryKey(
              providerId: connection.backend.oauthProvider.id,
              accountId: connection.accountId,
            );
        recoveryRequired = envelope != null && localKey == null;
      } else {
        final legacyEncrypted = _isLegacyEncryptedHead(head);
        _legacyRemoteIgnored = legacyEncrypted;
        remoteExists = head != null && !legacyEncrypted;
        remoteRevision = legacyEncrypted ? null : remoteRevision;
      }
      _backend = backend;
      _set(
        _state.copyWith(
          backend: connection.backend,
          accountId: connection.accountId.isEmpty ? null : connection.accountId,
          accountLabel: connection.accountLabel.isEmpty
              ? null
              : connection.accountLabel,
          capabilityMode: capability.supportsBidirectional
              ? CloudSyncCapabilityMode.bidirectional
              : CloudSyncCapabilityMode.manualBackupOnly,
          supportsHistory: capability.supportsHistory,
          supportsDelete: capability.supportsDelete,
          capabilityWarnings: capability.warnings,
          providerLimit: cloudSyncProviderLimit(connection),
          remoteExists: remoteExists,
          remoteRevision: remoteRevision,
          recoveryRequired: recoveryRequired,
          pendingRecoveryKey: pendingRecoveryKey,
          clearPendingRecoveryKey: pendingRecoveryKey == null,
          clearError: true,
        ),
      );
    } catch (error) {
      _errorReporter.record(error);
      rethrow;
    }
  }

  @override
  Future<void> connect(CloudSyncConnectRequest request) =>
      _gate.run((operation) => _connect(request, operation));

  @override
  Future<CloudSyncConnectionDraft> authorizeCloudDrive(
    CloudSyncBackendKind backend,
  ) => _gate.run((_) async {
    if (!backend.usesOAuth) {
      throw ArgumentError.value(backend, 'backend', 'must use OAuth');
    }
    final providers = _cloudDriveProviders;
    if (providers == null) {
      throw StateError('Cloud-drive OAuth is unavailable in this build.');
    }
    final stopwatch = Stopwatch()..start();
    AppLogger.i(
      'Cloud-drive authorization requested: backend=${backend.name}',
      'CloudSync',
    );
    try {
      final session = await providers.require(backend.oauthProvider).connect();
      AppLogger.i(
        'Cloud-drive authorization completed: backend=${backend.name}, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
        'CloudSync',
      );
      return CloudSyncConnectionDraft(
        backend: backend,
        path: 'aaalice-sync',
        accountId: session.accountId,
        accountLabel: session.displayIdentifier,
      );
    } catch (error, stackTrace) {
      AppLogger.e(
        'Cloud-drive authorization failed: backend=${backend.name}, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
        error,
        stackTrace,
        'CloudSync',
      );
      _errorReporter.record(error);
      rethrow;
    }
  });

  @override
  Future<void> discardCloudDriveAuthorization(
    CloudSyncConnectionDraft connection,
  ) async {
    if (!connection.backend.usesOAuth || connection.accountId.isEmpty) return;
    final providers = _cloudDriveProviders;
    if (providers == null) return;
    await providers
        .require(connection.backend.oauthProvider)
        .disconnect(connection.accountId);
  }

  @override
  Future<void> recoverCloudDriveEncryption(String recoveryKey) =>
      _gate.run((operation) async {
        final persisted = await _connectionStore.load();
        if (persisted == null || !persisted.draft.backend.usesOAuth) {
          throw StateError('No cloud-drive connection is awaiting recovery.');
        }
        if (_backend == null || _keys == null) {
          await _detectRemote(persisted.draft);
        }
        final keys = _keys;
        if (keys == null || !_remoteKeyExists) {
          throw StateError('Remote encryption metadata is missing.');
        }
        final random = Random.secure();
        final wrappingSecret = base64UrlEncode(
          List<int>.generate(32, (_) => random.nextInt(256)),
        );
        _keySession = await keys.recoverAndRotate(
          recoveryKey.trim(),
          wrappingSecret,
        );
        final replacementRecoveryKey = _keySession!.recoveryKey!;
        await _secureStorage.saveCloudDrivePendingRecoveryKey(
          providerId: persisted.draft.backend.oauthProvider.id,
          accountId: persisted.draft.accountId,
          recoveryKey: replacementRecoveryKey,
        );
        final codec = LegacyEncryptedCloudObjectCodec(
          crypto: CloudCrypto(),
          masterKey: _keySession!.masterKey,
        );
        _coordinator = await _coordinatorFactory(
          _backend!,
          codec,
          persisted.dataKinds,
          persisted.contentSelection,
          persisted.draft,
        );
        await _coordinator!.recoverPending(
          token: operation,
          onProgress: (progress) =>
              _set(_state.copyWith(progress: mapCloudSyncProgress(progress))),
        );
        _set(
          _state.copyWith(
            recoveryRequired: false,
            pendingRecoveryKey: replacementRecoveryKey,
            clearProgress: true,
            clearError: true,
          ),
        );
      });

  @override
  Future<void> confirmCloudDriveRecoveryKeySaved() async {
    final persisted = await _connectionStore.load();
    if (persisted == null || !persisted.draft.backend.usesOAuth) {
      throw StateError('No cloud-drive recovery key is pending.');
    }
    if (_state.pendingRecoveryKey == null) {
      throw StateError('No cloud-drive recovery key is pending.');
    }
    await _secureStorage.clearCloudDrivePendingRecoveryKey(
      providerId: persisted.draft.backend.oauthProvider.id,
      accountId: persisted.draft.accountId,
    );
    _set(_state.copyWith(clearPendingRecoveryKey: true));
  }

  Future<void> _connect(
    CloudSyncConnectRequest request,
    OperationToken operation,
  ) async {
    try {
      _state.ensureNoPendingPreview();
      await initialize();
      // The one-page form remains editable after a failed attempt, so every
      // save must rebuild and verify the backend from the current draft.
      await _detectRemote(request.connection);
      if (request.connection.backend.usesOAuth && _state.recoveryRequired) {
        await _connectionStore.save(
          request.connection,
          request.dataKinds,
          contentSelection: request.contentSelection,
          remoteRevision: _state.remoteRevision,
          lastSync: _state.lastSync,
        );
        _set(
          _state.copyWith(
            connectionStatus: CloudSyncConnectionStatus.connected,
            clearError: true,
          ),
        );
        return;
      }
      final codec = await _codecForConnection(request.connection);
      _coordinator = await _coordinatorFactory(
        _backend!,
        codec,
        request.dataKinds,
        request.contentSelection,
        request.connection,
      );
      if (_legacyRemoteIgnored) {
        await _coordinator!.discardPending();
      } else {
        await _coordinator!.recoverPending(
          token: operation,
          onProgress: (progress) =>
              _set(_state.copyWith(progress: mapCloudSyncProgress(progress))),
        );
      }
      final recoveredHead = await _backend!.readHead();
      final recoveredLegacy =
          !request.connection.backend.usesOAuth &&
          _isLegacyEncryptedHead(recoveredHead);
      _set(
        _state.copyWith(
          remoteExists: recoveredHead != null && !recoveredLegacy,
          remoteRevision: recoveredLegacy
              ? null
              : cloudSyncSnapshotId(recoveredHead),
          clearProgress: true,
        ),
      );
      await _connectionStore.save(
        request.connection,
        request.dataKinds,
        contentSelection: request.contentSelection,
        remoteRevision: _state.remoteRevision,
        lastSync: _state.lastSync,
      );
      _set(
        _state.copyWith(
          connectionStatus: CloudSyncConnectionStatus.connected,
          backend: request.connection.backend,
          accountId: request.connection.accountId.isEmpty
              ? null
              : request.connection.accountId,
          accountLabel: request.connection.accountLabel.isEmpty
              ? null
              : request.connection.accountLabel,
          clearError: true,
        ),
      );
    } catch (error) {
      if (_state.error != '$error') _errorReporter.record(error);
      rethrow;
    }
  }

  Future<CloudObjectCodec> _codecForConnection(
    CloudSyncConnectionDraft connection,
  ) async {
    if (!connection.backend.usesOAuth) {
      return const PlainCloudObjectCodec();
    }
    final keys = _keys;
    if (keys == null) {
      throw StateError('Cloud-drive encryption is not initialized.');
    }
    if (_remoteKeyExists) {
      _keySession ??= await keys.unlock();
    } else {
      final random = Random.secure();
      final deviceWrappingSecret = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      final recoveryKey = await keys.prepareCreate(deviceWrappingSecret);
      _keySession = await keys.commitPrepared();
      _remoteKeyExists = true;
      await _secureStorage.saveCloudDrivePendingRecoveryKey(
        providerId: connection.backend.oauthProvider.id,
        accountId: connection.accountId,
        recoveryKey: recoveryKey,
      );
      _set(_state.copyWith(pendingRecoveryKey: recoveryKey));
    }
    return LegacyEncryptedCloudObjectCodec(
      crypto: CloudCrypto(),
      masterKey: _keySession!.masterKey,
    );
  }

  Future<bool> restorePersisted() => _gate.tryRunLifecycle(
    (operation) => _restorePersisted(operation: operation),
  );

  Future<void> _restorePersisted({required OperationToken operation}) async {
    try {
      await initialize();
      final persisted = await _connectionStore.load();
      if (persisted == null) return;
      final knownRevision = _state.isConnected
          ? _state.remoteRevision
          : persisted.remoteRevision;
      if (_backend == null || _coordinator == null) {
        await _detectRemote(persisted.draft);
        if (persisted.draft.backend.usesOAuth && _state.recoveryRequired) {
          _set(
            _state.copyWith(
              connectionStatus: CloudSyncConnectionStatus.connected,
              lastSync: persisted.lastSync,
              clearProgress: true,
            ),
          );
          return;
        }
        final codec = await _codecForConnection(persisted.draft);
        _coordinator = await _coordinatorFactory(
          _backend!,
          codec,
          persisted.dataKinds,
          persisted.contentSelection,
          persisted.draft,
        );
      }
      final head = await _backend!.readHead();
      final legacyEncrypted =
          !persisted.draft.backend.usesOAuth && _isLegacyEncryptedHead(head);
      var currentRevision = legacyEncrypted ? null : cloudSyncSnapshotId(head);
      final hasPendingJournal = await _coordinator!.journalStore.read() != null;
      if (hasPendingJournal) {
        if (_legacyRemoteIgnored) {
          await _coordinator!.discardPending();
        } else {
          await _coordinator!.recoverPending(
            token: operation,
            onProgress: (progress) =>
                _set(_state.copyWith(progress: mapCloudSyncProgress(progress))),
          );
        }
        final recoveredHead = await _backend!.readHead();
        currentRevision =
            !persisted.draft.backend.usesOAuth &&
                _isLegacyEncryptedHead(recoveredHead)
            ? null
            : cloudSyncSnapshotId(recoveredHead);
      }
      _set(
        _state.copyWith(
          connectionStatus: CloudSyncConnectionStatus.connected,
          remoteRevision: currentRevision ?? knownRevision,
          lastSync: _state.lastSync ?? persisted.lastSync,
          clearProgress: true,
        ),
      );
    } catch (error) {
      _errorReporter.record(error);
      rethrow;
    }
  }

  @override
  Future<void> pushNow() {
    _state.ensureNoPendingPreview();
    if (!_state.encryptionReady || _coordinator == null) {
      return Future.error(StateError('Save the recovery key before syncing.'));
    }
    return _gate.run(
      (operation) => _operations.runSync(
        operation,
        direction: CloudSyncInitialAction.upload,
      ),
    );
  }

  @override
  Future<void> pullNow() {
    _state.ensureNoPendingPreview();
    if (!_state.encryptionReady || _coordinator == null) {
      return Future.error(
        StateError('Unlock encryption and save the recovery key first.'),
      );
    }
    if (_state.remoteExists != true) {
      return Future.error(StateError('Remote snapshot is missing.'));
    }
    return _gate.run(
      (operation) => _operations.runSync(
        operation,
        direction: CloudSyncInitialAction.download,
      ),
    );
  }

  @override
  Future<void> applyPendingPreview() {
    if (_state.capabilityMode == CloudSyncCapabilityMode.manualBackupOnly) {
      return Future.error(
        StateError('Merge is unavailable in manual backup mode.'),
      );
    }
    if (_state.pendingPreview == null || _state.pendingPreview!.isRestore) {
      return Future.error(
        StateError('No merge preview is awaiting confirmation.'),
      );
    }
    if (_state.conflicts.any((item) => item.choice == null)) {
      return Future.error(
        StateError('Resolve every conflict before applying.'),
      );
    }
    if (_state.conflicts.isEmpty) {
      return _gate.run(_operations.runSync);
    }
    return _runResolvedMerge();
  }

  Future<void> _runResolvedMerge() => _gate.run(
    (operation) =>
        _operations.runResolvedMerge(operation, _conflictSelections.choices),
  );

  @override
  Future<void> cancel() async => _gate.operation?.cancel();
  @override
  Future<void> pause() async {
    _gate.operation?.pause();
    _set(_state.copyWith(activityStatus: CloudSyncActivityStatus.paused));
  }

  @override
  Future<void> resume() async {
    _gate.operation?.resume();
    _set(_state.copyWith(activityStatus: CloudSyncActivityStatus.syncing));
  }

  @override
  Future<void> previewRestoreSnapshot(String snapshotId) async {
    _state.ensureRestoreAvailable();
    _state.ensureNoPendingPreview();
    return _gate.run(
      (operation) => _operations.previewRestore(snapshotId, operation),
    );
  }

  @override
  Future<void> confirmRestoreSnapshot() {
    if (_state.capabilityMode == CloudSyncCapabilityMode.manualBackupOnly) {
      return Future.error(
        StateError('Restore is unavailable in manual backup mode.'),
      );
    }
    final preview = _state.pendingPreview;
    if (preview == null || !preview.isRestore || preview.snapshotId == null) {
      return Future.error(
        StateError('No restore preview is awaiting confirmation.'),
      );
    }
    return _gate.run(
      (operation) => _operations.restore(preview.snapshotId!, operation),
    );
  }

  @override
  Future<void> deleteRemoteNamespace() => _gate.run((_) async {
    if (!_state.supportsDelete) {
      throw StateError('This backend does not support namespace deletion.');
    }
    try {
      await _backend!.deleteNamespace();
      await _clearConnection();
    } catch (error) {
      _errorReporter.record(error);
      rethrow;
    }
  });

  @override
  Future<void> disconnect() async {
    await _gate.cancelAndClose(_clearConnection);
  }

  Future<void> _clearConnection() async {
    final persisted = await _connectionStore.load();
    Object? cleanupError;
    StackTrace? cleanupStack;
    _backend = null;
    _coordinator = null;
    _keys = null;
    _keySession = null;
    _remoteKeyExists = false;
    _legacyRemoteIgnored = false;
    _conflictSelections.clear();
    if (persisted != null &&
        persisted.draft.backend.usesOAuth &&
        persisted.draft.accountId.isNotEmpty) {
      try {
        await _secureStorage.clearCloudDriveEncryptionSecrets(
          providerId: persisted.draft.backend.oauthProvider.id,
          accountId: persisted.draft.accountId,
        );
      } catch (error, stack) {
        cleanupError = error;
        cleanupStack = stack;
      }
      try {
        final providers = _cloudDriveProviders;
        if (providers != null) {
          await providers
              .require(persisted.draft.backend.oauthProvider)
              .disconnect(persisted.draft.accountId);
        }
      } catch (error, stack) {
        cleanupError ??= error;
        cleanupStack ??= stack;
      }
    }
    await _connectionStore.clear();
    _set(CloudSyncUiState(deviceName: _state.deviceName));
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStack!);
    }
  }

  @override
  Future<void> resolveConflict(
    String conflictId,
    CloudSyncConflictChoice choice,
  ) async {
    if (_state.capabilityMode == CloudSyncCapabilityMode.manualBackupOnly) {
      throw StateError(
        'Conflict application is unavailable in manual backup mode.',
      );
    }
    _set(
      _state.copyWith(
        conflicts: _conflictSelections.chooseOne(
          _state.conflicts,
          conflictId,
          choice,
        ),
      ),
    );
  }

  @override
  Future<void> resolveAllConflicts(CloudSyncConflictChoice choice) async {
    if (_state.capabilityMode == CloudSyncCapabilityMode.manualBackupOnly) {
      throw StateError(
        'Conflict application is unavailable in manual backup mode.',
      );
    }
    _set(
      _state.copyWith(
        conflicts: _conflictSelections.chooseAll(_state.conflicts, choice),
      ),
    );
  }

  @override
  Future<void> respondToFfdkjInstallIntent({required bool install}) async {
    if (install) await _installFfdkjDictionary();
    await _maintenance.clearFfdkjIntent();
  }
}
