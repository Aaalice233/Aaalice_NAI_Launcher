import 'dart:convert';

import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_config.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_models.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/mobile_oauth_clients.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tenantId = '9188040d-6c67-4c5b-b112-36a304b66dad';
  const clientId = 'microsoft-client';
  final config = CloudDriveOAuthProviderConfig(
    provider: CloudDriveOAuthProvider.oneDrive,
    platform: CloudDriveOAuthPlatform.android,
    clientId: clientId,
    redirectUri: Uri.parse(
      'com.aaalice.nailauncher.oauth://oauth2redirect/microsoft',
    ),
    authorizationEndpoint: Uri.parse(
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    ),
    tokenEndpoint: Uri.parse(
      'https://login.microsoftonline.com/common/oauth2/v2.0/token',
    ),
    revocationEndpoint: null,
    issuer: Uri.parse('https://login.microsoftonline.com/common/v2.0'),
    scopes: const <String>[
      'openid',
      'profile',
      'offline_access',
      'Files.ReadWrite.AppFolder',
    ],
  );

  test(
    'OneDrive exchanges the authorization code with explicit endpoints',
    () async {
      final appAuth = _FakeFlutterAppAuth();
      appAuth.authorizationResponse = const AuthorizationResponse(
        authorizationCode: 'authorization-code',
        codeVerifier: 'code-verifier',
      );
      appAuth.tokenResponses.add(
        TokenResponse(
          'access-token',
          'refresh-token',
          DateTime.utc(2026, 9, 2, 11),
          _jwt(<String, Object?>{
            'oid': 'object-id',
            'tid': tenantId,
            'preferred_username': 'person@example.com',
          }),
          'Bearer',
          null,
          null,
        ),
      );
      final client = AppAuthOneDriveOAuthClient(
        config: config,
        appAuth: appAuth,
      );

      final session = await client.authenticate();

      expect(session.accountId, '$tenantId:object-id');
      expect(session.displayIdentifier, 'person@example.com');
      final authorizationRequest = appAuth.authorizationRequests.single;
      final tokenRequest = appAuth.tokenRequests.single;
      expect(authorizationRequest.issuer, isNull);
      expect(
        authorizationRequest.serviceConfiguration?.authorizationEndpoint,
        config.authorizationEndpoint.toString(),
      );
      expect(tokenRequest.issuer, isNull);
      expect(
        tokenRequest.serviceConfiguration?.tokenEndpoint,
        config.tokenEndpoint.toString(),
      );
      expect(tokenRequest.authorizationCode, 'authorization-code');
      expect(tokenRequest.codeVerifier, 'code-verifier');
      expect(tokenRequest.nonce, authorizationRequest.nonce);
    },
  );

  test('OneDrive refresh preserves an unrotated refresh token', () async {
    final appAuth = _FakeFlutterAppAuth();
    appAuth.tokenResponses.add(
      TokenResponse(
        'new-access-token',
        null,
        DateTime.utc(2026, 9, 2, 12),
        null,
        'Bearer',
        null,
        null,
      ),
    );
    final client = AppAuthOneDriveOAuthClient(config: config, appAuth: appAuth);
    final current = CloudDriveOAuthSession(
      provider: CloudDriveOAuthProvider.oneDrive,
      accountId: '$tenantId:object-id',
      displayIdentifier: 'person@example.com',
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
      expiresAt: DateTime.utc(2026, 9, 2, 10),
    );

    final refreshed = await client.refresh(current);

    expect(refreshed.accessToken, 'new-access-token');
    expect(refreshed.refreshToken, 'old-refresh-token');
    final request = appAuth.tokenRequests.single;
    expect(request.refreshToken, 'old-refresh-token');
    expect(
      request.serviceConfiguration?.tokenEndpoint,
      config.tokenEndpoint.toString(),
    );
  });
}

String _jwt(Map<String, Object?> claims) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(<String, Object?>{'alg': 'RS256', 'typ': 'JWT'})}.'
      '${encode(claims)}.signature';
}

final class _FakeFlutterAppAuth extends FlutterAppAuth {
  AuthorizationResponse? authorizationResponse;
  final List<TokenResponse> tokenResponses = <TokenResponse>[];
  final List<AuthorizationRequest> authorizationRequests =
      <AuthorizationRequest>[];
  final List<TokenRequest> tokenRequests = <TokenRequest>[];

  @override
  Future<AuthorizationResponse> authorize(AuthorizationRequest request) async {
    authorizationRequests.add(request);
    final response = authorizationResponse;
    if (response == null) {
      throw StateError('Missing authorization response');
    }
    return response;
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    tokenRequests.add(request);
    if (tokenResponses.isEmpty) {
      throw StateError('Missing token response');
    }
    return tokenResponses.removeAt(0);
  }
}
