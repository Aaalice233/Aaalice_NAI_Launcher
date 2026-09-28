import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/models.dart';

String? cloudSyncSnapshotId(CloudHeadRead? head) =>
    head == null ? null : SnapshotHead.decode(head.bytes).snapshotId;
