import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import 'cloud_sync_ui_provider.dart';

CloudSyncCapabilityResult mapCloudSyncCapability(
  CloudSyncConnectionDraft connection,
  CloudBackendCapability capability,
) => CloudSyncCapabilityResult(
  succeeded: true,
  mode: capability.supportsBidirectional
      ? CloudSyncCapabilityMode.bidirectional
      : CloudSyncCapabilityMode.manualBackupOnly,
  message: capability.message,
  supportsHistory: capability.supportsHistory,
  supportsDelete: capability.supportsDelete,
  warnings: capability.warnings,
  limit: cloudSyncProviderLimit(connection),
);

String? cloudSyncProviderLimit(CloudSyncConnectionDraft connection) =>
    connection.backend == CloudSyncBackendKind.github
    ? 'GitHub Contents API: 100 MiB per file'
    : null;
