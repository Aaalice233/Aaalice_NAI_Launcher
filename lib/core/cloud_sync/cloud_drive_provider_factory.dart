import 'backend/google_drive_cloud_sync_backend.dart';
import 'backend/onedrive_cloud_sync_backend.dart';
import 'cloud_drive_provider.dart';
import 'oauth/cloud_drive_oauth_factory.dart';
import 'oauth/cloud_drive_oauth_models.dart';

CloudDriveProviderRegistry createCloudDriveProviderRegistry(
  CloudDriveOAuthRuntime runtime,
) => CloudDriveProviderRegistry([
  OAuthCloudDriveProvider(
    id: CloudDriveOAuthProvider.googleDrive,
    config: runtime.config,
    tokens: runtime.tokens,
    backendBuilder: ({required accessTokenProvider, required namespace}) =>
        GoogleDriveCloudSyncBackend(
          accessTokenProvider: accessTokenProvider,
          namespace: namespace,
        ),
  ),
  OAuthCloudDriveProvider(
    id: CloudDriveOAuthProvider.oneDrive,
    config: runtime.config,
    tokens: runtime.tokens,
    backendBuilder: ({required accessTokenProvider, required namespace}) =>
        OneDriveCloudSyncBackend(
          accessTokenProvider: accessTokenProvider,
          namespace: namespace,
        ),
  ),
]);
