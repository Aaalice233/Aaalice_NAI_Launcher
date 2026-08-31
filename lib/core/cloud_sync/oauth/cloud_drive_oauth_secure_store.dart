import '../../storage/secure_storage_service.dart';
import 'cloud_drive_oauth_models.dart';
import 'cloud_drive_oauth_token_provider.dart';

final class SecureCloudDriveOAuthSessionStore
    implements CloudDriveOAuthSessionStore {
  const SecureCloudDriveOAuthSessionStore(this._storage);

  final SecureStorageService _storage;

  @override
  Future<void> write(CloudDriveOAuthSession session) =>
      _storage.saveCloudDriveOAuthSession(
        providerId: session.provider.id,
        accountId: session.accountId,
        encodedSession: session.encodeForSecureStorage(),
      );

  @override
  Future<CloudDriveOAuthSession?> read(
    CloudDriveOAuthProvider provider,
    String accountId,
  ) async {
    final encoded = await _storage.getCloudDriveOAuthSession(
      providerId: provider.id,
      accountId: accountId,
    );
    if (encoded == null) return null;
    final session = CloudDriveOAuthSession.decodeFromSecureStorage(encoded);
    if (session.provider != provider || session.accountId != accountId) {
      throw const FormatException('OAuth session storage identity mismatch');
    }
    return session;
  }

  @override
  Future<void> delete(CloudDriveOAuthProvider provider, String accountId) =>
      _storage.deleteCloudDriveOAuthSession(
        providerId: provider.id,
        accountId: accountId,
      );
}
