import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';

part 'nai_auth_api_service.g.dart';

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
  Future<Map<String, dynamic>> validateToken(String token) async {
    final trimmedToken = token.trim();
    final unquotedToken = _stripWrappingQuotes(trimmedToken);
    final normalizedToken = unquotedToken
        .replaceFirst(_bearerPrefixRegex, '')
        .replaceAll(_allWhitespaceRegex, '');

    if (normalizedToken.isEmpty) {
      throw ArgumentError('Token 为空，无法验证');
    }

    if (!_isSupportedTokenFormat(normalizedToken)) {
      throw ArgumentError('Token 格式无效');
    }

    final authHeader = normalizedToken.startsWith('pst-')
        ? normalizedToken
        : 'Bearer $normalizedToken';

    AppLogger.d(
      'Validating API token, length: ${normalizedToken.length}',
      'NAIAuth',
    );

    final response = await _dio.get(
      '${ApiConstants.baseUrl}${ApiConstants.userSubscriptionEndpoint}',
      options: Options(
        headers: {'Authorization': authHeader},
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
      ),
    );

    return response.data as Map<String, dynamic>;
  }

  /// 使用 Access Key 登录
  Future<Map<String, dynamic>> loginWithKey(String accessKey) async {
    AppLogger.d('Attempting login with access key', 'NAIAuth');

    final response = await _dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}',
      data: {'key': accessKey},
      options: Options(
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
      ),
    );

    return response.data as Map<String, dynamic>;
  }

  /// 检查 Token 格式是否有效 (pst-xxxx)
  static bool isValidTokenFormat(String token) {
    return token.startsWith('pst-') && token.length > 10;
  }

  String _stripWrappingQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') ||
          (first == '\'' && last == '\'')) {
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
