import 'package:dio/dio.dart';

import 'vertex_credential.dart';
import 'vertex_jwt_assertion.dart';

/// 进程内的 Vertex 访问令牌缓存；同一凭据的并发请求共用一次换取。
class VertexAccessTokens {
  VertexAccessTokens({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final shared = VertexAccessTokens();

  static const scope = 'https://www.googleapis.com/auth/cloud-platform';

  /// 提前刷新，避免长请求中途令牌过期。
  static const refreshMargin = Duration(minutes: 5);

  final DateTime Function() _clock;
  final Map<String, _AccessToken> _tokens = {};
  final Map<String, Future<_AccessToken>> _pending = {};
  final Map<String, VertexJwtAssertionSigner> _signers = {};

  /// 不接受调用方的 CancelToken：换取结果由所有等待者共享。
  Future<String> accessToken(Dio dio, VertexOAuthCredential credential) async {
    final key = credential.cacheKey;
    final cached = _tokens[key];
    if (cached != null &&
        cached.expiresAt.isAfter(_clock().add(refreshMargin))) {
      return cached.value;
    }
    // 回调不能返回 remove 的结果：那正是本 Future，whenComplete 会等它自己而死锁。
    final pending = _pending[key] ??= _exchange(dio, credential).whenComplete(
      () {
        _pending.remove(key);
      },
    );
    return (await pending).value;
  }

  /// Vertex 返回 401 时调用，令牌可能已被吊销。
  void invalidate(VertexOAuthCredential credential) {
    _tokens.remove(credential.cacheKey);
  }

  Future<_AccessToken> _exchange(
    Dio dio,
    VertexOAuthCredential credential,
  ) async {
    final issuedAt = _clock();
    final form = switch (credential) {
      VertexServiceAccountCredential() => {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': _signerFor(
          credential,
        ).sign(issuedAt: issuedAt, scope: scope),
      },
      VertexAuthorizedUserCredential() => {
        'grant_type': 'refresh_token',
        'client_id': credential.clientId,
        'client_secret': credential.clientSecret,
        'refresh_token': credential.refreshToken,
      },
    };
    final Response<dynamic> response;
    try {
      response = await dio.postUri<dynamic>(
        credential.tokenUri,
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // 4xx 是凭据本身的问题，重试无意义；429、网络错误与 5xx 原样抛出交给重试判定。
      if (status != null && status >= 400 && status < 500 && status != 429) {
        throw VertexAuthException.fromTokenEndpoint(
          status,
          error.response?.data,
        );
      }
      rethrow;
    }
    final data = response.data;
    final value = data is Map ? data['access_token'] : null;
    if (value is! String || value.isEmpty) {
      throw const VertexAuthException(
        'Token endpoint response has no access_token',
      );
    }
    final expiresIn = data is Map ? data['expires_in'] : null;
    final token = _AccessToken(
      value,
      issuedAt.add(
        Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600),
      ),
    );
    _tokens[credential.cacheKey] = token;
    return token;
  }

  VertexJwtAssertionSigner _signerFor(
    VertexServiceAccountCredential credential,
  ) => _signers[credential.cacheKey] ??= VertexJwtAssertionSigner(credential);
}

class VertexAuthException implements Exception {
  const VertexAuthException(this.message);

  /// 只取 OAuth 错误码与说明，响应里不会回显请求中的密钥。
  factory VertexAuthException.fromTokenEndpoint(int status, Object? body) {
    final detail = switch (body) {
      {'error': final String error} => [
        error,
        if (body['error_description'] case final String description
            when description.isNotEmpty)
          description,
      ].join(': '),
      final String text when text.trim().isNotEmpty => text.trim(),
      _ => null,
    };
    return VertexAuthException(
      'HTTP $status${detail == null ? '' : ': $detail'}',
    );
  }

  final String message;

  @override
  String toString() => 'Vertex AI authentication failed: $message';
}

class _AccessToken {
  const _AccessToken(this.value, this.expiresAt);

  final String value;
  final DateTime expiresAt;
}
