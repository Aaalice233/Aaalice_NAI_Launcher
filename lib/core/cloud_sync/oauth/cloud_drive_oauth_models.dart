import 'dart:convert';

/// Cloud providers supported by the OAuth infrastructure.
enum CloudDriveOAuthProvider {
  googleDrive('google_drive'),
  oneDrive('onedrive');

  const CloudDriveOAuthProvider(this.id);

  final String id;

  static CloudDriveOAuthProvider parse(String value) => values.firstWhere(
    (provider) => provider.id == value,
    orElse: () => throw const FormatException('Unsupported OAuth provider'),
  );
}

/// Credentials returned by a cloud provider.
///
/// Instances may only be encoded for [SecureStorageService]. Callers must not
/// place this object in ordinary app configuration, logs, analytics, or crash
/// reports.
final class CloudDriveOAuthSession {
  CloudDriveOAuthSession({
    required this.provider,
    required this.accountId,
    required this.displayIdentifier,
    required this.accessToken,
    required this.refreshToken,
    required DateTime expiresAt,
  }) : expiresAt = expiresAt.toUtc() {
    if (accountId.trim().isEmpty ||
        displayIdentifier.trim().isEmpty ||
        accessToken.isEmpty) {
      throw ArgumentError('OAuth session fields must not be empty');
    }
  }

  static const int schemaVersion = 1;
  static const Set<String> _schemaKeys = {
    'schemaVersion',
    'provider',
    'accountId',
    'displayIdentifier',
    'accessToken',
    'refreshToken',
    'expiresAt',
  };

  final CloudDriveOAuthProvider provider;
  final String accountId;
  final String displayIdentifier;
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  bool isExpired(DateTime now, {Duration skew = Duration.zero}) =>
      !expiresAt.isAfter(now.toUtc().add(skew));

  CloudDriveOAuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) => CloudDriveOAuthSession(
    provider: provider,
    accountId: accountId,
    displayIdentifier: displayIdentifier,
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  Map<String, Object?> _toSecureStorageJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'provider': provider.id,
    'accountId': accountId,
    'displayIdentifier': displayIdentifier,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  String encodeForSecureStorage() => jsonEncode(_toSecureStorageJson());

  factory CloudDriveOAuthSession.decodeFromSecureStorage(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('OAuth session must be a JSON object');
    }
    return CloudDriveOAuthSession.fromJson(value);
  }

  factory CloudDriveOAuthSession.fromJson(Map<String, dynamic> json) {
    if (json.keys.toSet().difference(_schemaKeys).isNotEmpty ||
        _schemaKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('OAuth session schema mismatch');
    }
    if (json['schemaVersion'] != schemaVersion ||
        json['provider'] is! String ||
        json['accountId'] is! String ||
        json['displayIdentifier'] is! String ||
        json['accessToken'] is! String ||
        (json['refreshToken'] != null && json['refreshToken'] is! String) ||
        json['expiresAt'] is! String) {
      throw const FormatException('OAuth session field type mismatch');
    }
    final expiry = DateTime.tryParse(json['expiresAt'] as String);
    if (expiry == null || !expiry.isUtc) {
      throw const FormatException('OAuth expiry must be an ISO-8601 UTC value');
    }
    final refreshToken = json['refreshToken'] as String?;
    if (refreshToken != null && refreshToken.isEmpty) {
      throw const FormatException(
        'OAuth refresh token must be null or non-empty',
      );
    }
    try {
      return CloudDriveOAuthSession(
        provider: CloudDriveOAuthProvider.parse(json['provider'] as String),
        accountId: json['accountId'] as String,
        displayIdentifier: json['displayIdentifier'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: refreshToken,
        expiresAt: expiry,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid OAuth session value', error);
    }
  }

  @override
  String toString() =>
      'CloudDriveOAuthSession(provider: ${provider.id}, accountId: $accountId, '
      'displayIdentifier: $displayIdentifier, expiresAt: $expiresAt, '
      'hasRefreshToken: ${refreshToken != null})';
}
