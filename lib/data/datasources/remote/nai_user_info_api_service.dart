import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

part 'nai_user_info_api_service.g.dart';

/// NovelAI User Info API 服务
class NAIUserInfoApiService {
  static const Duration _timeout = Duration(seconds: 30);

  final Dio _dio;

  NAIUserInfoApiService(this._dio);

  /// 获取用户订阅信息（包含 Anlas 余额）
  Future<Map<String, dynamic>> getUserSubscription({
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}${ApiConstants.userSubscriptionEndpoint}',
      options: Options(
        receiveTimeout: receiveTimeout ?? _timeout,
        sendTimeout: sendTimeout ?? _timeout,
      ),
    );

    return response.data as Map<String, dynamic>;
  }
}

/// NAIUserInfoApiService Provider
@Riverpod(keepAlive: true)
NAIUserInfoApiService naiUserInfoApiService(Ref ref) {
  // 使用全局 dioClient，它已经配置了 AuthInterceptor 来自动添加认证头
  final dio = ref.watch(dioClientProvider);
  return NAIUserInfoApiService(dio);
}
