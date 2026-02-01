import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/services/token_refresh_service.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/proxy_settings_provider.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

part 'dio_client.g.dart';

/// Dio 客户端 Provider
///
/// 根据代理设置动态选择 HTTP 适配器：
/// - 有代理时：使用默认 HTTP/1.1 适配器（配合 HttpOverrides.global 使用代理）
/// - 无代理时：使用 HTTP/2 适配器（提升并发性能）
@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  // 监听代理设置变化，当代理设置改变时会触发 Dio 重建
  final proxyAddress = ref.watch(currentProxyAddressProvider);

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

  // 根据代理设置选择适配器
  if (proxyAddress != null && proxyAddress.isNotEmpty) {
    // 有代理时：使用默认 HTTP/1.1 适配器
    // 默认适配器内部使用 dart:io.HttpClient，会自动遵循 HttpOverrides.global
    AppLogger.i('Dio using proxy: $proxyAddress (HTTP/1.1 adapter)', 'NETWORK');
    // 不设置 httpClientAdapter，使用默认值
  } else {
    // 无代理时：使用 HTTP/2 适配器以提升并发性能
    AppLogger.d('Dio using HTTP/2 adapter (no proxy)', 'NETWORK');
    dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 15),
      ),
    );
  }

  // 注意：不要在 dispose 时关闭 Dio，因为 Provider 可能会被重建
  // ref.onDispose(dio.close);

  return dio;
}

/// 认证拦截器 - 自动添加 Bearer Token 并支持 401 自动刷新
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  /// 是否正在刷新中（防止并发刷新）
  bool _isRefreshing = false;

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
      // 如果是登录请求失败，不要尝试刷新 token 或登出
      // 登录失败是预期的（密码错误等），不应影响当前的全局认证状态
      if (err.requestOptions.path.contains(ApiConstants.loginEndpoint)) {
        AppLogger.w(
          '[AuthInterceptor] Ignoring 401 from login endpoint',
          'DIO',
        );
        handler.next(err);
        return;
      }

      AppLogger.w(
        '[AuthInterceptor] onError: 401 received, path: ${err.requestOptions.path}',
        'DIO',
      );

      final authState = _ref.read(authNotifierProvider);
      AppLogger.w(
        '[AuthInterceptor] current authState: status=${authState.status}, isAuthenticated=${authState.isAuthenticated}, hasError=${authState.hasError}',
        'DIO',
      );

      // 只有在已登录状态且未在刷新中时才尝试刷新
      if (authState.isAuthenticated && !_isRefreshing) {
        _isRefreshing = true;

        try {
          // 尝试刷新 token
          AppLogger.d('[AuthInterceptor] Attempting token refresh...', 'DIO');
          final tokenRefreshService =
              _ref.read(tokenRefreshServiceProvider.notifier);
          final refreshed = await tokenRefreshService.refreshCurrentToken();

          if (refreshed) {
            AppLogger.d(
              '[AuthInterceptor] Token refreshed, retrying request',
              'DIO',
            );

            // 获取新 token 并重试请求
            final storage = _ref.read(secureStorageServiceProvider);
            final newToken = await storage.getAccessToken();

            if (newToken != null && newToken.isNotEmpty) {
              // 更新请求头
              err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

              try {
                // 创建新的 Dio 实例来重试，避免循环
                final retryDio = Dio();
                final response = await retryDio.fetch(err.requestOptions);
                _isRefreshing = false;
                handler.resolve(response);
                return;
              } catch (retryError) {
                AppLogger.e(
                  '[AuthInterceptor] Retry request failed: $retryError',
                  retryError,
                  null,
                  'DIO',
                );
              }
            }
          } else {
            AppLogger.w(
              '[AuthInterceptor] Token refresh returned false',
              'DIO',
            );
          }
        } catch (e) {
          AppLogger.e(
            '[AuthInterceptor] Token refresh error: $e',
            e,
            null,
            'DIO',
          );
        } finally {
          _isRefreshing = false;
        }

        // 刷新失败，执行登出
        AppLogger.w(
          '[AuthInterceptor] Token refresh failed, logging out...',
          'DIO',
        );
        await _ref.read(authNotifierProvider.notifier).logout(
              errorCode: AuthErrorCode.authFailed,
              httpStatusCode: 401,
            );
        AppLogger.w('[AuthInterceptor] logout() completed', 'DIO');
      } else if (_isRefreshing) {
        AppLogger.w(
          '[AuthInterceptor] Skipping because already refreshing',
          'DIO',
        );
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
