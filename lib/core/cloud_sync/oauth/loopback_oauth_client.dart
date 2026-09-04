import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_logger.dart';
import 'cloud_drive_oauth_client.dart';
import 'cloud_drive_oauth_config.dart';
import 'cloud_drive_oauth_models.dart';
import 'oauth_http_transport.dart';
import 'oauth_pkce.dart';

abstract interface class OAuthBrowserLauncher {
  Future<bool> open(Uri uri);
}

final class SystemOAuthBrowserLauncher implements OAuthBrowserLauncher {
  const SystemOAuthBrowserLauncher();

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

final class OAuthAuthorizationCallback {
  const OAuthAuthorizationCallback({required this.code});

  final String code;
}

final class OAuthCallbackValidator {
  const OAuthCallbackValidator._();

  static OAuthAuthorizationCallback validate(
    Uri uri, {
    required String expectedState,
  }) {
    if (uri.path != '/oauth2/callback') {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidCallback,
        'OAuth callback path validation failed',
      );
    }
    final returnedState = uri.queryParameters['state'];
    if (returnedState == null ||
        !OAuthPkce.secureEquals(expectedState, returnedState)) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidCallback,
        'OAuth callback state validation failed',
      );
    }
    final oauthError = uri.queryParameters['error'];
    if (oauthError != null) {
      throw CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.authorizationFailed,
        'OAuth authorization was not completed',
        oauthError: oauthError,
      );
    }
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidCallback,
        'OAuth callback did not contain an authorization code',
      );
    }
    return OAuthAuthorizationCallback(code: code);
  }
}

abstract interface class OAuthCallbackReceiver {
  Uri get redirectUri;

  Future<OAuthAuthorizationCallback> waitForCallback({
    required String expectedState,
    required Duration timeout,
  });

  Future<void> close();
}

abstract interface class OAuthCallbackReceiverFactory {
  Future<OAuthCallbackReceiver> start(Uri configuredRedirectUri);
}

final class LoopbackCallbackReceiverFactory
    implements OAuthCallbackReceiverFactory {
  const LoopbackCallbackReceiverFactory();

  @override
  Future<OAuthCallbackReceiver> start(Uri configuredRedirectUri) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _LoopbackCallbackReceiver(server);
  }
}

final class _LoopbackCallbackReceiver implements OAuthCallbackReceiver {
  _LoopbackCallbackReceiver(this._server)
    : redirectUri = Uri.parse(
        'http://127.0.0.1:${_server.port}/oauth2/callback',
      );

  final HttpServer _server;
  bool _completed = false;

  @override
  final Uri redirectUri;

  @override
  Future<OAuthAuthorizationCallback> waitForCallback({
    required String expectedState,
    required Duration timeout,
  }) => _wait(expectedState).timeout(
    timeout,
    onTimeout: () => throw const CloudDriveOAuthException(
      CloudDriveOAuthFailureCode.timedOut,
      'Timed out waiting for the OAuth browser callback',
    ),
  );

  Future<OAuthAuthorizationCallback> _wait(String expectedState) async {
    await for (final request in _server) {
      if (_completed) {
        await _respond(request, HttpStatus.conflict, 'Callback already used.');
        continue;
      }
      final uri = request.uri;
      AppLogger.i(
        'Loopback callback received: method=${request.method}, '
            'path=${uri.path}, hasState=${uri.queryParameters.containsKey('state')}, '
            'hasCode=${uri.queryParameters.containsKey('code')}, '
            'hasError=${uri.queryParameters.containsKey('error')}',
        'CloudDriveOAuth',
      );
      if (request.method != 'GET') {
        AppLogger.w(
          'Loopback callback rejected: unsupported method=${request.method}',
          'CloudDriveOAuth',
        );
        await _respond(request, HttpStatus.methodNotAllowed, 'Not allowed.');
        continue;
      }
      try {
        final callback = OAuthCallbackValidator.validate(
          uri,
          expectedState: expectedState,
        );
        _completed = true;
        await _respond(
          request,
          HttpStatus.ok,
          'Authorization complete. You may close this window.',
        );
        AppLogger.i(
          'Loopback callback validated successfully',
          'CloudDriveOAuth',
        );
        return callback;
      } on CloudDriveOAuthException catch (error) {
        AppLogger.w(
          'Loopback callback validation failed: code=${error.code.name}, '
              'oauthError=${error.oauthError ?? 'none'}',
          'CloudDriveOAuth',
        );
        if (error.code == CloudDriveOAuthFailureCode.cancelled ||
            error.code == CloudDriveOAuthFailureCode.authorizationFailed) {
          _completed = true;
          await _respond(request, HttpStatus.ok, 'Authorization cancelled.');
        } else {
          await _respond(request, HttpStatus.badRequest, 'Invalid callback.');
        }
        rethrow;
      }
    }
    throw const CloudDriveOAuthException(
      CloudDriveOAuthFailureCode.cancelled,
      'OAuth callback listener was closed',
    );
  }

  Future<void> _respond(HttpRequest request, int status, String message) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><meta charset="utf-8"><title>OAuth</title>'
        '<p>${const HtmlEscape().convert(message)}</p>',
      );
    await request.response.close();
  }

  @override
  Future<void> close() => _server.close(force: true);
}

final class LoopbackCloudDriveOAuthClient
    implements CloudDriveOAuthClient, CloudDriveOAuthAuthenticationCanceller {
  LoopbackCloudDriveOAuthClient({
    required CloudDriveOAuthProviderConfig config,
    required OAuthHttpTransport transport,
    OAuthBrowserLauncher browserLauncher = const SystemOAuthBrowserLauncher(),
    OAuthCallbackReceiverFactory callbackReceiverFactory =
        const LoopbackCallbackReceiverFactory(),
    OAuthPkce? pkce,
    DateTime Function()? clock,
    this.callbackTimeout = const Duration(minutes: 3),
  }) : _config = config,
       _transport = transport,
       _browserLauncher = browserLauncher,
       _callbackReceiverFactory = callbackReceiverFactory,
       _pkce = pkce ?? OAuthPkce(),
       _clock = clock ?? DateTime.now {
    if (config.platform != CloudDriveOAuthPlatform.windows) {
      throw ArgumentError('Loopback OAuth is only valid on Windows');
    }
  }

  final CloudDriveOAuthProviderConfig _config;
  final OAuthHttpTransport _transport;
  final OAuthBrowserLauncher _browserLauncher;
  final OAuthCallbackReceiverFactory _callbackReceiverFactory;
  final OAuthPkce _pkce;
  final DateTime Function() _clock;
  final Duration callbackTimeout;
  final Map<int, OAuthCallbackReceiver> _activeReceivers = {};
  final Map<int, Future<void>> _receiverClosures = {};
  var _nextAuthenticationId = 0;
  var _cancelledThroughAuthenticationId = 0;

  @override
  CloudDriveOAuthProvider get provider => _config.provider;

  @override
  Future<CloudDriveOAuthSession> authenticate() async {
    final stopwatch = Stopwatch()..start();
    var stage = 'initialize';
    OAuthCallbackReceiver? receiver;
    final authenticationId = ++_nextAuthenticationId;
    AppLogger.i(
      'OAuth authentication started: provider=${provider.id}, '
          'callbackTimeout=${callbackTimeout.inSeconds}s',
      'CloudDriveOAuth',
    );
    try {
      final pkce = _pkce.create();
      stage = 'start_loopback_listener';
      receiver = await _callbackReceiverFactory.start(_config.redirectUri);
      if (authenticationId <= _cancelledThroughAuthenticationId) {
        await receiver.close();
        receiver = null;
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.cancelled,
          'OAuth authorization was cancelled',
        );
      }
      _activeReceivers[authenticationId] = receiver;
      AppLogger.i(
        'Loopback listener ready: provider=${provider.id}, '
            'port=${receiver.redirectUri.port}, path=${receiver.redirectUri.path}',
        'CloudDriveOAuth',
      );

      final authorizationUri = buildAuthorizationUri(
        redirectUri: receiver.redirectUri,
        request: pkce,
      );
      stage = 'open_system_browser';
      AppLogger.i(
        'Opening system browser: provider=${provider.id}, '
            'authority=${authorizationUri.host}',
        'CloudDriveOAuth',
      );
      if (!await _browserLauncher.open(authorizationUri)) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.cancelled,
          'The system browser could not be opened',
        );
      }
      AppLogger.i(
        'System browser launch accepted: provider=${provider.id}',
        'CloudDriveOAuth',
      );

      stage = 'wait_for_callback';
      AppLogger.i(
        'Waiting for OAuth callback: provider=${provider.id}',
        'CloudDriveOAuth',
      );
      final callback = await receiver.waitForCallback(
        expectedState: pkce.state,
        timeout: callbackTimeout,
      );
      AppLogger.i(
        'OAuth callback completed: provider=${provider.id}',
        'CloudDriveOAuth',
      );

      stage = 'exchange_authorization_code';
      AppLogger.i(
        'Exchanging OAuth authorization code: provider=${provider.id}',
        'CloudDriveOAuth',
      );
      final response = await _exchangeCode(
        code: callback.code,
        redirectUri: receiver.redirectUri,
        request: pkce,
      );
      AppLogger.i(
        'OAuth token response received: provider=${provider.id}, '
            'hasRefreshToken=${response.refreshToken != null}, '
            'hasIdToken=${response.idToken != null}',
        'CloudDriveOAuth',
      );

      stage = 'validate_identity';
      final identity = _validatedIdentity(response, pkce.nonce);
      final session = CloudDriveOAuthSession(
        provider: provider,
        accountId: identity.accountId,
        displayIdentifier: identity.displayIdentifier,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        expiresAt: response.expiresAt,
      );
      AppLogger.i(
        'OAuth authentication completed: provider=${provider.id}, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
        'CloudDriveOAuth',
      );
      return session;
    } catch (error, stackTrace) {
      AppLogger.e(
        'OAuth authentication failed: provider=${provider.id}, stage=$stage, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
        error,
        stackTrace,
        'CloudDriveOAuth',
      );
      rethrow;
    } finally {
      final activeReceiver = receiver;
      if (activeReceiver != null) {
        await _closeReceiver(authenticationId, activeReceiver);
      }
    }
  }

  @override
  Future<void> cancelAuthentication() async {
    _cancelledThroughAuthenticationId = _nextAuthenticationId;
    final active = _activeReceivers.entries.toList(growable: false);
    for (final entry in active) {
      final receiver = entry.value;
      AppLogger.i(
        'Cancelling OAuth callback wait: provider=${provider.id}, '
            'port=${receiver.redirectUri.port}',
        'CloudDriveOAuth',
      );
      await _closeReceiver(entry.key, receiver);
    }
  }

  Future<void> _closeReceiver(
    int authenticationId,
    OAuthCallbackReceiver receiver,
  ) {
    final existing = _receiverClosures[authenticationId];
    if (existing != null) return existing;
    AppLogger.d(
      'Closing loopback listener: provider=${provider.id}, '
          'port=${receiver.redirectUri.port}',
      'CloudDriveOAuth',
    );
    final close = receiver.close().whenComplete(() {
      if (identical(_activeReceivers[authenticationId], receiver)) {
        _activeReceivers.remove(authenticationId);
      }
      _receiverClosures.remove(authenticationId);
      AppLogger.d(
        'Loopback listener closed: provider=${provider.id}, '
            'port=${receiver.redirectUri.port}',
        'CloudDriveOAuth',
      );
    });
    _receiverClosures[authenticationId] = close;
    return close;
  }

  Uri buildAuthorizationUri({
    required Uri redirectUri,
    required OAuthPkceRequest request,
  }) {
    final parameters = <String, String>{
      'client_id': _config.clientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      'scope': _config.scopes.join(' '),
      'code_challenge': request.codeChallenge,
      'code_challenge_method': 'S256',
      'state': request.state,
      'nonce': request.nonce,
      'response_mode': 'query',
    };
    if (provider == CloudDriveOAuthProvider.googleDrive) {
      parameters.addAll({
        'access_type': 'offline',
        'prompt': 'consent',
        'include_granted_scopes': 'true',
      });
    }
    return _config.authorizationEndpoint.replace(queryParameters: parameters);
  }

  Future<_OAuthTokenResponse> _exchangeCode({
    required String code,
    required Uri redirectUri,
    required OAuthPkceRequest request,
  }) async {
    try {
      final fields = <String, String>{
        'client_id': _config.clientId,
        if (_config.clientSecret case final clientSecret?)
          'client_secret': clientSecret,
        'code': code,
        'code_verifier': request.codeVerifier,
        'redirect_uri': redirectUri.toString(),
        'grant_type': 'authorization_code',
      };
      final response = await _transport.postForm(_config.tokenEndpoint, fields);
      return _OAuthTokenResponse.parse(response, now: _clock());
    } on OAuthHttpException catch (error) {
      throw _mapHttpError(error);
    } on FormatException catch (error) {
      throw CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        error.message,
      );
    }
  }

  @override
  Future<CloudDriveOAuthSession> refresh(CloudDriveOAuthSession session) async {
    _requireMatchingSession(session);
    final refreshToken = session.refreshToken;
    if (refreshToken == null) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidGrant,
        'No refresh token is available; sign in again',
      );
    }
    try {
      final fields = <String, String>{
        'client_id': _config.clientId,
        if (_config.clientSecret case final clientSecret?)
          'client_secret': clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
        'scope': _config.scopes.join(' '),
      };
      final json = await _transport.postForm(_config.tokenEndpoint, fields);
      final response = _OAuthTokenResponse.parse(
        json,
        now: _clock(),
        fallbackRefreshToken: refreshToken,
      );
      return session.copyWith(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        expiresAt: response.expiresAt,
      );
    } on OAuthHttpException catch (error) {
      throw _mapHttpError(error);
    } on FormatException catch (error) {
      throw CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        error.message,
      );
    }
  }

  @override
  Future<void> disconnect(CloudDriveOAuthSession session) async {
    _requireMatchingSession(session);
    final revocationEndpoint = _config.revocationEndpoint;
    if (provider == CloudDriveOAuthProvider.googleDrive &&
        revocationEndpoint != null) {
      await _transport.postFormNoContent(revocationEndpoint, {
        'token': session.refreshToken ?? session.accessToken,
      });
    }
  }

  _OAuthIdentity _validatedIdentity(
    _OAuthTokenResponse response,
    String expectedNonce,
  ) {
    final idToken = response.idToken;
    if (idToken == null) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'OpenID Connect response did not include an ID token',
      );
    }
    final claims = _decodeJwtClaims(idToken);
    if (claims['nonce'] is! String ||
        !OAuthPkce.secureEquals(expectedNonce, claims['nonce'] as String)) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidCallback,
        'OpenID Connect nonce validation failed',
      );
    }
    final audience = claims['aud'];
    final audienceMatches =
        audience == _config.clientId ||
        (audience is List && audience.contains(_config.clientId));
    final expiry = claims['exp'];
    if (!audienceMatches ||
        expiry is! num ||
        DateTime.fromMillisecondsSinceEpoch(
          expiry.toInt() * 1000,
          isUtc: true,
        ).isBefore(_clock().toUtc())) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidCallback,
        'OpenID Connect token validation failed',
      );
    }
    if (provider == CloudDriveOAuthProvider.googleDrive) {
      final issuer = claims['iss'];
      if (issuer != 'https://accounts.google.com' &&
          issuer != 'accounts.google.com') {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.invalidCallback,
          'Google ID token issuer validation failed',
        );
      }
      final subject = claims['sub'];
      final email = claims['email'];
      if (subject is! String || subject.isEmpty || email is! String) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.malformedResponse,
          'Google identity claims are incomplete',
        );
      }
      return _OAuthIdentity(subject, email);
    }
    final objectId = claims['oid'] ?? claims['sub'];
    final tenantId = claims['tid'] ?? 'consumer';
    final issuer = claims['iss'];
    if (tenantId is! String ||
        issuer != 'https://login.microsoftonline.com/$tenantId/v2.0') {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidCallback,
        'Microsoft ID token issuer validation failed',
      );
    }
    final display =
        claims['preferred_username'] ?? claims['email'] ?? claims['name'];
    if (objectId is! String ||
        objectId.isEmpty ||
        display is! String ||
        display.isEmpty) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'Microsoft identity claims are incomplete',
      );
    }
    return _OAuthIdentity('$tenantId:$objectId', display);
  }

  Map<String, dynamic> _decodeJwtClaims(String token) {
    final segments = token.split('.');
    if (segments.length != 3) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'ID token is not a JWT',
      );
    }
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JWT payload is not an object');
      }
      return decoded;
    } on FormatException {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'ID token payload is malformed',
      );
    }
  }

  CloudDriveOAuthException _mapHttpError(OAuthHttpException error) {
    var description = error.description?.replaceAll(RegExp(r'[\r\n]+'), ' ');
    final clientSecret = _config.clientSecret;
    if (description != null && clientSecret != null) {
      description = description.replaceAll(clientSecret, '[redacted]');
    }
    if (description != null && description.length > 300) {
      description = '${description.substring(0, 300)}…';
    }
    AppLogger.w(
      'OAuth endpoint rejected request: provider=${provider.id}, '
          'status=${error.statusCode}, oauthError=${error.error}, '
          'description=${description ?? 'none'}',
      'CloudDriveOAuth',
    );
    return CloudDriveOAuthException(
      error.error == 'invalid_grant'
          ? CloudDriveOAuthFailureCode.invalidGrant
          : CloudDriveOAuthFailureCode.authorizationFailed,
      error.error == 'invalid_grant'
          ? 'OAuth grant is no longer valid; sign in again'
          : 'OAuth endpoint rejected the request',
      oauthError: error.error,
    );
  }

  void _requireMatchingSession(CloudDriveOAuthSession session) {
    if (session.provider != provider) {
      throw ArgumentError('OAuth session provider mismatch');
    }
  }
}

final class _OAuthIdentity {
  const _OAuthIdentity(this.accountId, this.displayIdentifier);

  final String accountId;
  final String displayIdentifier;
}

final class _OAuthTokenResponse {
  const _OAuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.idToken,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String? idToken;

  factory _OAuthTokenResponse.parse(
    Map<String, dynamic> json, {
    required DateTime now,
    String? fallbackRefreshToken,
  }) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'] ?? fallbackRefreshToken;
    final expiresIn = json['expires_in'];
    final tokenType = json['token_type'];
    final idToken = json['id_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        (refreshToken != null && refreshToken is! String) ||
        expiresIn is! num ||
        expiresIn <= 0 ||
        tokenType is! String ||
        tokenType.toLowerCase() != 'bearer' ||
        (idToken != null && idToken is! String)) {
      throw const FormatException('OAuth token response schema mismatch');
    }
    return _OAuthTokenResponse(
      accessToken: accessToken,
      refreshToken: refreshToken as String?,
      expiresAt: now.toUtc().add(Duration(seconds: expiresIn.toInt())),
      idToken: idToken as String?,
    );
  }
}
