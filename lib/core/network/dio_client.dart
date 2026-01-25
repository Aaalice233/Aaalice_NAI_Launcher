import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../presentation/providers/auth_provider.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

part 'dio_client.g.dart';

/// Dio 客户端 Provider
@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: ApiConstants.defaultHeaders,
    ),
  );

  // 添加认证拦截器
  dio.interceptors.add(AuthInterceptor(ref));

  // 添加错误处理拦截器
  dio.interceptors.add(ErrorInterceptor());

  // 配置 HTTP/2 适配器以支持多路复用（提升并发性能）
  dio.httpClientAdapter = Http2Adapter(
    ConnectionManager(
      idleTimeout: const Duration(seconds: 15),
      // 忽略证书验证（仅用于开发环境，Danbooru 使用有效证书）
      // onBadCertificate: (_) => true,
    ),
  );

  // 注意：不要在 dispose 时关闭 Dio，因为 Provider 可能会被重建
  // ref.onDispose(dio.close);

  return dio;
}

/// 认证拦截器 - 自动添加 Bearer Token
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    AppLogger.d('Request to: ${options.path}', 'DIO');

    // 登录接口不需要 Token
    if (options.path.contains('/user/login')) {
      AppLogger.d('Skipping auth for login endpoint', 'DIO');
      handler.next(options);
      return;
    }

    // 检查请求是否已经有 Authorization header（如 validateToken 自己设置的）
    final existingAuth = options.headers['Authorization'];
    if (existingAuth != null && existingAuth.toString().isNotEmpty) {
      AppLogger.d('Using existing auth header', 'DIO');
      handler.next(options);
      return;
    }

    // 获取存储的 Token
    final storage = _ref.read(secureStorageServiceProvider);
    final token = await storage.getAccessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      AppLogger.d(
        'Added auth header from storage, token length: ${token.length}',
        'DIO',
      );
    } else {
      AppLogger.w(
        'No token available for request! Token is ${token == null ? "null" : "empty"}',
        'DIO',
      );
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Token 过期处理
    if (err.response?.statusCode == 401) {
      AppLogger.w(
        '[AuthInterceptor] onError: 401 received, path: ${err.requestOptions.path}',
        'DIO',
      );

      final authState = _ref.read(authNotifierProvider);
      AppLogger.w(
        '[AuthInterceptor] current authState: status=${authState.status}, isAuthenticated=${authState.isAuthenticated}, hasError=${authState.hasError}',
        'DIO',
      );

      // 只有在当前是已登录状态时才触发登出逻辑，避免并发请求导致多次重定向
      if (authState.isAuthenticated) {
        AppLogger.w(
          '[AuthInterceptor] Calling logout with error code...',
          'DIO',
        );
        await _ref.read(authNotifierProvider.notifier).logout(
              errorCode: AuthErrorCode.authFailed,
              httpStatusCode: 401,
            );
        AppLogger.w('[AuthInterceptor] logout() completed', 'DIO');
      } else {
        AppLogger.w(
          '[AuthInterceptor] Skipping logout because not authenticated',
          'DIO',
        );
      }
    }

    handler.next(err);
  }
}

/// 错误处理拦截器
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 详细记录错误信息
    AppLogger.e(
      'DIO Error: ${err.type.name}\n'
          'Status: ${err.response?.statusCode}\n'
          'URL: ${err.requestOptions.uri}\n'
          'Response Data: ${err.response?.data}',
      'DIO',
    );

    // 统一错误处理
    final error = _mapError(err);
    handler.next(error);
  }

  DioException _mapError(DioException err) {
    String message;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        message = '连接超时，请检查网络';
        break;
      case DioExceptionType.sendTimeout:
        message = '发送超时，请重试';
        break;
      case DioExceptionType.receiveTimeout:
        message = '接收超时，图像生成可能需要较长时间';
        break;
      case DioExceptionType.badResponse:
        message = _parseResponseError(err.response);
        break;
      case DioExceptionType.cancel:
        message = '请求已取消';
        break;
      case DioExceptionType.connectionError:
        message = '网络连接错误，请检查网络';
        break;
      default:
        message = err.message ?? '未知错误';
    }

    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: err.error,
      message: message,
    );
  }

  String _parseResponseError(Response? response) {
    if (response == null) return '服务器无响应';

    final statusCode = response.statusCode;
    final data = response.data;

    // 尝试从响应中提取错误信息
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
      if (message != null) return message.toString();
    }

    // 根据状态码返回错误信息
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '认证失败，请重新登录';
      case 402:
        return 'Anlas 不足';
      case 403:
        return '无权限访问';
      case 404:
        return '资源不存在';
      case 409:
        return '请求冲突';
      case 429:
        return '请求过于频繁，请稍后重试';
      case 500:
        return '服务器内部错误';
      case 502:
        return '服务器网关错误';
      case 503:
        return '服务暂时不可用';
      default:
        return '请求失败 ($statusCode)';
    }
  }
}
