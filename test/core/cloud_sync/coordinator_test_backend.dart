import 'dart:typed_data';

import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';

class CoordinatorTestBackend implements CloudSyncBackend {
  final Map<String, CloudObjectRead> objects = {};
  final List<String> events = [];
  CloudHeadRead? head;
  int revision = 0;
  bool loseFirstObjectResponse = false;
  bool loseHeadResponse = false;
  OperationToken? cancelAfterHeadToken;
  final Map<String, List<Uint8List>> putAttempts = {};

  @override
  Future<CloudObjectRead?> readObject(String objectId) async =>
      objects[objectId];
  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) async =>
      objects['snapshot.$snapshotId'];
  @override
  Future<CloudHeadRead?> readHead() async => head;
  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
  }) async {
    events.add(objectId);
    putAttempts.putIfAbsent(objectId, () => []).add(Uint8List.fromList(bytes));
    final existing = objects[objectId];
    if (existing != null) return CloudCommitResult(revision: existing.revision);
    final value = CloudObjectRead(
      bytes: Uint8List.fromList(bytes),
      revision: 'r${++revision}',
    );
    objects[objectId] = value;
    if (loseFirstObjectResponse && !objectId.startsWith('snapshot.')) {
      loseFirstObjectResponse = false;
      throw const CloudBackendException(
        CloudBackendErrorKind.network,
        'simulated response loss',
      );
    }
    return CloudCommitResult(revision: value.revision);
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
  }) => putObject('snapshot.$snapshotId', bytes, sha256: sha256);

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    if (expectedRevision != head?.revision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'CAS failed',
      );
    }
    events.add('head');
    head = CloudHeadRead(
      bytes: Uint8List.fromList(bytes),
      revision: 'r${++revision}',
    );
    cancelAfterHeadToken?.cancel();
    cancelAfterHeadToken = null;
    if (loseHeadResponse) {
      loseHeadResponse = false;
      throw const CloudBackendException(
        CloudBackendErrorKind.network,
        'simulated HEAD response loss',
      );
    }
    return CloudCommitResult(revision: head!.revision);
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async => objects.keys
      .where((key) => key.startsWith('snapshot.'))
      .map((key) => key.substring('snapshot.'.length))
      .take(limit)
      .toList();
  @override
  Future<CloudBackendCapability> testCapability() async =>
      const CloudBackendCapability(
        mode: CloudBackendMode.bidirectional,
        message: 'ok',
      );
  @override
  Future<void> deleteNamespace() async {
    objects.clear();
    head = null;
  }
}
