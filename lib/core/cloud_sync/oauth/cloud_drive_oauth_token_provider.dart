import 'dart:async';

import '../../utils/app_logger.dart';
import 'cloud_drive_oauth_client.dart';
import 'cloud_drive_oauth_config.dart';
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
    Map<CloudDriveOAuthProvider, CloudDriveOAuthConfigDiagnostic> diagnostics =
        const {},
    DateTime Function()? clock,
    this.refreshSkew = const Duration(minutes: 2),
  }) : _store = store,
       _clients = Map.unmodifiable(clients),
       _diagnostics = Map.unmodifiable(diagnostics),
       _clock = clock ?? DateTime.now;

  final CloudDriveOAuthSessionStore _store;
  final Map<CloudDriveOAuthProvider, CloudDriveOAuthClient> _clients;
  final Map<CloudDriveOAuthProvider, CloudDriveOAuthConfigDiagnostic>
  _diagnostics;
  final DateTime Function() _clock;
  final Duration refreshSkew;
  final Map<String, Future<CloudDriveOAuthSession>> _refreshes = {};
  final Map<String, int> _generations = {};
  final Map<CloudDriveOAuthProvider, Completer<void>> _connectCancellations =
      {};
  final Map<CloudDriveOAuthProvider, Future<CloudDriveOAuthSession>>
  _authentications = {};

  @override
  Future<CloudDriveOAuthSession?> readSession(
    CloudDriveOAuthProvider provider,
    String accountId,
  ) => _store.read(provider, accountId);

  @override
  Future<CloudDriveOAuthSession> connect(
    CloudDriveOAuthProvider provider,
  ) async {
    if (_authentications.isNotEmpty || _connectCancellations.isNotEmpty) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.authorizationInProgress,
        'Another OAuth authorization is still finishing',
      );
    }
    final stopwatch = Stopwatch()..start();
    var stage = 'authenticate';
    final cancellation = Completer<void>();
    _connectCancellations[provider] = cancellation;
    AppLogger.i(
      'OAuth session connection started: provider=${provider.id}',
      'CloudDriveOAuth',
    );
    try {
      final client = _client(provider);
      final authentication = client.authenticate();
      _authentications[provider] = authentication;
      unawaited(
        authentication.then<void>(
          (_) => _clearAuthentication(provider, authentication),
          onError: (Object _, StackTrace __) =>
              _clearAuthentication(provider, authentication),
        ),
      );
      final session = await Future.any<CloudDriveOAuthSession>([
        authentication,
        cancellation.future.then<CloudDriveOAuthSession>(
          (_) => throw const CloudDriveOAuthException(
            CloudDriveOAuthFailureCode.cancelled,
            'OAuth authorization was cancelled',
          ),
        ),
      ]);
      _verifyClientSession(provider, session);
      if (cancellation.isCompleted) _throwAuthorizationCancelled();
      final previousSession = await _store.read(provider, session.accountId);
      if (cancellation.isCompleted) _throwAuthorizationCancelled();
      final key = _sessionKey(provider, session.accountId);
      final generation = (_generations[key] ?? 0) + 1;
      _generations[key] = generation;
      stage = 'persist_secure_session';
      AppLogger.i(
        'Persisting OAuth session in secure storage: provider=${provider.id}',
        'CloudDriveOAuth',
      );
      await _store.write(session);
      if (cancellation.isCompleted) {
        stage = 'restore_session_after_cancellation';
        await _restoreSessionAfterCancellation(
          session,
          previousSession,
          generation,
        );
        _throwAuthorizationCancelled();
      }
      AppLogger.i(
        'OAuth session persisted: provider=${provider.id}, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
        'CloudDriveOAuth',
      );
      return session;
    } catch (error, stackTrace) {
      AppLogger.e(
        'OAuth session connection failed: provider=${provider.id}, '
            'stage=$stage, elapsedMs=${stopwatch.elapsedMilliseconds}',
        error,
        stackTrace,
        'CloudDriveOAuth',
      );
      rethrow;
    } finally {
      if (identical(_connectCancellations[provider], cancellation)) {
        _connectCancellations.remove(provider);
      }
    }
  }

  @override
  Future<void> cancelConnect(CloudDriveOAuthProvider provider) async {
    final cancellation = _connectCancellations[provider];
    if (cancellation == null) return;
    if (!cancellation.isCompleted) cancellation.complete();
    final client = _client(provider);
    if (client is CloudDriveOAuthAuthenticationCanceller) {
      await (client as CloudDriveOAuthAuthenticationCanceller)
          .cancelAuthentication();
      final authentication = _authentications[provider];
      if (authentication != null) {
        try {
          await authentication;
        } on Object {
          // The connect Future owns and reports the cancellation result.
        }
      }
    }
  }

  void _clearAuthentication(
    CloudDriveOAuthProvider provider,
    Future<CloudDriveOAuthSession> authentication,
  ) {
    if (identical(_authentications[provider], authentication)) {
      _authentications.remove(provider);
    }
  }

  Future<void> _restoreSessionAfterCancellation(
    CloudDriveOAuthSession cancelled,
    CloudDriveOAuthSession? previous,
    int generation,
  ) {
    final key = _sessionKey(cancelled.provider, cancelled.accountId);
    if ((_generations[key] ?? 0) != generation) {
      return _store.delete(cancelled.provider, cancelled.accountId);
    }
    return previous == null
        ? _store.delete(cancelled.provider, cancelled.accountId)
        : _store.write(previous);
  }

  Never _throwAuthorizationCancelled() => throw const CloudDriveOAuthException(
    CloudDriveOAuthFailureCode.cancelled,
    'OAuth authorization was cancelled',
  );

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
    final generation = (_generations[key] ?? 0) + 1;
    _generations[key] = generation;
    final session = await _store.read(provider, accountId);
    if (session == null) return;
    try {
      await _client(provider).disconnect(session);
    } finally {
      if ((_generations[key] ?? 0) == generation) {
        await _store.delete(provider, accountId);
      }
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
      if (error.requiresReauthentication &&
          (_generations[key] ?? 0) == generation) {
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
      final diagnostic = _diagnostics[provider];
      throw CloudDriveOAuthException(
        diagnostic?.platform == CloudDriveOAuthPlatform.unsupported
            ? CloudDriveOAuthFailureCode.platformUnsupported
            : CloudDriveOAuthFailureCode.notConfigured,
        diagnostic == null
            ? 'No OAuth client is registered for ${provider.id}'
            : diagnostic.reasons.join('\n'),
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
