import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/models.dart';
import 'cloud_sync_ui_provider.dart';

String? cloudSyncSnapshotId(CloudHeadRead? head) =>
    head == null ? null : SnapshotHead.decode(head.bytes).snapshotId;

bool shouldRunLifecycleSync(
  bool synchronize,
  CloudSyncCapabilityMode mode,
  String? knownRevision,
  String? currentRevision,
  bool hasPendingJournal,
) =>
    synchronize &&
    mode == CloudSyncCapabilityMode.bidirectional &&
    (hasPendingJournal || currentRevision != knownRevision);
