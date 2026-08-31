import 'backend/cloud_sync_backend.dart';
import 'oauth/cloud_drive_oauth_client.dart';
import 'oauth/cloud_drive_oauth_config.dart';
import 'oauth/cloud_drive_oauth_models.dart';

/// Authenticates a cloud-drive destination and creates its storage adapter.
///
/// Sync policy and snapshot semantics deliberately remain outside this layer;
/// Google Drive and OneDrive only provide identity, tokens, capability claims,
/// and file operations to the shared cloud-sync engine.
abstract interface class CloudDriveProvider {
  CloudDriveOAuthProvider get id;

  CloudDriveOAuthConfigDiagnostic diagnose();

  Future<CloudDriveOAuthSession> connect();

  CloudSyncBackend createBackend({
    required String accountId,
    required String namespace,
  });

  Future<void> disconnect(String accountId);
}

typedef CloudDriveBackendBuilder =
    CloudSyncBackend Function({
      required Future<String> Function() accessTokenProvider,
      required String namespace,
    });

final class OAuthCloudDriveProvider implements CloudDriveProvider {
  OAuthCloudDriveProvider({
    required this.id,
    required CloudDriveOAuthConfig config,
    required CloudDriveOAuthTokenProvider tokens,
    required CloudDriveBackendBuilder backendBuilder,
  }) : _config = config,
       _tokens = tokens,
       _backendBuilder = backendBuilder;

  @override
  final CloudDriveOAuthProvider id;
  final CloudDriveOAuthConfig _config;
  final CloudDriveOAuthTokenProvider _tokens;
  final CloudDriveBackendBuilder _backendBuilder;

  @override
  CloudDriveOAuthConfigDiagnostic diagnose() => _config.diagnose(id);

  @override
  Future<CloudDriveOAuthSession> connect() async {
    final diagnostic = diagnose();
    if (!diagnostic.isConfigured) {
      throw CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.notConfigured,
        diagnostic.reasons.join('\n'),
      );
    }
    final session = await _tokens.connect(id);
    if (session.provider != id) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'OAuth provider identity changed during connection',
      );
    }
    return session;
  }

  @override
  CloudSyncBackend createBackend({
    required String accountId,
    required String namespace,
  }) {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'must not be empty');
    }
    return _backendBuilder(
      accessTokenProvider: () => _tokens.accessToken(id, accountId),
      namespace: namespace,
    );
  }

  @override
  Future<void> disconnect(String accountId) =>
      _tokens.disconnect(id, accountId);
}

final class CloudDriveProviderRegistry {
  CloudDriveProviderRegistry(Iterable<CloudDriveProvider> providers)
    : _providers = Map.unmodifiable({
        for (final provider in providers) provider.id: provider,
      }) {
    if (_providers.length != providers.length) {
      throw ArgumentError('Duplicate cloud-drive provider');
    }
  }

  final Map<CloudDriveOAuthProvider, CloudDriveProvider> _providers;

  CloudDriveProvider require(CloudDriveOAuthProvider id) {
    final provider = _providers[id];
    if (provider == null) {
      throw CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.platformUnsupported,
        'Cloud-drive provider ${id.id} is unavailable on this platform',
      );
    }
    return provider;
  }
}
