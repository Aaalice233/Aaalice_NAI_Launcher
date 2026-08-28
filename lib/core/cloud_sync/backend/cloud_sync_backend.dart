import 'dart:typed_data';

const maxCloudHeadResponseBytes = 64 * 1024;
const maxCloudKeyResponseBytes = 64 * 1024;
const maxCloudManifestResponseBytes = 1024 * 1024 + 64;
const maxCloudObjectResponseBytes = 4 * 1024 * 1024;
const maxCloudListingResponseBytes = 4 * 1024 * 1024;
const maxCloudJsonApiResponseBytes = 6 * 1024 * 1024;

enum CloudBackendMode { bidirectional, manualBackupOnly }

class CloudBackendCapability {
  const CloudBackendCapability({
    required this.mode,
    required this.message,
    this.supportsHistory = true,
    this.supportsDelete = true,
    this.warnings = const [],
  });

  final CloudBackendMode mode;
  final String message;
  final bool supportsHistory;
  final bool supportsDelete;
  final List<String> warnings;

  bool get supportsBidirectional => mode == CloudBackendMode.bidirectional;
}

class CloudObjectRead {
  const CloudObjectRead({required this.bytes, required this.revision});

  final Uint8List bytes;
  final String revision;
}

class CloudHeadRead extends CloudObjectRead {
  const CloudHeadRead({required super.bytes, required super.revision});
}

class CloudCommitResult {
  const CloudCommitResult({required this.revision});

  final String revision;
}

/// Rotatable remote key material kept independently from immutable snapshots.
/// Implementations store it at the namespace root as `KEY.json` and must use
/// the same compare-and-swap semantics as HEAD.
abstract interface class CloudKeyEnvelopeBackend {
  Future<CloudObjectRead?> readKeyEnvelope();

  Future<CloudCommitResult> commitKeyEnvelope(
    Uint8List bytes, {
    required String? expectedRevision,
  });
}

enum CloudBackendErrorKind {
  authentication,
  authorization,
  notFound,
  conflict,
  quota,
  rateLimited,
  redirectRejected,
  invalidResponse,
  network,
}

class CloudBackendException implements Exception {
  const CloudBackendException(
    this.kind,
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.cause,
  });

  final CloudBackendErrorKind kind;
  final String message;
  final int? statusCode;
  final DateTime? retryAfter;

  /// Original transport cause for internal diagnostics. Never included in
  /// user-facing messages or [toString].
  final Object? cause;

  @override
  String toString() => 'CloudBackendException($kind): $message';
}

abstract interface class CloudSyncBackend {
  Future<CloudBackendCapability> testCapability();

  Future<CloudHeadRead?> readHead();

  Future<CloudObjectRead?> readObject(String objectId);

  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId);

  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
  });

  /// Creates a manifest once; implementations must not replace different
  /// bytes at the same snapshot id.
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
  });

  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  });

  Future<List<String>> listSnapshotIds({int limit = 20});

  Future<void> deleteNamespace();
}

/// Optional maintenance implemented only by backends that can safely reclaim
/// immutable objects without rewriting provider history.
abstract interface class CloudSyncBackendMaintenance {
  Future<CloudMaintenanceResult> cleanUnreferencedObjects();
}

class CloudMaintenanceResult {
  const CloudMaintenanceResult({
    required this.scanned,
    required this.deleted,
    required this.skipped,
    this.warnings = const [],
  });

  final int scanned;
  final int deleted;
  final int skipped;
  final List<String> warnings;
}
