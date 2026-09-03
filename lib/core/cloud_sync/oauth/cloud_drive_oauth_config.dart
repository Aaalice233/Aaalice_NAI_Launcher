import 'dart:io';

import 'cloud_drive_oauth_models.dart';

enum CloudDriveOAuthPlatform { android, macos, windows, unsupported }

final class CloudDriveOAuthConfigDiagnostic {
  const CloudDriveOAuthConfigDiagnostic({
    required this.provider,
    required this.platform,
    required this.isConfigured,
    required this.reasons,
  });

  final CloudDriveOAuthProvider provider;
  final CloudDriveOAuthPlatform platform;
  final bool isConfigured;
  final List<String> reasons;

  @override
  String toString() => isConfigured
      ? '${provider.id}/${platform.name}: configured'
      : '${provider.id}/${platform.name}: ${reasons.join('; ')}';
}

final class CloudDriveOAuthProviderConfig {
  const CloudDriveOAuthProviderConfig({
    required this.provider,
    required this.platform,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.revocationEndpoint,
    required this.issuer,
  });

  final CloudDriveOAuthProvider provider;
  final CloudDriveOAuthPlatform platform;
  final String clientId;
  final Uri redirectUri;
  final List<String> scopes;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri? revocationEndpoint;
  final Uri issuer;
}

/// Compile-time OAuth configuration. Scopes and endpoints are intentionally
/// constants and cannot be widened using `--dart-define`.
final class CloudDriveOAuthConfig {
  CloudDriveOAuthConfig._(this.platform, this._values);

  factory CloudDriveOAuthConfig.fromDartDefines({
    CloudDriveOAuthPlatform? platform,
  }) => CloudDriveOAuthConfig._(platform ?? detectPlatform(), const {
    'GOOGLE_DRIVE_ANDROID_CLIENT_ID': String.fromEnvironment(
      'GOOGLE_DRIVE_ANDROID_CLIENT_ID',
    ),
    'GOOGLE_DRIVE_ANDROID_REDIRECT_URI': String.fromEnvironment(
      'GOOGLE_DRIVE_ANDROID_REDIRECT_URI',
    ),
    'GOOGLE_DRIVE_MACOS_CLIENT_ID': String.fromEnvironment(
      'GOOGLE_DRIVE_MACOS_CLIENT_ID',
    ),
    'GOOGLE_DRIVE_MACOS_REDIRECT_URI': String.fromEnvironment(
      'GOOGLE_DRIVE_MACOS_REDIRECT_URI',
    ),
    'GOOGLE_DRIVE_WINDOWS_CLIENT_ID': String.fromEnvironment(
      'GOOGLE_DRIVE_WINDOWS_CLIENT_ID',
    ),
    'GOOGLE_DRIVE_WINDOWS_REDIRECT_URI': String.fromEnvironment(
      'GOOGLE_DRIVE_WINDOWS_REDIRECT_URI',
    ),
    'ONEDRIVE_ANDROID_CLIENT_ID': String.fromEnvironment(
      'ONEDRIVE_ANDROID_CLIENT_ID',
    ),
    'ONEDRIVE_ANDROID_REDIRECT_URI': String.fromEnvironment(
      'ONEDRIVE_ANDROID_REDIRECT_URI',
    ),
    'ONEDRIVE_MACOS_CLIENT_ID': String.fromEnvironment(
      'ONEDRIVE_MACOS_CLIENT_ID',
    ),
    'ONEDRIVE_MACOS_REDIRECT_URI': String.fromEnvironment(
      'ONEDRIVE_MACOS_REDIRECT_URI',
    ),
    'ONEDRIVE_WINDOWS_CLIENT_ID': String.fromEnvironment(
      'ONEDRIVE_WINDOWS_CLIENT_ID',
    ),
    'ONEDRIVE_WINDOWS_REDIRECT_URI': String.fromEnvironment(
      'ONEDRIVE_WINDOWS_REDIRECT_URI',
    ),
    'ONEDRIVE_TENANT_ID': String.fromEnvironment(
      'ONEDRIVE_TENANT_ID',
      defaultValue: 'common',
    ),
  });

  factory CloudDriveOAuthConfig.forTesting({
    required CloudDriveOAuthPlatform platform,
    Map<String, String> values = const {},
  }) => CloudDriveOAuthConfig._(platform, values);

  static const googleDriveScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const oneDriveAppFolderScope = 'Files.ReadWrite.AppFolder';
  static const mobileCallbackScheme = 'com.aaalice.nailauncher.oauth';
  static const oneDriveMobileCallbackUri =
      '$mobileCallbackScheme://oauth2redirect/microsoft';

  static const _googleScopes = <String>['openid', 'email', googleDriveScope];
  static const _oneDriveScopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
    oneDriveAppFolderScope,
  ];

  final CloudDriveOAuthPlatform platform;
  final Map<String, String> _values;

  static CloudDriveOAuthPlatform detectPlatform() {
    if (Platform.isAndroid) return CloudDriveOAuthPlatform.android;
    if (Platform.isMacOS) return CloudDriveOAuthPlatform.macos;
    if (Platform.isWindows) return CloudDriveOAuthPlatform.windows;
    return CloudDriveOAuthPlatform.unsupported;
  }

  CloudDriveOAuthConfigDiagnostic diagnose(CloudDriveOAuthProvider provider) {
    final reasons = <String>[];
    if (platform == CloudDriveOAuthPlatform.unsupported) {
      reasons.add('OAuth is supported only on Android, macOS, and Windows');
      return CloudDriveOAuthConfigDiagnostic(
        provider: provider,
        platform: platform,
        isConfigured: false,
        reasons: reasons,
      );
    }
    final clientKey = _key(provider, 'CLIENT_ID');
    final redirectKey = _key(provider, 'REDIRECT_URI');
    final clientId = (_values[clientKey] ?? '').trim();
    final redirectValue = (_values[redirectKey] ?? '').trim();
    final requiresRedirect =
        !(provider == CloudDriveOAuthProvider.googleDrive &&
            platform == CloudDriveOAuthPlatform.android);
    if (clientId.isEmpty) reasons.add('Missing --dart-define=$clientKey');
    if (redirectValue.isEmpty && requiresRedirect) {
      reasons.add('Missing --dart-define=$redirectKey');
    } else if (redirectValue.isNotEmpty) {
      final redirect = Uri.tryParse(redirectValue);
      if (redirect == null || !redirect.hasScheme || redirect.hasFragment) {
        reasons.add('$redirectKey is not a valid redirect URI');
      } else {
        reasons.addAll(_validateRedirect(provider, redirectKey, redirect));
      }
    }
    final tenant = (_values['ONEDRIVE_TENANT_ID'] ?? 'common').trim();
    if (provider == CloudDriveOAuthProvider.oneDrive && tenant.isEmpty) {
      reasons.add('ONEDRIVE_TENANT_ID must not be empty');
    }
    return CloudDriveOAuthConfigDiagnostic(
      provider: provider,
      platform: platform,
      isConfigured: reasons.isEmpty,
      reasons: List.unmodifiable(reasons),
    );
  }

  CloudDriveOAuthProviderConfig requireProvider(
    CloudDriveOAuthProvider provider,
  ) {
    final diagnostic = diagnose(provider);
    if (!diagnostic.isConfigured) {
      throw StateError(diagnostic.toString());
    }
    final tenant = (_values['ONEDRIVE_TENANT_ID'] ?? 'common').trim();
    final microsoftBase =
        'https://login.microsoftonline.com/$tenant/oauth2/v2.0';
    return CloudDriveOAuthProviderConfig(
      provider: provider,
      platform: platform,
      clientId: _values[_key(provider, 'CLIENT_ID')]!.trim(),
      redirectUri: Uri.parse(
        (_values[_key(provider, 'REDIRECT_URI')] ?? '').trim().isEmpty
            ? 'com.googleusercontent.apps.sdk:/oauth2redirect'
            : _values[_key(provider, 'REDIRECT_URI')]!.trim(),
      ),
      scopes: provider == CloudDriveOAuthProvider.googleDrive
          ? _googleScopes
          : _oneDriveScopes,
      authorizationEndpoint: Uri.parse(
        provider == CloudDriveOAuthProvider.googleDrive
            ? 'https://accounts.google.com/o/oauth2/v2/auth'
            : '$microsoftBase/authorize',
      ),
      tokenEndpoint: Uri.parse(
        provider == CloudDriveOAuthProvider.googleDrive
            ? 'https://oauth2.googleapis.com/token'
            : '$microsoftBase/token',
      ),
      revocationEndpoint: provider == CloudDriveOAuthProvider.googleDrive
          ? Uri.parse('https://oauth2.googleapis.com/revoke')
          : null,
      issuer: Uri.parse(
        provider == CloudDriveOAuthProvider.googleDrive
            ? 'https://accounts.google.com'
            : 'https://login.microsoftonline.com/$tenant/v2.0',
      ),
    );
  }

  String _key(CloudDriveOAuthProvider provider, String suffix) {
    final providerPrefix = provider == CloudDriveOAuthProvider.googleDrive
        ? 'GOOGLE_DRIVE'
        : 'ONEDRIVE';
    return '${providerPrefix}_${platform.name.toUpperCase()}_$suffix';
  }

  List<String> _validateRedirect(
    CloudDriveOAuthProvider provider,
    String key,
    Uri redirect,
  ) {
    if (platform == CloudDriveOAuthPlatform.windows) {
      if (redirect.scheme != 'http' ||
          redirect.host != '127.0.0.1' ||
          redirect.hasPort ||
          (redirect.path.isNotEmpty && redirect.path != '/')) {
        return [
          '$key must be http://127.0.0.1 for a random-port loopback callback',
        ];
      }
      return const [];
    }
    if (provider == CloudDriveOAuthProvider.oneDrive &&
        redirect.toString() != oneDriveMobileCallbackUri) {
      return ['$key must be $oneDriveMobileCallbackUri'];
    }
    if (provider == CloudDriveOAuthProvider.googleDrive &&
        platform == CloudDriveOAuthPlatform.macos &&
        !redirect.scheme.startsWith('com.googleusercontent.apps.')) {
      return ['$key must use the reversed Google client ID scheme'];
    }
    return const [];
  }
}
