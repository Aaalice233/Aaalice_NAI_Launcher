import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_client.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_config.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_models.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_token_provider.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/loopback_oauth_client.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/oauth_http_transport.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/oauth_pkce.dart';

void main() {
  final now = DateTime.utc(2026, 3, 1, 12);

  group('CloudDriveOAuthSession', () {
    test('uses strict versioned JSON and redacts tokens from toString', () {
      final session = _session(
        now: now,
        accessToken: 'access-secret',
        refreshToken: 'refresh-secret',
      );

      final decoded = CloudDriveOAuthSession.decodeFromSecureStorage(
        session.encodeForSecureStorage(),
      );
      expect(decoded.accountId, session.accountId);
      expect(decoded.accessToken, 'access-secret');
      expect(session.toString(), isNot(contains('access-secret')));
      expect(session.toString(), isNot(contains('refresh-secret')));

      final json =
          jsonDecode(session.encodeForSecureStorage()) as Map<String, dynamic>
            ..['unexpected'] = true;
      expect(
        () => CloudDriveOAuthSession.fromJson(json),
        throwsFormatException,
      );
    });

    test('rejects non-UTC expiry and empty credentials', () {
      final json =
          jsonDecode(_session(now: now).encodeForSecureStorage())
                as Map<String, dynamic>
            ..['expiresAt'] = '2026-03-01T13:00:00';
      expect(
        () => CloudDriveOAuthSession.fromJson(json),
        throwsFormatException,
      );
      expect(
        () => CloudDriveOAuthSession(
          provider: CloudDriveOAuthProvider.googleDrive,
          accountId: 'account',
          displayIdentifier: 'user@example.test',
          accessToken: '',
          refreshToken: null,
          expiresAt: now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CloudDriveOAuthConfig', () {
    test('reports each missing dart define with an actionable reason', () {
      final config = CloudDriveOAuthConfig.forTesting(
        platform: CloudDriveOAuthPlatform.windows,
      );

      final diagnostic = config.diagnose(CloudDriveOAuthProvider.googleDrive);

      expect(diagnostic.isConfigured, isFalse);
      expect(
        diagnostic.reasons.join(' '),
        contains('GOOGLE_DRIVE_WINDOWS_CLIENT_ID'),
      );
      expect(
        diagnostic.reasons.join(' '),
        contains('GOOGLE_DRIVE_WINDOWS_REDIRECT_URI'),
      );
    });

    test('keeps scopes fixed and ignores credential-like ordinary values', () {
      final config = _windowsConfig(
        CloudDriveOAuthProvider.oneDrive,
        extras: {
          'ONEDRIVE_WINDOWS_SCOPE': 'User.ReadWrite.All',
          'ONEDRIVE_WINDOWS_ACCESS_TOKEN': 'must-not-appear',
        },
      ).requireProvider(CloudDriveOAuthProvider.oneDrive);

      expect(config.scopes, contains('Files.ReadWrite.AppFolder'));
      expect(config.scopes, isNot(contains('User.ReadWrite.All')));
      expect(config.toString(), isNot(contains('must-not-appear')));
    });

    test(
      'Google Android SDK configuration does not require a redirect define',
      () {
        final config = CloudDriveOAuthConfig.forTesting(
          platform: CloudDriveOAuthPlatform.android,
          values: const {'GOOGLE_DRIVE_ANDROID_CLIENT_ID': 'web-client-id'},
        );

        final diagnostic = config.diagnose(CloudDriveOAuthProvider.googleDrive);
        expect(diagnostic.isConfigured, isTrue);
        expect(
          config.requireProvider(CloudDriveOAuthProvider.googleDrive).scopes,
          contains(CloudDriveOAuthConfig.googleDriveScope),
        );
      },
    );

    test('OneDrive mobile redirect matches the registered callback scheme', () {
      final config = CloudDriveOAuthConfig.forTesting(
        platform: CloudDriveOAuthPlatform.android,
        values: const {
          'ONEDRIVE_ANDROID_CLIENT_ID': 'client-id',
          'ONEDRIVE_ANDROID_REDIRECT_URI':
              'com.aaalice.nailauncher.oauth:/oauth2redirect/microsoft',
        },
      );

      expect(
        config.diagnose(CloudDriveOAuthProvider.oneDrive).isConfigured,
        isTrue,
      );
    });

    test('rejects a non-loopback Windows redirect', () {
      final config = CloudDriveOAuthConfig.forTesting(
        platform: CloudDriveOAuthPlatform.windows,
        values: {
          'GOOGLE_DRIVE_WINDOWS_CLIENT_ID': 'client-id',
          'GOOGLE_DRIVE_WINDOWS_REDIRECT_URI': 'http://localhost:8080',
        },
      );
      expect(
        config.diagnose(CloudDriveOAuthProvider.googleDrive).reasons.single,
        contains('http://127.0.0.1'),
      );
    });
  });

  group('PKCE', () {
    test('uses RFC 7636 S256 and unpredictable state/nonce material', () {
      expect(
        OAuthPkce.challengeForVerifier(
          'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
        ),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
      final request = OAuthPkce(random: _SequenceRandom()).create();
      expect(request.codeVerifier.length, greaterThanOrEqualTo(43));
      expect(request.state, isNot(request.nonce));
      expect(request.codeChallenge, isNot(request.codeVerifier));
    });

    test('constant-time comparison has exact semantics', () {
      expect(OAuthPkce.secureEquals('state', 'state'), isTrue);
      expect(OAuthPkce.secureEquals('state', 'State'), isFalse);
      expect(OAuthPkce.secureEquals('state', 'state-extra'), isFalse);
    });
  });

  group('SecureCloudDriveOAuthTokenProvider', () {
    test(
      'refreshes expired credentials and persists refresh rotation',
      () async {
        final store = _MemorySessionStore();
        final original = _session(
          now: now,
          expiresAt: now.subtract(const Duration(seconds: 1)),
          refreshToken: 'old-refresh',
        );
        await store.write(original);
        final client = _FakeClient(
          CloudDriveOAuthProvider.googleDrive,
          refreshResult: original.copyWith(
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
        );
        final provider = _provider(store, client, now);

        expect(
          await provider.accessToken(original.provider, original.accountId),
          'new-access',
        );
        expect(
          (await store.read(
            original.provider,
            original.accountId,
          ))!.refreshToken,
          'new-refresh',
        );
        expect(client.refreshCalls, 1);
      },
    );

    test('clears only the failed account after invalid_grant', () async {
      final store = _MemorySessionStore();
      final failed = _session(
        now: now,
        accountId: 'failed',
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      final other = _session(now: now, accountId: 'other');
      await store.write(failed);
      await store.write(other);
      final client = _FakeClient(
        failed.provider,
        refreshError: const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.invalidGrant,
          'invalid grant',
          oauthError: 'invalid_grant',
        ),
      );
      final provider = _provider(store, client, now);

      await expectLater(
        provider.accessToken(failed.provider, failed.accountId),
        throwsA(
          isA<CloudDriveOAuthException>().having(
            (error) => error.requiresReauthentication,
            'requiresReauthentication',
            isTrue,
          ),
        ),
      );
      expect(await store.read(failed.provider, failed.accountId), isNull);
      expect(await store.read(other.provider, other.accountId), isNotNull);
    });

    test('isolates accounts and skips refresh for a valid expiry', () async {
      final store = _MemorySessionStore();
      final first = _session(
        now: now,
        accountId: 'first',
        accessToken: 'first-token',
      );
      final second = _session(
        now: now,
        accountId: 'second',
        accessToken: 'second-token',
      );
      await store.write(first);
      await store.write(second);
      final client = _FakeClient(first.provider, refreshResult: first);
      final provider = _provider(store, client, now);

      expect(
        await provider.accessToken(first.provider, first.accountId),
        'first-token',
      );
      expect(
        await provider.accessToken(second.provider, second.accountId),
        'second-token',
      );
      expect(client.refreshCalls, 0);
    });

    test('discards a refresh completed after disconnect', () async {
      final store = _MemorySessionStore();
      final expired = _session(
        now: now,
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      await store.write(expired);
      final client = _DelayedClient(expired.provider);
      final provider = SecureCloudDriveOAuthTokenProvider(
        store: store,
        clients: {expired.provider: client},
        clock: () => now,
      );

      final access = provider.accessToken(expired.provider, expired.accountId);
      await client.started.future;
      await provider.disconnect(expired.provider, expired.accountId);
      client.result.complete(
        expired.copyWith(
          accessToken: 'stale-access',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );

      await expectLater(
        access,
        throwsA(
          isA<CloudDriveOAuthException>().having(
            (error) => error.requiresReauthentication,
            'requiresReauthentication',
            isTrue,
          ),
        ),
      );
      expect(await store.read(expired.provider, expired.accountId), isNull);
    });

    test(
      'disconnect invokes provider revocation then clears locally',
      () async {
        final store = _MemorySessionStore();
        final session = _session(now: now);
        await store.write(session);
        final client = _FakeClient(session.provider, refreshResult: session);
        final provider = _provider(store, client, now);

        await provider.disconnect(session.provider, session.accountId);

        expect(client.disconnectCalls, 1);
        expect(await store.read(session.provider, session.accountId), isNull);
      },
    );
  });

  group('Windows loopback flow', () {
    test(
      'builds system-browser authorization with PKCE, state and fixed scope',
      () {
        final config = _windowsConfig(
          CloudDriveOAuthProvider.googleDrive,
        ).requireProvider(CloudDriveOAuthProvider.googleDrive);
        final client = LoopbackCloudDriveOAuthClient(
          config: config,
          transport: _FakeTransport(),
        );
        final request = OAuthPkce(random: _SequenceRandom()).create();

        final uri = client.buildAuthorizationUri(
          redirectUri: Uri.parse('http://127.0.0.1:43123/oauth2/callback'),
          request: request,
        );

        expect(uri.queryParameters['state'], request.state);
        expect(uri.queryParameters['nonce'], request.nonce);
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        expect(uri.queryParameters['code_challenge'], request.codeChallenge);
        expect(
          uri.queryParameters['scope'],
          contains(CloudDriveOAuthConfig.googleDriveScope),
        );
        expect(uri.queryParameters, isNot(contains('client_secret')));
      },
    );

    test('exchanges one callback and validates nonce/audience', () async {
      final browser = _FakeBrowser();
      final receiver = _FakeCallbackReceiver();
      final transport = _FakeTransport(
        tokenResponse: () {
          final query = browser.opened!.queryParameters;
          return {
            'access_token': 'access-secret',
            'refresh_token': 'refresh-secret',
            'expires_in': 3600,
            'token_type': 'Bearer',
            'id_token': _jwt({
              'sub': 'stable-subject',
              'email': 'user@example.test',
              'iss': 'https://accounts.google.com',
              'aud': 'client-id',
              'nonce': query['nonce'],
              'exp':
                  now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                  1000,
            }),
          };
        },
      );
      final client = LoopbackCloudDriveOAuthClient(
        config: _windowsConfig(
          CloudDriveOAuthProvider.googleDrive,
        ).requireProvider(CloudDriveOAuthProvider.googleDrive),
        transport: transport,
        browserLauncher: browser,
        callbackReceiverFactory: _FakeCallbackFactory(receiver),
        pkce: OAuthPkce(random: _SequenceRandom()),
        clock: () => now,
      );

      final session = await client.authenticate();

      expect(session.accountId, 'stable-subject');
      expect(session.displayIdentifier, 'user@example.test');
      expect(receiver.waitCalls, 1);
      expect(receiver.closed, isTrue);
      expect(transport.lastForm, containsPair('code_verifier', isNotEmpty));
      expect(transport.lastForm, isNot(contains('client_secret')));
    });

    test('preserves refresh token when provider does not rotate it', () async {
      final transport = _FakeTransport(
        tokenResponse: () => {
          'access_token': 'new-access',
          'expires_in': 3600,
          'token_type': 'Bearer',
        },
      );
      final client = LoopbackCloudDriveOAuthClient(
        config: _windowsConfig(
          CloudDriveOAuthProvider.oneDrive,
        ).requireProvider(CloudDriveOAuthProvider.oneDrive),
        transport: transport,
        clock: () => now,
      );

      final refreshed = await client.refresh(
        _session(
          now: now,
          provider: CloudDriveOAuthProvider.oneDrive,
          refreshToken: 'existing-refresh',
        ),
      );

      expect(refreshed.refreshToken, 'existing-refresh');
      expect(refreshed.accessToken, 'new-access');
    });
  });
}

CloudDriveOAuthSession _session({
  required DateTime now,
  CloudDriveOAuthProvider provider = CloudDriveOAuthProvider.googleDrive,
  String accountId = 'account-id',
  String accessToken = 'access-token',
  String? refreshToken = 'refresh-token',
  DateTime? expiresAt,
}) => CloudDriveOAuthSession(
  provider: provider,
  accountId: accountId,
  displayIdentifier: '$accountId@example.test',
  accessToken: accessToken,
  refreshToken: refreshToken,
  expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
);

CloudDriveOAuthConfig _windowsConfig(
  CloudDriveOAuthProvider provider, {
  Map<String, String> extras = const {},
}) {
  final prefix = provider == CloudDriveOAuthProvider.googleDrive
      ? 'GOOGLE_DRIVE'
      : 'ONEDRIVE';
  return CloudDriveOAuthConfig.forTesting(
    platform: CloudDriveOAuthPlatform.windows,
    values: {
      '${prefix}_WINDOWS_CLIENT_ID': 'client-id',
      '${prefix}_WINDOWS_REDIRECT_URI': 'http://127.0.0.1',
      ...extras,
    },
  );
}

SecureCloudDriveOAuthTokenProvider _provider(
  _MemorySessionStore store,
  _FakeClient client,
  DateTime now,
) => SecureCloudDriveOAuthTokenProvider(
  store: store,
  clients: {client.provider: client},
  clock: () => now,
);

String _jwt(Map<String, Object?> claims) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'RS256', 'typ': 'JWT'})}.${encode(claims)}.signature';
}

final class _SequenceRandom implements OAuthRandomSource {
  var _seed = 0;

  @override
  Uint8List bytes(int length) => Uint8List.fromList(
    List.generate(length, (index) => (_seed++ + index) % 256),
  );
}

final class _MemorySessionStore implements CloudDriveOAuthSessionStore {
  final _sessions = <String, CloudDriveOAuthSession>{};

  String _key(CloudDriveOAuthProvider provider, String accountId) =>
      '${provider.id}:$accountId';

  @override
  Future<void> delete(
    CloudDriveOAuthProvider provider,
    String accountId,
  ) async {
    _sessions.remove(_key(provider, accountId));
  }

  @override
  Future<CloudDriveOAuthSession?> read(
    CloudDriveOAuthProvider provider,
    String accountId,
  ) async => _sessions[_key(provider, accountId)];

  @override
  Future<void> write(CloudDriveOAuthSession session) async {
    _sessions[_key(session.provider, session.accountId)] = session;
  }
}

final class _FakeClient implements CloudDriveOAuthClient {
  _FakeClient(this.provider, {this.refreshResult, this.refreshError});

  @override
  final CloudDriveOAuthProvider provider;
  final CloudDriveOAuthSession? refreshResult;
  final Object? refreshError;
  var refreshCalls = 0;
  var disconnectCalls = 0;

  @override
  Future<CloudDriveOAuthSession> authenticate() async => refreshResult!;

  @override
  Future<void> disconnect(CloudDriveOAuthSession session) async {
    disconnectCalls++;
  }

  @override
  Future<CloudDriveOAuthSession> refresh(CloudDriveOAuthSession session) async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return refreshResult!;
  }
}

final class _DelayedClient implements CloudDriveOAuthClient {
  _DelayedClient(this.provider);

  @override
  final CloudDriveOAuthProvider provider;
  final started = Completer<void>();
  final result = Completer<CloudDriveOAuthSession>();

  @override
  Future<CloudDriveOAuthSession> authenticate() => result.future;

  @override
  Future<void> disconnect(CloudDriveOAuthSession session) async {}

  @override
  Future<CloudDriveOAuthSession> refresh(CloudDriveOAuthSession session) {
    started.complete();
    return result.future;
  }
}

final class _FakeBrowser implements OAuthBrowserLauncher {
  Uri? opened;

  @override
  Future<bool> open(Uri uri) async {
    opened = uri;
    return true;
  }
}

final class _FakeCallbackFactory implements OAuthCallbackReceiverFactory {
  const _FakeCallbackFactory(this.receiver);

  final OAuthCallbackReceiver receiver;

  @override
  Future<OAuthCallbackReceiver> start(Uri configuredRedirectUri) async =>
      receiver;
}

final class _FakeCallbackReceiver implements OAuthCallbackReceiver {
  @override
  final redirectUri = Uri.parse('http://127.0.0.1:43123/oauth2/callback');
  var waitCalls = 0;
  var closed = false;

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<OAuthAuthorizationCallback> waitForCallback({
    required String expectedState,
    required Duration timeout,
  }) async {
    waitCalls++;
    expect(expectedState, isNotEmpty);
    return const OAuthAuthorizationCallback(code: 'authorization-code');
  }
}

final class _FakeTransport implements OAuthHttpTransport {
  _FakeTransport({this.tokenResponse});

  final Map<String, dynamic> Function()? tokenResponse;
  Map<String, String> lastForm = const {};

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async => const {};

  @override
  Future<Map<String, dynamic>> postForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String> headers = const {},
  }) async {
    lastForm = fields;
    return tokenResponse?.call() ?? const {};
  }

  @override
  Future<void> postFormNoContent(Uri uri, Map<String, String> fields) async {
    lastForm = fields;
  }
}
