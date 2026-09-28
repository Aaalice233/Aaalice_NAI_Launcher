import '../../../core/cloud_sync/operation.dart';
import 'cloud_sync_ui_provider.dart';

CloudSyncProgressView mapCloudSyncProgress(SyncProgress progress) =>
    CloudSyncProgressView(
      stage: progress.phase.name,
      objectName: progress.objectId ?? '',
      completedBytes: progress.bytesCompleted,
      totalBytes: progress.bytesTotal,
      completedObjects: progress.objectsCompleted,
      totalObjects: progress.objectsTotal,
      reusedObjects: progress.objectsReused,
    );
