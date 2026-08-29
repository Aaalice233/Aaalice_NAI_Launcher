import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud_sync/content_selection.dart';
import 'cloud_sync_provider_wiring.dart';

enum CloudSyncBackendKind { webDav, github }

enum CloudSyncConnectionStatus { disconnected, connected }

enum CloudSyncActivityStatus { idle, syncing, paused }

enum CloudSyncCapabilityMode { bidirectional, manualBackupOnly }

enum CloudSyncConflictChoice { local, remote, keepBoth }

enum CloudSyncDataKind { settings, prompts, galleries, largeBinary }

enum CloudSyncChangeKind { added, modified, deleted }

@immutable
class CloudSyncChangeSummary {
  const CloudSyncChangeSummary({
    required this.kind,
    required this.added,
    required this.modified,
    required this.deleted,
  });

  final CloudSyncDataKind kind;
  final int added;
  final int modified;
  final int deleted;
  int get total => added + modified + deleted;
}

@immutable
class CloudSyncPreviewView {
  const CloudSyncPreviewView({
    required this.title,
    required this.changes,
    this.snapshotId,
    this.isRestore = false,
  });

  final String title;
  final String? snapshotId;
  final bool isRestore;
  final List<CloudSyncChangeSummary> changes;
  int get conflictSafeDeletionCount =>
      changes.fold(0, (sum, row) => sum + row.deleted);
}

@immutable
class CloudSyncConnectionDraft {
  const CloudSyncConnectionDraft({
    required this.backend,
    this.serverUrl = '',
    this.username = '',
    this.secret = '',
    this.owner = '',
    this.repository = '',
    this.branch = 'main',
    this.path = '',
    this.allowInsecureHttp = false,
  });

  final CloudSyncBackendKind backend;
  final String serverUrl;
  final String username;
  final String secret;
  final String owner;
  final String repository;
  final String branch;
  final String path;
  final bool allowInsecureHttp;
}

@immutable
class CloudSyncCapabilityResult {
  const CloudSyncCapabilityResult({
    required this.succeeded,
    required this.mode,
    required this.message,
    this.supportsHistory = false,
    this.supportsDelete = false,
    this.warnings = const [],
    this.limit,
  });

  const CloudSyncCapabilityResult.unavailable()
    : succeeded = false,
      mode = CloudSyncCapabilityMode.manualBackupOnly,
      message = '',
      supportsHistory = false,
      supportsDelete = false,
      warnings = const [],
      limit = null;

  final bool succeeded;
  final CloudSyncCapabilityMode mode;
  final String message;
  final bool supportsHistory;
  final bool supportsDelete;
  final List<String> warnings;
  final String? limit;
}

@immutable
class CloudSyncConnectRequest {
  const CloudSyncConnectRequest({
    required this.connection,
    required this.dataKinds,
    this.legacyPassword = '',
    this.contentSelection = const CloudSyncContentSelection(),
  });

  final CloudSyncConnectionDraft connection;
  final Set<CloudSyncDataKind> dataKinds;
  final String legacyPassword;
  final CloudSyncContentSelection contentSelection;
}

enum CloudSyncInitialAction { upload, download, mergePreview }

@immutable
class CloudSyncProgressView {
  const CloudSyncProgressView({
    required this.stage,
    required this.objectName,
    required this.completedBytes,
    required this.totalBytes,
    required this.completedObjects,
    required this.totalObjects,
  });

  final String stage;
  final String objectName;
  final int completedBytes;
  final int totalBytes;
  final int completedObjects;
  final int totalObjects;

  double? get fraction => totalBytes == 0 ? null : completedBytes / totalBytes;
}

@immutable
class CloudSyncLogEntry {
  const CloudSyncLogEntry({required this.time, required this.message});

  final DateTime time;
  final String message;
}

@immutable
class CloudSyncSnapshotView {
  const CloudSyncSnapshotView({
    required this.id,
    required this.createdAt,
    required this.summary,
  });

  final String id;
  final DateTime createdAt;
  final String summary;
}

@immutable
class CloudSyncConflictView {
  const CloudSyncConflictView({
    required this.id,
    required this.kind,
    required this.title,
    required this.baseSummary,
    required this.localSummary,
    required this.remoteSummary,
    this.choice,
  });

  final String id;
  final CloudSyncDataKind kind;
  final String title;
  final String baseSummary;
  final String localSummary;
  final String remoteSummary;
  final CloudSyncConflictChoice? choice;

  CloudSyncConflictChoice get effectiveChoice =>
      choice ??
      (kind == CloudSyncDataKind.largeBinary
          ? CloudSyncConflictChoice.keepBoth
          : CloudSyncConflictChoice.local);
}

@immutable
class CloudSyncUiState {
  const CloudSyncUiState({
    this.connectionStatus = CloudSyncConnectionStatus.disconnected,
    this.activityStatus = CloudSyncActivityStatus.idle,
    this.backend,
    this.deviceName,
    this.lastSync,
    this.remoteRevision,
    this.capabilityMode = CloudSyncCapabilityMode.bidirectional,
    this.supportsHistory = true,
    this.supportsDelete = true,
    this.capabilityWarnings = const [],
    this.providerLimit,
    this.progress,
    this.logs = const [],
    this.snapshots = const [],
    this.conflicts = const [],
    this.remoteExists,
    this.legacyEncryptedBackup = false,
    this.legacyUnlockRequired = false,
    this.pendingPreview,
    this.pendingFfdkjInstall = false,
    this.maintenanceWarning,
    this.error,
  });

  final CloudSyncConnectionStatus connectionStatus;
  final CloudSyncActivityStatus activityStatus;
  final CloudSyncBackendKind? backend;
  final String? deviceName;
  final DateTime? lastSync;
  final String? remoteRevision;
  final CloudSyncCapabilityMode capabilityMode;
  final bool supportsHistory;
  final bool supportsDelete;
  final List<String> capabilityWarnings;
  final String? providerLimit;
  final CloudSyncProgressView? progress;
  final List<CloudSyncLogEntry> logs;
  final List<CloudSyncSnapshotView> snapshots;
  final List<CloudSyncConflictView> conflicts;
  final bool? remoteExists;
  final bool legacyEncryptedBackup;
  final bool legacyUnlockRequired;
  final CloudSyncPreviewView? pendingPreview;
  final bool pendingFfdkjInstall;
  final String? maintenanceWarning;
  final String? error;

  bool get isConnected =>
      connectionStatus == CloudSyncConnectionStatus.connected;
  bool get needsConflictResolution => conflicts.isNotEmpty;
  bool get isBusy => activityStatus != CloudSyncActivityStatus.idle;
  bool get needsPreviewConfirmation => pendingPreview != null;

  void ensureNoPendingPreview() {
    if (pendingPreview != null) {
      throw StateError('Confirm or finish the pending preview first.');
    }
  }

  void ensureRestoreAvailable() {
    if (capabilityMode == CloudSyncCapabilityMode.manualBackupOnly ||
        !supportsHistory) {
      throw StateError('Snapshot restore is unavailable on this backend.');
    }
  }

  CloudSyncUiState copyWith({
    CloudSyncConnectionStatus? connectionStatus,
    CloudSyncActivityStatus? activityStatus,
    CloudSyncBackendKind? backend,
    String? deviceName,
    DateTime? lastSync,
    String? remoteRevision,
    CloudSyncCapabilityMode? capabilityMode,
    bool? supportsHistory,
    bool? supportsDelete,
    List<String>? capabilityWarnings,
    String? providerLimit,
    CloudSyncProgressView? progress,
    List<CloudSyncLogEntry>? logs,
    List<CloudSyncSnapshotView>? snapshots,
    List<CloudSyncConflictView>? conflicts,
    bool? remoteExists,
    bool? legacyEncryptedBackup,
    bool? legacyUnlockRequired,
    CloudSyncPreviewView? pendingPreview,
    bool? pendingFfdkjInstall,
    String? maintenanceWarning,
    String? error,
    bool clearProgress = false,
    bool clearError = false,
    bool clearPendingPreview = false,
    bool clearMaintenanceWarning = false,
  }) => CloudSyncUiState(
    connectionStatus: connectionStatus ?? this.connectionStatus,
    activityStatus: activityStatus ?? this.activityStatus,
    backend: backend ?? this.backend,
    deviceName: deviceName ?? this.deviceName,
    lastSync: lastSync ?? this.lastSync,
    remoteRevision: remoteRevision ?? this.remoteRevision,
    capabilityMode: capabilityMode ?? this.capabilityMode,
    supportsHistory: supportsHistory ?? this.supportsHistory,
    supportsDelete: supportsDelete ?? this.supportsDelete,
    capabilityWarnings: capabilityWarnings ?? this.capabilityWarnings,
    providerLimit: providerLimit ?? this.providerLimit,
    progress: clearProgress ? null : progress ?? this.progress,
    logs: logs ?? this.logs,
    snapshots: snapshots ?? this.snapshots,
    conflicts: conflicts ?? this.conflicts,
    remoteExists: remoteExists ?? this.remoteExists,
    legacyEncryptedBackup: legacyEncryptedBackup ?? this.legacyEncryptedBackup,
    legacyUnlockRequired: legacyUnlockRequired ?? this.legacyUnlockRequired,
    pendingPreview: clearPendingPreview
        ? null
        : pendingPreview ?? this.pendingPreview,
    pendingFfdkjInstall: pendingFfdkjInstall ?? this.pendingFfdkjInstall,
    maintenanceWarning: clearMaintenanceWarning
        ? null
        : maintenanceWarning ?? this.maintenanceWarning,
    error: clearError ? null : error ?? this.error,
  );
}

abstract interface class CloudSyncUiPort {
  Future<CloudSyncCapabilityResult> testConnection(
    CloudSyncConnectionDraft connection,
  );

  Future<void> detectRemote(CloudSyncConnectionDraft connection);

  Future<void> connect(CloudSyncConnectRequest request);

  Future<void> unlockLegacyBackup(String password);

  Future<void> recoverLegacyBackup(String recoveryKey, String newPassword);

  Future<void> syncNow();

  Future<void> applyPendingPreview();

  Future<void> pause();

  Future<void> resume();

  Future<void> cancel();

  Future<void> previewRestoreSnapshot(String snapshotId);

  Future<void> confirmRestoreSnapshot();

  Future<void> deleteRemoteNamespace();

  Future<void> disconnect();

  Future<void> resolveConflict(
    String conflictId,
    CloudSyncConflictChoice choice,
  );

  Future<void> resolveAllConflicts(CloudSyncConflictChoice choice);

  Future<void> respondToFfdkjInstallIntent({required bool install});
}

/// Test/embedding adapter whose operations are unsupported unless overridden.
class CloudSyncUiPortAdapter implements CloudSyncUiPort {
  const CloudSyncUiPortAdapter();

  @override
  Future<CloudSyncCapabilityResult> testConnection(
    CloudSyncConnectionDraft connection,
  ) async => const CloudSyncCapabilityResult.unavailable();

  @override
  Future<void> cancel() => _unavailable();

  @override
  Future<void> applyPendingPreview() => _unavailable();

  @override
  Future<void> connect(CloudSyncConnectRequest request) => _unavailable();

  @override
  Future<void> unlockLegacyBackup(String password) => _unavailable();

  @override
  Future<void> recoverLegacyBackup(String recoveryKey, String newPassword) =>
      _unavailable();

  @override
  Future<void> deleteRemoteNamespace() => _unavailable();

  @override
  Future<void> detectRemote(CloudSyncConnectionDraft connection) =>
      _unavailable();

  @override
  Future<void> disconnect() => _unavailable();

  @override
  Future<void> pause() => _unavailable();

  @override
  Future<void> resolveAllConflicts(CloudSyncConflictChoice choice) =>
      _unavailable();

  @override
  Future<void> resolveConflict(
    String conflictId,
    CloudSyncConflictChoice choice,
  ) => _unavailable();

  @override
  Future<void> previewRestoreSnapshot(String snapshotId) => _unavailable();

  @override
  Future<void> confirmRestoreSnapshot() => _unavailable();

  @override
  Future<void> respondToFfdkjInstallIntent({required bool install}) =>
      _unavailable();

  @override
  Future<void> resume() => _unavailable();

  @override
  Future<void> syncNow() => _unavailable();

  Future<void> _unavailable() async {
    throw StateError('Cloud sync service is not connected.');
  }
}

final cloudSyncUiPortProvider = Provider<CloudSyncUiPort>(
  (ref) => ref.watch(cloudSyncApplicationServiceProvider),
);

final cloudSyncUiStateProvider = Provider<CloudSyncUiState>(
  (ref) => ref.watch(cloudSyncApplicationStateProvider),
);
