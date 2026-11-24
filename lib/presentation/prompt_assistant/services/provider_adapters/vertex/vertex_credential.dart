import 'dart:convert';

import 'package:crypto/crypto.dart';

const _defaultUniverseDomain = 'googleapis.com';
const _defaultTokenUri = 'https://oauth2.googleapis.com/token';

/// 安全存储里保存的 Vertex 凭据：服务账号 JSON、gcloud ADC JSON 或 API Key。
sealed class VertexCredential {
  const VertexCredential();

  /// 解析失败抛 [VertexCredentialFormatException]，消息不含凭据内容。
  factory VertexCredential.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const VertexCredentialFormatException(
        'Credential is not configured',
      );
    }
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      if (RegExp(r'\s').hasMatch(trimmed)) {
        throw const VertexCredentialFormatException(
          'API key must not contain whitespace',
        );
      }
      // 会原样写进请求头，只接受可打印 ASCII。
      if (!RegExp(r'^[\x21-\x7E]+$').hasMatch(trimmed)) {
        throw const VertexCredentialFormatException(
          'API key contains unsupported characters',
        );
      }
      return VertexApiKeyCredential(trimmed);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw const VertexCredentialFormatException(
        'Credential JSON is malformed',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const VertexCredentialFormatException(
        'Credential JSON must be an object',
      );
    }
    return switch (decoded['type']) {
      'service_account' => VertexServiceAccountCredential._fromJson(decoded),
      'authorized_user' => VertexAuthorizedUserCredential._fromJson(decoded),
      final Object? type => throw VertexCredentialFormatException(
        'Unsupported credential type: ${type ?? 'missing'}; '
        'expected service_account or authorized_user',
      ),
    };
  }

  /// 凭据自带的项目，作为未填写项目 ID 时的默认值。
  String? get projectId;

  String get universeDomain;
}

final class VertexApiKeyCredential extends VertexCredential {
  const VertexApiKeyCredential(this.apiKey);

  final String apiKey;

  @override
  String? get projectId => null;

  @override
  String get universeDomain => _defaultUniverseDomain;
}

/// 需要换取 OAuth 访问令牌的凭据。
sealed class VertexOAuthCredential extends VertexCredential {
  const VertexOAuthCredential({
    required this.tokenUri,
    required this.universeDomain,
  });

  final Uri tokenUri;

  @override
  final String universeDomain;

  /// 访问令牌缓存键；只含摘要，不保留明文密钥。
  String get cacheKey;
}

final class VertexServiceAccountCredential extends VertexOAuthCredential {
  const VertexServiceAccountCredential({
    required this.clientEmail,
    required this.privateKeyPem,
    required this.privateKeyId,
    required this.projectId,
    required super.tokenUri,
    required super.universeDomain,
  });

  factory VertexServiceAccountCredential._fromJson(Map<String, dynamic> json) {
    final universe = _universeDomain(json);
    return VertexServiceAccountCredential(
      clientEmail: _requiredString(json, 'client_email'),
      privateKeyPem: _requiredString(json, 'private_key'),
      privateKeyId: _optionalString(json, 'private_key_id'),
      projectId: _optionalString(json, 'project_id'),
      tokenUri: _tokenUri(json, universe),
      universeDomain: universe,
    );
  }

  final String clientEmail;
  final String privateKeyPem;
  final String? privateKeyId;

  @override
  final String? projectId;

  @override
  String get cacheKey => 'sa:${_digest('$clientEmail\n$privateKeyPem')}';
}

final class VertexAuthorizedUserCredential extends VertexOAuthCredential {
  const VertexAuthorizedUserCredential({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.quotaProjectId,
    required super.tokenUri,
    required super.universeDomain,
  });

  factory VertexAuthorizedUserCredential._fromJson(Map<String, dynamic> json) {
    final universe = _universeDomain(json);
    return VertexAuthorizedUserCredential(
      clientId: _requiredString(json, 'client_id'),
      clientSecret: _requiredString(json, 'client_secret'),
      refreshToken: _requiredString(json, 'refresh_token'),
      quotaProjectId: _optionalString(json, 'quota_project_id'),
      tokenUri: Uri.parse(_defaultTokenUri),
      universeDomain: universe,
    );
  }

  final String clientId;
  final String clientSecret;
  final String refreshToken;
  final String? quotaProjectId;

  @override
  String? get projectId => quotaProjectId;

  @override
  String get cacheKey => 'user:${_digest('$clientId\n$refreshToken')}';
}

class VertexCredentialFormatException implements Exception {
  const VertexCredentialFormatException(this.message);

  final String message;

  @override
  String toString() => 'Invalid Vertex AI credential: $message';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) {
    throw VertexCredentialFormatException('Missing field "$key"');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _universeDomain(Map<String, dynamic> json) {
  final value = _optionalString(json, 'universe_domain');
  if (value == null) return _defaultUniverseDomain;
  if (!RegExp(r'^[a-z0-9]+([.-][a-z0-9]+)*\.[a-z]{2,}$').hasMatch(value)) {
    throw const VertexCredentialFormatException('Invalid universe_domain');
  }
  return value;
}

/// 签名断言只发往该 universe 下的 HTTPS 令牌端点，避免被篡改的文件把它带走。
Uri _tokenUri(Map<String, dynamic> json, String universe) {
  final raw = _optionalString(json, 'token_uri') ?? _defaultTokenUri;
  final uri = Uri.tryParse(raw);
  final host = uri?.host.toLowerCase() ?? '';
  if (uri == null ||
      uri.scheme != 'https' ||
      !(host == universe || host.endsWith('.$universe'))) {
    throw const VertexCredentialFormatException(
      'token_uri must be an HTTPS endpoint of the credential universe',
    );
  }
  return uri;
}

String _digest(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 32);
