import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';

part 'nai_auth_api_service.g.dart';

/// NovelAI Authentication API 服务
///
/// 提供 NovelAI 用户认证功能
/// - Token 验证
/// - Access Key 登录
/// - Token 格式验证
class NAIAuthApiService {
  // ==================== 配置 ====================
  static const Duration _timeout = Duration(seconds: 30);

  final Dio _dio;

  NAIAuthApiService(this._dio);

  // ==================== 认证 API ====================

  /// 验证 API Token 是否有效
  ///
  /// [token] Persistent API Token (格式: pst-xxxx)
  ///
  /// 返回验证结果，包含订阅信息；如果 Token 无效则抛出异常
  Future<Map<String, dynamic>> validateToken(String token) async {
    try {
      AppLogger.d('Validating API token', 'NAIAuth');

      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.userSubscriptionEndpoint}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      AppLogger.d('Token validation successful', 'NAIAuth');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('Token validation request timeout', 'NAIAuth');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w('Token validation connection error: ${e.message}', 'NAIAuth');
      } else if (e.response?.statusCode == 401) {
        AppLogger.w('Token validation failed: Invalid token', 'NAIAuth');
      } else {
        AppLogger.e('Token validation error: ${e.message}', e, null, 'NAIAuth');
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Token validation failed', e, stack, 'NAIAuth');
      rethrow;
    }
  }

  /// 使用 Access Key 登录
  ///
  /// [accessKey] 通过邮箱+密码 Argon2哈希生成的 Access Key
  ///
  /// 返回登录结果，包含 accessToken；如果登录失败则抛出异常
  Future<Map<String, dynamic>> loginWithKey(String accessKey) async {
    try {
      AppLogger.d('Attempting login with access key', 'NAIAuth');

      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}',
        data: {'key': accessKey},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      AppLogger.d('Login successful, received access token', 'NAIAuth');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('Login request timeout', 'NAIAuth');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w('Login connection error: ${e.message}', 'NAIAuth');
      } else if (e.response?.statusCode == 401) {
        AppLogger.w('Login failed: Invalid credentials', 'NAIAuth');
      } else {
        AppLogger.e('Login error: ${e.message}', e, null, 'NAIAuth');
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Login failed', e, stack, 'NAIAuth');
      rethrow;
    }
  }

  /// 检查 Token 格式是否有效
  ///
  /// Persistent API Token 格式: pst-xxxx
  static bool isValidTokenFormat(String token) {
    return token.startsWith('pst-') && token.length > 10;
  }
}

/// NAIAuthApiService Provider
@Riverpod(keepAlive: true)
NAIAuthApiService naiAuthApiService(Ref ref) {
  // 使用全局 dioClient，确保代理配置正确应用
  final dio = ref.watch(dioClientProvider);
  return NAIAuthApiService(dio);
}
