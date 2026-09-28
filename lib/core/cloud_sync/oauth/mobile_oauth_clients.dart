import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../utils/app_logger.dart';
import '../../utils/fatal_diagnostics.dart';
import 'cloud_drive_oauth_client.dart';
import 'cloud_drive_oauth_config.dart';
import 'cloud_drive_oauth_models.dart';
import 'oauth_http_transport.dart';
import 'oauth_pkce.dart';

final class GoogleSignInAndroidCloudDriveOAuthClient
    implements CloudDriveOAuthClient {
  GoogleSignInAndroidCloudDriveOAuthClient({
    required CloudDriveOAuthProviderConfig config,
    GoogleSignIn? signIn,
    OAuthPkce? random,
    DateTime Function()? clock,
  }) : _config = config,
       _signIn = signIn ?? GoogleSignIn.instance,
       _random = random ?? OAuthPkce(),
       _clock = clock ?? DateTime.now {
    if (config.provider != CloudDriveOAuthProvider.googleDrive ||
        config.platform != CloudDriveOAuthPlatform.android) {
      throw ArgumentError('Google Sign-In client requires Android');
    }
  }

  static const _scopes = <String>[CloudDriveOAuthConfig.googleDriveScope];
  static const _accessTokenLifetime = Duration(minutes: 50);

  final CloudDriveOAuthProviderConfig _config;
  final GoogleSignIn _signIn;
  final OAuthPkce _random;
  final DateTime Function() _clock;
  Future<void>? _initialization;

  @override
  CloudDriveOAuthProvider get provider => CloudDriveOAuthProvider.googleDrive;

  Future<void> _initialize() => _initialization ??= _signIn.initialize(
    serverClientId: _config.clientId,
    nonce: _random.create().nonce,
  );

  @override
  Future<CloudDriveOAuthSession> authenticate() async {
    await _initialize();
    try {
      final account = await _signIn.authenticate(scopeHint: _scopes);
      final authorization =
          await account.authorizationClient.authorizationForScopes(_scopes) ??
          await account.authorizationClient.authorizeScopes(_scopes);
      return _session(account, authorization.accessToken);
    } on GoogleSignInException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<CloudDriveOAuthSession> refresh(CloudDriveOAuthSession session) async {
    _requireSession(session);
    await _initialize();
    try {
      final account = await _signIn.attemptLightweightAuthentication(
        reportAllExceptions: true,
      );
      if (account == null || account.id != session.accountId) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.invalidGrant,
          'Google account authorization must be renewed',
        );
      }
      final authorization = await account.authorizationClient
          .authorizationForScopes(_scopes);
      if (authorization == null) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.invalidGrant,
          'Google Drive authorization must be renewed',
        );
      }
      return _session(account, authorization.accessToken);
    } on GoogleSignInException catch (error) {
      throw _mapError(error, refreshing: true);
    }
  }

  @override
  Future<void> disconnect(CloudDriveOAuthSession session) async {
    _requireSession(session);
    await _initialize();
    await _signIn.disconnect();
  }

  CloudDriveOAuthSession _session(
    GoogleSignInAccount account,
    String accessToken,
  ) => CloudDriveOAuthSession(
    provider: provider,
    accountId: account.id,
    displayIdentifier: account.email,
    accessToken: accessToken,
    refreshToken: null,
    expiresAt: _clock().toUtc().add(_accessTokenLifetime),
  );

  CloudDriveOAuthException _mapError(
    GoogleSignInException error, {
    bool refreshing = false,
  }) {
    final cancelled =
        error.code == GoogleSignInExceptionCode.canceled ||
        error.code == GoogleSignInExceptionCode.interrupted;
    final description = error.description == null
        ? null
        : FatalDiagnostics.redactSensitiveText(
            error.description!.replaceAll(RegExp(r'[\r\n]+'), ' ').trim(),
          );
    AppLogger.e(
      'Google native OAuth failed: code=${error.code.name}, '
          'description=${description == null || description.isEmpty ? 'none' : description}',
      'CloudDriveOAuth',
    );
    return CloudDriveOAuthException(
      cancelled
          ? CloudDriveOAuthFailureCode.cancelled
          : refreshing
          ? CloudDriveOAuthFailureCode.invalidGrant
          : CloudDriveOAuthFailureCode.authorizationFailed,
      cancelled
          ? 'Google authorization was cancelled'
          : refreshing
          ? 'Google authorization must be renewed'
          : 'Google authorization failed',
    );
  }

  void _requireSession(CloudDriveOAuthSession session) {
    if (session.provider != provider) {
      throw ArgumentError('OAuth session provider mismatch');
    }
  }
}

final class AppAuthGoogleDriveOAuthClient implements CloudDriveOAuthClient {
  AppAuthGoogleDriveOAuthClient({
    required CloudDriveOAuthProviderConfig config,
    FlutterAppAuth appAuth = const FlutterAppAuth(),
    OAuthHttpTransport? transport,
    OAuthPkce? random,
  }) : _config = config,
       _appAuth = appAuth,
       _transport = transport ?? DioOAuthHttpTransport(),
       _random = random ?? OAuthPkce() {
    if (config.provider != CloudDriveOAuthProvider.googleDrive ||
        (config.platform != CloudDriveOAuthPlatform.android &&
            config.platform != CloudDriveOAuthPlatform.macos)) {
      throw ArgumentError('AppAuth Google client requires Android or macOS');
    }
  }

  final CloudDriveOAuthProviderConfig _config;
  final FlutterAppAuth _appAuth;
  final OAuthHttpTransport _transport;
  final OAuthPkce _random;

  @override
  CloudDriveOAuthProvider get provider => CloudDriveOAuthProvider.googleDrive;

  @override
  Future<CloudDriveOAuthSession> authenticate() async {
    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _config.clientId,
          _config.redirectUri.toString(),
          issuer: _config.issuer.toString(),
          scopes: _config.scopes,
          nonce: _random.create().nonce,
          promptValues: const ['consent'],
          additionalParameters: const {
            'access_type': 'offline',
            'include_granted_scopes': 'true',
          },
        ),
      );
      return _newSession(response);
    } on FlutterAppAuthUserCancelledException {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.cancelled,
        'Google authorization was cancelled',
      );
    } on FlutterAppAuthPlatformException catch (error) {
      throw _mapAppAuthError(error);
    }
  }

  @override
  Future<CloudDriveOAuthSession> refresh(CloudDriveOAuthSession session) async {
    _requireSession(session);
    final refreshToken = session.refreshToken;
    if (refreshToken == null) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidGrant,
        'No Google refresh token is available; sign in again',
      );
    }
    try {
      final response = await _appAuth.token(
        TokenRequest(
          _config.clientId,
          _config.redirectUri.toString(),
          issuer: _config.issuer.toString(),
          refreshToken: refreshToken,
          scopes: _config.scopes,
        ),
      );
      final accessToken = response.accessToken;
      final expiry = response.accessTokenExpirationDateTime;
      if (accessToken == null || accessToken.isEmpty || expiry == null) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.malformedResponse,
          'Google refresh response is incomplete',
        );
      }
      return session.copyWith(
        accessToken: accessToken,
        refreshToken: response.refreshToken ?? refreshToken,
        expiresAt: expiry,
      );
    } on FlutterAppAuthPlatformException catch (error) {
      throw _mapAppAuthError(error);
    }
  }

  @override
  Future<void> disconnect(CloudDriveOAuthSession session) async {
    _requireSession(session);
    await _transport.postFormNoContent(_config.revocationEndpoint!, {
      'token': session.refreshToken ?? session.accessToken,
    });
  }

  CloudDriveOAuthSession _newSession(AuthorizationTokenResponse response) {
    final accessToken = response.accessToken;
    final refreshToken = response.refreshToken;
    final expiry = response.accessTokenExpirationDateTime;
    final idToken = response.idToken;
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        expiry == null ||
        idToken == null) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'Google authorization response is incomplete',
      );
    }
    final claims = _decodeClaims(idToken, 'Google');
    final accountId = claims['sub'];
    final display = claims['email'];
    if (accountId is! String ||
        accountId.isEmpty ||
        display is! String ||
        display.isEmpty) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'Google identity claims are incomplete',
      );
    }
    return CloudDriveOAuthSession(
      provider: provider,
      accountId: accountId,
      displayIdentifier: display,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiry,
    );
  }

  CloudDriveOAuthException _mapAppAuthError(
    FlutterAppAuthPlatformException error,
  ) {
    final oauthError = error.platformErrorDetails.error;
    _logAppAuthFailure(provider, error.platformErrorDetails);
    return CloudDriveOAuthException(
      oauthError == FlutterAppAuthOAuthError.invalidGrant
          ? CloudDriveOAuthFailureCode.invalidGrant
          : CloudDriveOAuthFailureCode.authorizationFailed,
      oauthError == FlutterAppAuthOAuthError.invalidGrant
          ? 'Google authorization is no longer valid; sign in again'
          : 'Google authorization failed',
      oauthError: oauthError,
    );
  }

  void _requireSession(CloudDriveOAuthSession session) {
    if (session.provider != provider) {
      throw ArgumentError('OAuth session provider mismatch');
    }
  }
}

final class AppAuthOneDriveOAuthClient implements CloudDriveOAuthClient {
  AppAuthOneDriveOAuthClient({
    required CloudDriveOAuthProviderConfig config,
    FlutterAppAuth appAuth = const FlutterAppAuth(),
    OAuthPkce? random,
  }) : _config = config,
       _appAuth = appAuth,
       _random = random ?? OAuthPkce() {
    if (config.provider != CloudDriveOAuthProvider.oneDrive ||
        (config.platform != CloudDriveOAuthPlatform.android &&
            config.platform != CloudDriveOAuthPlatform.macos)) {
      throw ArgumentError('AppAuth OneDrive client requires Android or macOS');
    }
  }

  final CloudDriveOAuthProviderConfig _config;
  final FlutterAppAuth _appAuth;
  final OAuthPkce _random;

  @override
  CloudDriveOAuthProvider get provider => CloudDriveOAuthProvider.oneDrive;

  @override
  Future<CloudDriveOAuthSession> authenticate() async {
    final nonce = _random.create().nonce;
    try {
      // Microsoft returns a tenant-specific ID-token issuer even when the
      // documented `common` authority is used. Explicit endpoints avoid the
      // discovery issuer mismatch while AppAuth still owns PKCE and token
      // validation.
      final authorization = await _appAuth.authorize(
        AuthorizationRequest(
          _config.clientId,
          _config.redirectUri.toString(),
          serviceConfiguration: _serviceConfiguration,
          scopes: _config.scopes,
          nonce: nonce,
        ),
      );
      final code = authorization.authorizationCode;
      final verifier = authorization.codeVerifier;
      if (code == null ||
          code.isEmpty ||
          verifier == null ||
          verifier.isEmpty) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.malformedResponse,
          'Microsoft authorization response is incomplete',
        );
      }
      final response = await _appAuth.token(
        TokenRequest(
          _config.clientId,
          _config.redirectUri.toString(),
          serviceConfiguration: _serviceConfiguration,
          scopes: _config.scopes,
          authorizationCode: code,
          codeVerifier: verifier,
          nonce: nonce,
        ),
      );
      return _newSession(response);
    } on FlutterAppAuthUserCancelledException {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.cancelled,
        'Microsoft authorization was cancelled',
      );
    } on FlutterAppAuthPlatformException catch (error) {
      throw _mapAppAuthError(error);
    }
  }

  @override
  Future<CloudDriveOAuthSession> refresh(CloudDriveOAuthSession session) async {
    _requireSession(session);
    final refreshToken = session.refreshToken;
    if (refreshToken == null) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.invalidGrant,
        'No Microsoft refresh token is available; sign in again',
      );
    }
    try {
      final response = await _appAuth.token(
        TokenRequest(
          _config.clientId,
          _config.redirectUri.toString(),
          serviceConfiguration: _serviceConfiguration,
          scopes: _config.scopes,
          refreshToken: refreshToken,
        ),
      );
      final accessToken = response.accessToken;
      final expiry = response.accessTokenExpirationDateTime;
      if (accessToken == null || accessToken.isEmpty || expiry == null) {
        throw const CloudDriveOAuthException(
          CloudDriveOAuthFailureCode.malformedResponse,
          'Microsoft refresh response is incomplete',
        );
      }
      final nextRefreshToken = response.refreshToken;
      return session.copyWith(
        accessToken: accessToken,
        refreshToken: nextRefreshToken == null || nextRefreshToken.isEmpty
            ? refreshToken
            : nextRefreshToken,
        expiresAt: expiry,
      );
    } on FlutterAppAuthPlatformException catch (error) {
      throw _mapAppAuthError(error);
    }
  }

  @override
  Future<void> disconnect(CloudDriveOAuthSession session) async {
    _requireSession(session);
    // Microsoft has no least-privilege per-token revoke endpoint for this
    // native flow. Local secure-storage deletion is performed by the token
    // provider; browser-wide logout is intentionally not automatic.
  }

  AuthorizationServiceConfiguration get _serviceConfiguration =>
      AuthorizationServiceConfiguration(
        authorizationEndpoint: _config.authorizationEndpoint.toString(),
        tokenEndpoint: _config.tokenEndpoint.toString(),
      );

  CloudDriveOAuthSession _newSession(TokenResponse response) {
    final accessToken = response.accessToken;
    final refreshToken = response.refreshToken;
    final expiry = response.accessTokenExpirationDateTime;
    final idToken = response.idToken;
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        expiry == null ||
        idToken == null ||
        idToken.isEmpty) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'Microsoft authorization response is incomplete',
      );
    }
    final claims = _decodeClaims(idToken, 'Microsoft');
    final objectId = claims['oid'] ?? claims['sub'];
    final tenantId = claims['tid'];
    final display =
        claims['preferred_username'] ?? claims['email'] ?? claims['name'];
    if (objectId is! String ||
        objectId.isEmpty ||
        tenantId is! String ||
        tenantId.isEmpty ||
        display is! String ||
        display.isEmpty) {
      throw const CloudDriveOAuthException(
        CloudDriveOAuthFailureCode.malformedResponse,
        'Microsoft identity claims are incomplete',
      );
    }
    return CloudDriveOAuthSession(
      provider: provider,
      accountId: '$tenantId:$objectId',
      displayIdentifier: display,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiry,
    );
  }

  CloudDriveOAuthException _mapAppAuthError(
    FlutterAppAuthPlatformException error,
  ) {
    final oauthError = error.platformErrorDetails.error;
    _logAppAuthFailure(provider, error.platformErrorDetails);
    return CloudDriveOAuthException(
      oauthError == FlutterAppAuthOAuthError.invalidGrant
          ? CloudDriveOAuthFailureCode.invalidGrant
          : CloudDriveOAuthFailureCode.authorizationFailed,
      oauthError == FlutterAppAuthOAuthError.invalidGrant
          ? 'Microsoft authorization is no longer valid; sign in again'
          : 'Microsoft authorization failed',
      oauthError: oauthError,
    );
  }

  void _requireSession(CloudDriveOAuthSession session) {
    if (session.provider != provider) {
      throw ArgumentError('OAuth session provider mismatch');
    }
  }
}

void _logAppAuthFailure(
  CloudDriveOAuthProvider provider,
  FlutterAppAuthPlatformErrorDetails details,
) {
  final description = details.errorDescription == null
      ? null
      : FatalDiagnostics.redactSensitiveText(
          details.errorDescription!.replaceAll(RegExp(r'[\r\n]+'), ' ').trim(),
        );
  AppLogger.e(
    'Native OAuth failed: provider=${provider.id}, type=${details.type}, '
        'code=${details.code}, oauthError=${details.error ?? 'none'}, '
        'description=${description == null || description.isEmpty ? 'none' : description}',
    'CloudDriveOAuth',
  );
}

Map<String, dynamic> _decodeClaims(String token, String providerName) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw CloudDriveOAuthException(
      CloudDriveOAuthFailureCode.malformedResponse,
      '$providerName ID token is malformed',
    );
  }
  try {
    final value = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  } on FormatException {
    throw CloudDriveOAuthException(
      CloudDriveOAuthFailureCode.malformedResponse,
      '$providerName ID token payload is malformed',
    );
  }
}
