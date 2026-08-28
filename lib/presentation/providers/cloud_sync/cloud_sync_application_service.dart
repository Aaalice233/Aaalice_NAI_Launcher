import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/key_envelope_service.dart';
import '../../../core/cloud_sync/operation.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/storage/local_storage_service.dart';
import 'cloud_sync_connection_store.dart';
import 'cloud_sync_capability_mapper.dart';
import 'cloud_sync_conflict_selections.dart';
import 'cloud_sync_ui_provider.dart';
import 'cloud_sync_factories.dart';
import 'cloud_sync_error_reporter.dart';
import 'cloud_sync_flight_gate.dart';
import 'cloud_sync_lifecycle_policy.dart';
import 'cloud_sync_maintenance.dart';
import 'cloud_sync_operation_runner.dart';

class CloudSyncApplicationService implements CloudSyncUiPort {
  CloudSyncApplicationService({
    required CloudBackendFactory backendFactory,
    required CloudCoordinatorFactory coordinatorFactory,
    required SecureStorageService secureStorage,
    required LocalStorageService localStorage,
    required void Function(CloudSyncUiState state) onState,
    Future<void> Function()? installFfdkjDictionary,
    String Function()? deviceIdFactory,
  }) : _backendFactory = backendFactory,
       _coordinatorFactory = coordinatorFactory,
       _secureStorage = secureStorage,
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
  final SecureStorageService _secureStorage;
  final Future<void> Function() _installFfdkjDictionary;
  final void Function(CloudSyncUiState state) _onState;
  final CloudSyncConnectionStore _connectionStore;
  CloudSyncUiState _state = const CloudSyncUiState();
  CloudSyncBackend? _backend;
  CloudKeyEnvelopeService? _keys;
  CloudKeyEnvelopeSession? _keySession;
  SyncCoordinator? _coordinator;
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
      _keys?.discardPrepared();
      _keySession = null;
      _coordinator = null;
      final backend = _backendFactory(connection);
      final capability = await backend.testCapability();
      final keyBackend = backend as CloudKeyEnvelopeBackend;
      final envelope = await keyBackend.readKeyEnvelope();
      final head = await backend.readHead();
      if (head != null && envelope == null) {
        throw StateError('Remote HEAD exists without KEY.json.');
      }
      _backend = backend;
      _keys = CloudKeyEnvelopeService(
        backend: keyBackend,
        secureStorage: _secureStorage,
      );
      _set(
        _state.copyWith(
          backend: connection.backend,
          capabilityMode: capability.supportsBidirectional
              ? CloudSyncCapabilityMode.bidirectional
              : CloudSyncCapabilityMode.manualBackupOnly,
          supportsHistory: capability.supportsHistory,
          supportsDelete: capability.supportsDelete,
          capabilityWarnings: capability.warnings,
          providerLimit: cloudSyncProviderLimit(connection),
          remoteExists: envelope != null,
          remoteRevision: cloudSyncSnapshotId(head),
          clearError: true,
        ),
      );
    } catch (error) {
      _errorReporter.record(error);
      rethrow;
    }
  }

  @override
  Future<String> createRecoveryKey(String password) =>
      _gate.run((_) => _createRecoveryKey(password));

  Future<String> _createRecoveryKey(String password) async {
    if (_state.remoteExists != false || _keys == null) {
      throw StateError('Remote detection must confirm an empty namespace.');
    }
    return _keys!.prepareCreate(password);
  }

  @override
  Future<void> recoverKeyEnvelope(String recoveryKey, String newPassword) =>
      _gate.run((_) => _recoverKeyEnvelope(recoveryKey, newPassword));

  Future<void> _recoverKeyEnvelope(
    String recoveryKey,
    String newPassword,
  ) async {
    final keys = _keys;
    if (_state.remoteExists != true || keys == null) {
      throw StateError('No remote key envelope was detected.');
    }
    _keySession = await keys.recover(recoveryKey, newPassword);
  }

  @override
  Future<void> connect(CloudSyncConnectRequest request) =>
      _gate.run((operation) => _connect(request, operation));

  Future<void> _connect(
    CloudSyncConnectRequest request,
    OperationToken operation,
  ) async {
    try {
      if (request.initialAction == CloudSyncInitialAction.mergePreview) {
        _state.ensureNoPendingPreview();
      }
      await initialize();
      if (_backend == null || _keys == null) {
        await _detectRemote(request.connection);
      }
      if (_state.capabilityMode == CloudSyncCapabilityMode.manualBackupOnly &&
          request.initialAction != CloudSyncInitialAction.upload) {
        throw StateError(
          'This backend only supports explicit manual backup uploads.',
        );
      }
      if (_state.remoteExists == true) {
        _keySession ??= await _keys!.unlock(
          password: request.encryptionPassword,
        );
      } else {
        if (!request.recoveryKeyConfirmed) {
          throw StateError('Recovery key confirmation is required.');
        }
        _keySession = await _keys!.commitPrepared();
      }
      _coordinator = await _coordinatorFactory(
        _backend!,
        _keySession!,
        request.dataKinds,
        request.contentSelection,
      );
      await _coordinator!.recoverPending();
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
          clearError: true,
        ),
      );
      switch (request.initialAction) {
        case CloudSyncInitialAction.mergePreview:
          await _operations.previewInitial();
        case CloudSyncInitialAction.upload:
          await _operations.runSync(
            operation,
            direction: CloudSyncInitialAction.upload,
          );
        case CloudSyncInitialAction.download:
          if (_state.capabilityMode ==
              CloudSyncCapabilityMode.manualBackupOnly) {
            throw StateError('This backend only supports manual uploads.');
          }
          await _operations.runSync(
            operation,
            direction: CloudSyncInitialAction.download,
          );
      }
    } catch (error) {
      if (_state.error != '$error') _errorReporter.record(error);
      rethrow;
    }
  }

  Future<bool> restorePersisted({bool synchronize = false}) =>
      _gate.tryRunLifecycle(
        (operation) =>
            _restorePersisted(synchronize: synchronize, operation: operation),
      );

  Future<void> _restorePersisted({
    required bool synchronize,
    required OperationToken operation,
  }) async {
    try {
      await initialize();
      final persisted = await _connectionStore.load();
      if (persisted == null) return;
      final knownRevision = _state.isConnected
          ? _state.remoteRevision
          : persisted.remoteRevision;
      if (_backend == null || _keys == null || _coordinator == null) {
        await _detectRemote(persisted.draft);
        if (_state.remoteExists != true) return;
        _keySession = await _keys!.unlock();
        _coordinator = await _coordinatorFactory(
          _backend!,
          _keySession!,
          persisted.dataKinds,
          persisted.contentSelection,
        );
      }
      final head = await _backend!.readHead();
      var currentRevision = cloudSyncSnapshotId(head);
      final hasPendingJournal = await _coordinator!.journalStore.read() != null;
      if (hasPendingJournal) {
        await _coordinator!.recoverPending();
        currentRevision = cloudSyncSnapshotId(await _backend!.readHead());
      }
      _set(
        _state.copyWith(
          connectionStatus: CloudSyncConnectionStatus.connected,
          remoteRevision: currentRevision ?? knownRevision,
          lastSync: _state.lastSync ?? persisted.lastSync,
        ),
      );
      if (shouldRunLifecycleSync(
        synchronize,
        _state.capabilityMode,
        knownRevision,
        currentRevision,
        hasPendingJournal,
      )) {
        _state.ensureNoPendingPreview();
        await _operations.runSync(operation);
      }
    } catch (error) {
      _errorReporter.record(error);
      rethrow;
    }
  }

  @override
  Future<void> syncNow() {
    _state.ensureNoPendingPreview();
    return _gate.run(_operations.runSync);
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
  Future<void> changePassword(String password) async {
    await _gate.run((_) async {
      _keySession = await _keys!.changePassword(_keySession!, password);
    });
  }

  @override
  Future<void> rotateRecoveryKey() => _gate.run((_) async {
    final keys = _keys;
    final session = _keySession;
    if (keys == null || session == null) {
      throw StateError('Cloud sync is not connected.');
    }
    _set(
      _state.copyWith(
        activityStatus: CloudSyncActivityStatus.syncing,
        clearError: true,
      ),
    );
    try {
      final rotated = await keys.rotateRecoveryKey(session);
      _keySession = rotated;
      final recoveryKey = rotated.recoveryKey;
      if (recoveryKey == null || recoveryKey.isEmpty) {
        throw StateError('Recovery key rotation did not return a new key.');
      }
      _set(
        _state.copyWith(
          activityStatus: CloudSyncActivityStatus.idle,
          pendingRecoveryKey: recoveryKey,
        ),
      );
    } catch (error) {
      _errorReporter.record(error, resetActivity: true);
      rethrow;
    }
  });

  @override
  Future<void> confirmRecoveryKeySaved() async {
    if (_state.pendingRecoveryKey == null) {
      throw StateError('No new recovery key is awaiting confirmation.');
    }
    _set(_state.copyWith(clearPendingRecoveryKey: true));
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
    _keys?.discardPrepared();
    _keys = null;
    _backend = null;
    _coordinator = null;
    _keySession = null;
    _conflictSelections.clear();
    await _connectionStore.clear();
    _set(CloudSyncUiState(deviceName: _state.deviceName));
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
