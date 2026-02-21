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

    // 详细的日志记录用于诊断登录问题
    final tokenFormat = normalizedToken.startsWith('pst-') ? 'pst' : 'jwt';
    final prefix = normalizedToken.startsWith('pst-') 
        ? normalizedToken.substring(0, normalizedToken.length > 10 ? 10 : normalizedToken.length)
        : normalizedToken.substring(0, normalizedToken.length > 20 ? 20 : normalizedToken.length);
    AppLogger.i(
      'Validating token: format=$tokenFormat, length=${normalizedToken.length}, prefix=$prefix...',
      'NAIAuth',
    );

    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.userSubscriptionEndpoint}',
        options: Options(
          headers: {'Authorization': authHeader},
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      AppLogger.i('Token validation successful', 'NAIAuth');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final responseData = e.response?.data;
        final message = responseData is Map ? responseData['message'] : null;
        AppLogger.e(
          'Token validation failed (400): $message, authHeader format=$tokenFormat',
          'NAIAuth',
        );
        // 添加更详细的错误信息
        if (message?.toString().contains('Invalid Authorization header') ?? false) {
          throw DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: 'Token无效或已过期，请检查Token是否正确。'
                '如果是Persistent Token，应以pst-开头。',
          );
        }
      }
      rethrow;
    }
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
