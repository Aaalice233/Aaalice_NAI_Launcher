import 'cloud_drive_oauth_client.dart';
import 'cloud_drive_oauth_models.dart';

abstract interface class CloudDriveOAuthSessionStore {
  Future<void> write(CloudDriveOAuthSession session);

  Future<CloudDriveOAuthSession?> read(
    CloudDriveOAuthProvider provider,
    String accountId,
  );

  Future<void> delete(CloudDriveOAuthProvider provider, String accountId);
}

final class SecureCloudDriveOAuthTokenProvider
    implements CloudDriveOAuthTokenProvider {
  SecureCloudDriveOAuthTokenProvider({
    required CloudDriveOAuthSessionStore store,
    required Map<CloudDriveOAuthProvider, CloudDriveOAuthClient> clients,
    DateTime Function()? clock,
    this.refreshSkew = const Duration(minutes: 2),
  }) : _store = store,
       _clients = Map.unmodifiable(clients),
       _clock = clock ?? DateTime.now;

  final CloudDriveOAuthSessionStore _store;
  final Map<CloudDriveOAuthProvider, CloudDriveOAuthClient> _clients;
  final DateTime Function() _clock;
  final Duration refreshSkew;
  final Map<String, Future<CloudDriveOAuthSession>> _refreshes = {};
  final Map<String, int> _generations = {};

  @override
  Future<CloudDriveOAuthSession?> readSession(
    CloudDriveOAuthProvider provider,
    String accountId,
  ) => _store.read(provider, accountId);

  @override
  Future<CloudDriveOAuthSession> connect(
    CloudDriveOAuthProvider provider,
  ) async {
    final session = await _client(provider).authenticate();
    _verifyClientSession(provider, session);
    await _store.write(session);
    return session;
  }

  @override
  Future<String> accessToken(
    CloudDriveOAuthProvider provider,
    String accountId,
  ) async {
    final session = await _store.read(provider, accountId);
    if (session == null) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidGrant,
        'No OAuth session exists for this account',
      );
    }
    if (!session.isExpired(_clock(), skew: refreshSkew)) {
      return session.accessToken;
    }
    return (await _refreshOnce(session)).accessToken;
  }

  @override
  Future<void> disconnect(
    CloudDriveOAuthProvider provider,
    String accountId,
  ) async {
    final key = _sessionKey(provider, accountId);
    _generations[key] = (_generations[key] ?? 0) + 1;
    final session = await _store.read(provider, accountId);
    if (session == null) return;
    try {
      await _client(provider).disconnect(session);
    } finally {
      await _store.delete(provider, accountId);
    }
  }

  Future<CloudDriveOAuthSession> _refreshOnce(CloudDriveOAuthSession session) {
    final key = _sessionKey(session.provider, session.accountId);
    final existing = _refreshes[key];
    if (existing != null) return existing;
    final generation = _generations[key] ?? 0;
    final refresh = _refreshAndClear(key, generation, session);
    _refreshes[key] = refresh;
    return refresh;
  }

  Future<CloudDriveOAuthSession> _refreshAndClear(
    String key,
    int generation,
    CloudDriveOAuthSession session,
  ) async {
    try {
      return await _refresh(key, generation, session);
    } finally {
      _refreshes.remove(key);
    }
  }

  Future<CloudDriveOAuthSession> _refresh(
    String key,
    int generation,
    CloudDriveOAuthSession session,
  ) async {
    try {
      final refreshed = await _client(session.provider).refresh(session);
      _verifyClientSession(session.provider, refreshed);
      if (refreshed.accountId != session.accountId) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.malformedResponse,
          'Refreshed OAuth account identity changed',
        );
      }
      if ((_generations[key] ?? 0) != generation) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.invalidGrant,
          'Discarded an OAuth refresh completed after account disconnect',
        );
      }
      await _store.write(refreshed);
      return refreshed;
    } on CloudDriveOAuthException catch (error) {
      if (error.requiresReauthentication) {
        await _store.delete(session.provider, session.accountId);
      }
      rethrow;
    }
  }

  String _sessionKey(CloudDriveOAuthProvider provider, String accountId) =>
      '${provider.id}:$accountId';

  CloudDriveOAuthClient _client(CloudDriveOAuthProvider provider) {
    final client = _clients[provider];
    if (client == null) {
      throw CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.platformUnsupported,
        'No OAuth client is registered for ${provider.id}',
      );
    }
    return client;
  }

  void _verifyClientSession(
    CloudDriveOAuthProvider provider,
    CloudDriveOAuthSession session,
  ) {
    if (session.provider != provider) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'OAuth client returned the wrong provider',
      );
    }
  }
}
