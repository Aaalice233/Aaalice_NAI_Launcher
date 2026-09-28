import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/nai_api_endpoint.dart';
import '../../../core/utils/app_logger.dart';

part 'nai_auth_api_service.g.dart';

/// Token 验证结果。
///
/// 第三方 NAI 兼容站点普遍只实现生成端点而缺失 `/user/subscription`，
/// 此时 [subscriptionInfo] 为 null 且 [subscriptionUnsupported] 为 true。
class TokenValidationResult {
  final Map<String, dynamic>? subscriptionInfo;
  final bool subscriptionUnsupported;

  const TokenValidationResult.subscribed(Map<String, dynamic> info)
    : subscriptionInfo = info,
      subscriptionUnsupported = false;

  const TokenValidationResult.withoutSubscription()
    : subscriptionInfo = null,
      subscriptionUnsupported = true;
}

/// 第三方站点在所填地址下未暴露 NAI 兼容接口。
class NaiEndpointIncompatibleException implements Exception {
  final String probedUrl;
  final int? statusCode;

  const NaiEndpointIncompatibleException({
    required this.probedUrl,
    this.statusCode,
  });

  @override
  String toString() =>
      'NaiEndpointIncompatibleException(status: $statusCode, url: $probedUrl)';
}

/// NovelAI Authentication API 服务
class NAIAuthApiService {
  static const Duration _timeout = Duration(seconds: 30);
  static final RegExp _bearerPrefixRegex = RegExp(
    r'^Bearer\s+',
    caseSensitive: false,
  );
  static final RegExp _allWhitespaceRegex = RegExp(r'\s+');

  final Dio _dio;

  NAIAuthApiService(this._dio);

  /// 验证 API Token 是否有效
  ///
  /// 第三方端点缺失 `/user/subscription` 时改用生成端点做鉴权探测，
  /// 探测通过则返回无订阅信息的成功结果，登录不再因 404 失败。
  Future<TokenValidationResult> validateToken(
    String token, {
    NaiApiEndpointConfig endpoint = NaiApiEndpointConfig.official,
    bool allowAnyTokenFormat = false,
  }) async {
    final normalizedToken = _normalizeToken(token);

    if (normalizedToken.isEmpty) {
      throw ArgumentError('Token 为空，无法验证');
    }

    if (!allowAnyTokenFormat && !_isSupportedTokenFormat(normalizedToken)) {
      throw ArgumentError('Token 格式无效');
    }

    // 所有 token 都使用 Bearer 前缀（与 NAI-Generator-Flutter 保持一致）
    final authHeader = 'Bearer $normalizedToken';

    // 详细的日志记录用于诊断登录问题
    final tokenFormat = normalizedToken.startsWith('pst-') ? 'pst' : 'jwt';
    final prefix = normalizedToken.startsWith('pst-')
        ? normalizedToken.substring(
            0,
            normalizedToken.length > 10 ? 10 : normalizedToken.length,
          )
        : normalizedToken.substring(
            0,
            normalizedToken.length > 20 ? 20 : normalizedToken.length,
          );
    AppLogger.i(
      'Validating token: format=$tokenFormat, length=${normalizedToken.length}, prefix=$prefix...',
      'NAIAuth',
    );
    AppLogger.d(
      'Auth header prepared: length=${authHeader.length}, tokenFormat=$tokenFormat',
      'NAIAuth',
    );

    try {
      final response = await _dio.get(
        endpoint.userUrl(ApiConstants.userSubscriptionEndpoint),
        options: Options(
          headers: {'Authorization': authHeader},
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        // 站点把未知路径兜底成网页时会 200 返回 HTML，视同缺失订阅端点。
        if (endpoint.isThirdParty) {
          AppLogger.w(
            'Third-party /user/subscription returned non-JSON body, '
            'falling back to image endpoint probe',
            'NAIAuth',
          );
          return _probeThirdPartyImageAuth(endpoint, authHeader);
        }
        throw StateError(
          'Unexpected /user/subscription payload: ${data.runtimeType}',
        );
      }

      AppLogger.i('Token validation successful', 'NAIAuth');
      return TokenValidationResult.subscribed(data);
    } on DioException catch (e) {
      if (endpoint.isThirdParty && e.response?.statusCode == 404) {
        AppLogger.w(
          'Third-party site has no /user/subscription, '
          'falling back to image endpoint probe',
          'NAIAuth',
        );
        return _probeThirdPartyImageAuth(endpoint, authHeader);
      }
      if (e.response?.statusCode == 400) {
        final responseData = e.response?.data;
        final message = responseData is Map ? responseData['message'] : null;
        AppLogger.e(
          'Token validation failed (400): $message, authHeader format=$tokenFormat',
          'NAIAuth',
        );
        // 添加更详细的错误信息
        if (message?.toString().contains('Invalid Authorization header') ??
            false) {
          throw DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error:
                'Token无效或已过期，请检查Token是否正确。'
                '如果是Persistent Token，应以pst-开头。',
          );
        }
      }
      rethrow;
    }
  }

  /// 用生成端点对第三方 Token 做鉴权探测。
  ///
  /// 空请求体在鉴权通过后才会走到参数校验，不会真正生成：
  /// 401/403 说明 Key 无效，404/405 说明该地址下没有 NAI 兼容接口，
  /// 其余 4xx（参数校验类）与 2xx 都证明 Key 已被站点接受。
  Future<TokenValidationResult> _probeThirdPartyImageAuth(
    NaiApiEndpointConfig endpoint,
    String authHeader,
  ) async {
    final probeUrl = endpoint.imageUrl(ApiConstants.generateImageEndpoint);
    AppLogger.i('Probing third-party auth via $probeUrl', 'NAIAuth');

    final response = await _dio.post<dynamic>(
      probeUrl,
      data: const <String, dynamic>{},
      options: Options(
        headers: {'Authorization': authHeader},
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        validateStatus: (_) => true,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      AppLogger.w('Third-party auth probe rejected: $status', 'NAIAuth');
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Third-party token rejected by image endpoint probe',
      );
    }
    if (status >= 500) {
      AppLogger.w('Third-party auth probe server error: $status', 'NAIAuth');
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: 'Third-party image endpoint probe failed with $status',
      );
    }

    final routeExists =
        (status >= 200 && status < 300) ||
        (status >= 400 && status != 404 && status != 405);
    if (!routeExists) {
      AppLogger.w(
        'No NAI-compatible image endpoint at $probeUrl (status=$status)',
        'NAIAuth',
      );
      throw NaiEndpointIncompatibleException(
        probedUrl: probeUrl,
        statusCode: response.statusCode,
      );
    }

    AppLogger.i(
      'Third-party auth probe passed (status=$status), '
      'logging in without subscription info',
      'NAIAuth',
    );
    return const TokenValidationResult.withoutSubscription();
  }

  /// 使用 Access Key 登录
  Future<Map<String, dynamic>> loginWithKey(
    String accessKey, {
    NaiApiEndpointConfig endpoint = NaiApiEndpointConfig.official,
  }) async {
    AppLogger.d('Attempting login with access key', 'NAIAuth');

    final response = await _dio.post(
      endpoint.userUrl(ApiConstants.loginEndpoint),
      data: {'key': accessKey},
      options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
    );

    return response.data as Map<String, dynamic>;
  }

  /// 检查 Token 格式是否有效 (pst-xxxx)
  /// NovelAI Persistent Token 格式: pst- 前缀 + 64位十六进制字符
  static bool isValidTokenFormat(String token) {
    if (!token.startsWith('pst-')) return false;
    // pst- 前缀 (4字符) + 至少 10 字符的 token 内容
    if (token.length < 14) return false;
    // 检查是否包含非法字符（Persistent Token 应该是十六进制格式）
    final tokenBody = token.substring(4); // 去掉 'pst-'
    // 允许字母、数字、下划线和横线
    final validPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
    return validPattern.hasMatch(tokenBody);
  }

  String _normalizeToken(String token) {
    final trimmedToken = token.trim();
    final unquotedToken = _stripWrappingQuotes(trimmedToken);

    // 循环移除所有 Bearer 前缀（处理重复添加的情况）
    var normalizedToken = unquotedToken;
    var previousToken = '';
    while (normalizedToken != previousToken) {
      previousToken = normalizedToken;
      normalizedToken = normalizedToken
          .replaceFirst(_bearerPrefixRegex, '')
          .trim();
    }

    // 移除所有空白字符
    return normalizedToken.replaceAll(_allWhitespaceRegex, '');
  }

  String _stripWrappingQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  bool _isSupportedTokenFormat(String token) {
    if (token.startsWith('pst-')) {
      return token.length > 10;
    }

    // JWT 基础格式：header.payload.signature
    final parts = token.split('.');
    return parts.length == 3 &&
        parts.every((part) => part.isNotEmpty) &&
        !token.contains(' ');
  }
}

/// NAIAuthApiService Provider
@Riverpod(keepAlive: true)
NAIAuthApiService naiAuthApiService(Ref ref) {
  // 使用全局 dioClient，确保代理配置正确应用
  final dio = ref.watch(dioClientProvider);
  return NAIAuthApiService(dio);
}
