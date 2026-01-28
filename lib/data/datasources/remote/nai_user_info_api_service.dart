import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';

part 'nai_user_info_api_service.g.dart';

/// NovelAI User Info API 服务
///
/// 提供 NovelAI 用户订阅信息查询功能
/// - 获取用户订阅信息
/// - 查询 Anlas 余额
class NAIUserInfoApiService {
  // ==================== 配置 ====================
  static const Duration _timeout = Duration(seconds: 30);

  final Dio _dio;

  NAIUserInfoApiService(this._dio);

  // ==================== 用户信息 API ====================

  /// 获取用户订阅信息（包含 Anlas 余额）
  ///
  /// 返回订阅信息 Map，包含:
  /// - subscriptionType: 订阅类型
  /// - anlasBalance: Anlas 余额
  /// - trainingStepsLeft: 剩余训练步数
  /// - 等其他订阅相关信息
  ///
  /// 如果获取失败则抛出异常
  Future<Map<String, dynamic>> getUserSubscription() async {
    try {
      AppLogger.d('Fetching user subscription info', 'NAIUserInfo');

      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.userSubscriptionEndpoint}',
        options: Options(
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      AppLogger.d('User subscription info fetched successfully', 'NAIUserInfo');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        AppLogger.w('User subscription request timeout', 'NAIUserInfo');
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.w(
          'User subscription connection error: ${e.message}',
          'NAIUserInfo',
        );
      } else if (e.response?.statusCode == 401) {
        AppLogger.w('User subscription failed: Unauthorized', 'NAIUserInfo');
      } else {
        AppLogger.e(
            'User subscription error: ${e.message}', e, null, 'NAIUserInfo',);
      }
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Failed to get user subscription', e, stack, 'NAIUserInfo');
      rethrow;
    }
  }
}

/// NAIUserInfoApiService Provider
@Riverpod(keepAlive: true)
NAIUserInfoApiService naiUserInfoApiService(Ref ref) {
  // 使用全局 dioClient，它已经配置了 AuthInterceptor 来自动添加认证头
  final dio = ref.watch(dioClientProvider);
  return NAIUserInfoApiService(dio);
}
