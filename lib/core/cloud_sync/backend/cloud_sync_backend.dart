import 'dart:collection';
import 'dart:typed_data';

import '../operation.dart';

const maxCloudHeadResponseBytes = 64 * 1024;
const maxCloudManifestResponseBytes = 1024 * 1024 + 64;
const maxCloudObjectResponseBytes = 4 * 1024 * 1024;
const maxCloudListingResponseBytes = 4 * 1024 * 1024;
const maxCloudJsonApiResponseBytes = 6 * 1024 * 1024;

enum CloudBackendMode { bidirectional, manualBackupOnly }

enum CloudBackendWarning {
  googleDriveWeakCas,
  githubPublicRepository,
  webDavWeakCas,
  webDavUnverifiedCas,
}

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
  final List<CloudBackendWarning> warnings;

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

/// Optional backend hint for immutable object uploads. Implementations must
/// only opt in when parallel requests preserve their provider transaction.
abstract interface class ConcurrentCloudObjectUploadBackend {
  int get maxConcurrentObjectUploads;
}

/// Optional operation-scoped inventory for immutable content-addressed
/// objects. Implementations must reject duplicate/conflicting entries and may
/// report an object as existing only after validating its identity and size.
typedef CloudObjectInventoryProgressCallback =
    void Function(CloudObjectInventoryProgress progress);

class CloudObjectInventoryProgress {
  const CloudObjectInventoryProgress({
    required this.objectsCompleted,
    required this.objectsTotal,
    required this.bytesCompleted,
    required this.bytesTotal,
  });

  final int objectsCompleted;
  final int objectsTotal;
  final int bytesCompleted;
  final int bytesTotal;
}

class CloudObjectInventoryResult extends SetBase<String> {
  CloudObjectInventoryResult({
    required Set<String> existingObjectIds,
    required Map<String, String> verifiedRevisions,
  }) : existingObjectIds = Set.unmodifiable(existingObjectIds),
       verifiedRevisions = Map.unmodifiable(verifiedRevisions);

  CloudObjectInventoryResult.empty()
    : existingObjectIds = const {},
      verifiedRevisions = const {};

  final Set<String> existingObjectIds;
  final Map<String, String> verifiedRevisions;

  @override
  bool add(String value) => throw UnsupportedError('Inventory is immutable');

  @override
  bool contains(Object? element) => existingObjectIds.contains(element);

  @override
  Iterator<String> get iterator => existingObjectIds.iterator;

  @override
  int get length => existingObjectIds.length;

  @override
  String? lookup(Object? element) => existingObjectIds.lookup(element);

  @override
  bool remove(Object? value) =>
      throw UnsupportedError('Inventory is immutable');

  @override
  Set<String> toSet() => Set.of(existingObjectIds);
}

abstract interface class CloudObjectInventoryBackend {
  Future<CloudObjectInventoryResult> findExistingObjects(
    Map<String, int> expectedObjects, {
    Map<String, String> trustedRevisions = const {},
    OperationToken? token,
    CloudObjectInventoryProgressCallback? onProgress,
  });
}

/// Optional lightweight validation used while saving or restoring a WebDAV
/// connection. Implementations must not create, update, or delete remote data.
abstract interface class ReadOnlyCloudSyncBackendValidation {
  Future<void> validateConnectionReadOnly();
}

abstract interface class CloudSyncBackend {
  Future<CloudBackendCapability> testCapability();

  Future<CloudHeadRead?> readHead();

  Future<CloudObjectRead?> readObject(String objectId);

  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId);

  /// [payloadVerified] means the caller already validated [bytes] against
  /// [sha256]; providers must reuse that proof instead of hashing the payload
  /// again. Direct callers leave it false and receive backend validation.
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  });

  /// Creates a manifest once; implementations must not replace different
  /// bytes at the same snapshot id. [payloadVerified] has the same proof
  /// semantics as [putObject].
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  });

  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  });

  Future<List<String>> listSnapshotIds({int limit = 20});

  Future<void> deleteNamespace();
}
