import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/models.dart';
import '../../../core/cloud_sync/object_codec.dart';
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
    String Function()? deviceIdFactory,
  }) : _backendFactory = backendFactory,
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
  final Future<void> Function() _installFfdkjDictionary;
  final void Function(CloudSyncUiState state) _onState;
  final CloudSyncConnectionStore _connectionStore;
  CloudSyncUiState _state = const CloudSyncUiState();
  CloudSyncBackend? _backend;
  SyncCoordinator? _coordinator;
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
      _legacyRemoteIgnored = false;
      final backend = _backendFactory(connection);
      final capability = await backend.testCapability();
      final head = await backend.readHead();
      final legacyEncrypted = _isLegacyEncryptedHead(head);
      _backend = backend;
      _legacyRemoteIgnored = legacyEncrypted;
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
          remoteExists: head != null && !legacyEncrypted,
          remoteRevision: legacyEncrypted ? null : cloudSyncSnapshotId(head),
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
      _coordinator = await _coordinatorFactory(
        _backend!,
        const PlainCloudObjectCodec(),
        request.dataKinds,
        request.contentSelection,
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
      final recoveredLegacy = _isLegacyEncryptedHead(recoveredHead);
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
          clearError: true,
        ),
      );
    } catch (error) {
      if (_state.error != '$error') _errorReporter.record(error);
      rethrow;
    }
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
        _coordinator = await _coordinatorFactory(
          _backend!,
          const PlainCloudObjectCodec(),
          persisted.dataKinds,
          persisted.contentSelection,
        );
      }
      final head = await _backend!.readHead();
      var currentRevision = _isLegacyEncryptedHead(head)
          ? null
          : cloudSyncSnapshotId(head);
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
        currentRevision = _isLegacyEncryptedHead(recoveredHead)
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
    _backend = null;
    _coordinator = null;
    _legacyRemoteIgnored = false;
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
