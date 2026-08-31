import 'cloud_drive_oauth_models.dart';

abstract interface class CloudDriveOAuthClient {
  CloudDriveOAuthProvider get provider;

  Future<CloudDriveOAuthSession> authenticate();

  Future<CloudDriveOAuthSession> refresh(CloudDriveOAuthSession session);

  /// Revokes Google authorization where supported. Microsoft disconnect only
  /// clears local credentials and deliberately does not request the privileged
  /// User.RevokeSessions.All permission.
  Future<void> disconnect(CloudDriveOAuthSession session);
}

abstract interface class CloudDriveOAuthTokenProvider {
  Future<CloudDriveOAuthSession?> readSession(
    CloudDriveOAuthProvider provider,
    String accountId,
  );

  Future<CloudDriveOAuthSession> connect(CloudDriveOAuthProvider provider);

  Future<String> accessToken(
    CloudDriveOAuthProvider provider,
    String accountId,
  );

  Future<void> disconnect(CloudDriveOAuthProvider provider, String accountId);
}

enum CloudDriveOAuthFailureCode {
  notConfigured,
  cancelled,
  timedOut,
  invalidCallback,
  authorizationFailed,
  invalidGrant,
  malformedResponse,
  platformUnsupported,
}

final class CloudDriveOAuthException implements Exception {
  const CloudDriveOAuthException(this.code, this.message, {this.oauthError});

  final CloudDriveOAuthFailureCode code;
  final String message;
  final String? oauthError;

  bool get requiresReauthentication =>
      code == CloudDriveOAuthFailureCode.invalidGrant;

  @override
  String toString() => 'CloudDriveOAuthException($code): $message';
}
