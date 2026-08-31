import '../../storage/secure_storage_service.dart';
import 'cloud_drive_oauth_client.dart';
import 'cloud_drive_oauth_config.dart';
import 'cloud_drive_oauth_models.dart';
import 'cloud_drive_oauth_secure_store.dart';
import 'cloud_drive_oauth_token_provider.dart';
import 'loopback_oauth_client.dart';
import 'mobile_oauth_clients.dart';
import 'oauth_http_transport.dart';

final class CloudDriveOAuthRuntime {
  const CloudDriveOAuthRuntime({required this.config, required this.tokens});

  final CloudDriveOAuthConfig config;
  final CloudDriveOAuthTokenProvider tokens;
}

CloudDriveOAuthRuntime createCloudDriveOAuthRuntime(
  SecureStorageService secureStorage, {
  CloudDriveOAuthConfig? config,
}) {
  final resolved = config ?? CloudDriveOAuthConfig.fromDartDefines();
  final clients = <CloudDriveOAuthProvider, CloudDriveOAuthClient>{};
  for (final provider in CloudDriveOAuthProvider.values) {
    if (!resolved.diagnose(provider).isConfigured) continue;
    final providerConfig = resolved.requireProvider(provider);
    clients[provider] = switch (resolved.platform) {
      CloudDriveOAuthPlatform.windows => LoopbackCloudDriveOAuthClient(
        config: providerConfig,
        transport: DioOAuthHttpTransport(),
      ),
      CloudDriveOAuthPlatform.android =>
        provider == CloudDriveOAuthProvider.googleDrive
            ? GoogleSignInAndroidCloudDriveOAuthClient(config: providerConfig)
            : AppAuthOneDriveOAuthClient(config: providerConfig),
      CloudDriveOAuthPlatform.macos =>
        provider == CloudDriveOAuthProvider.googleDrive
            ? AppAuthGoogleDriveOAuthClient(config: providerConfig)
            : AppAuthOneDriveOAuthClient(config: providerConfig),
      CloudDriveOAuthPlatform.unsupported => throw StateError(
        'OAuth runtime cannot be created for an unsupported platform',
      ),
    };
  }
  return CloudDriveOAuthRuntime(
    config: resolved,
    tokens: SecureCloudDriveOAuthTokenProvider(
      store: SecureCloudDriveOAuthSessionStore(secureStorage),
      clients: clients,
    ),
  );
}
