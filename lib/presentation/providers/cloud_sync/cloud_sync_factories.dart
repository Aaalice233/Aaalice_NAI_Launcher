import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/cloud_sync/object_codec.dart';
import 'cloud_sync_ui_provider.dart';

typedef CloudBackendFactory =
    CloudSyncBackend Function(CloudSyncConnectionDraft draft);

typedef CloudCoordinatorFactory =
    Future<SyncCoordinator> Function(
      CloudSyncBackend backend,
      CloudObjectCodec codec,
      Set<CloudSyncDataKind> scope,
      CloudSyncContentSelection contentSelection,
      CloudSyncConnectionDraft connection,
    );
