import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/services/token_refresh_service.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/locale_provider.dart';
import '../../presentation/providers/proxy_settings_provider.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';
import 'dio_error_response_parser.dart';

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
  dio.interceptors.add(ErrorInterceptor(ref));

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
      ConnectionManager(idleTimeout: const Duration(seconds: 15)),
    );
  }

  // 注意：不要在 dispose 时关闭 Dio，因为 Provider 可能会被重建
  // ref.onDispose(dio.close);

  return dio;
}

/// 图像生成专用 Dio Provider
///
/// 始终使用默认 HTTP/1.1 适配器，不用 HTTP/2：
/// Http2Adapter 在响应到达前取消请求时不会终止 HTTP/2 流
/// （上游在 2.5.2 移除了 client stream termination），
/// NovelAI 收不到中止信号会继续生成并占用账号并发额度，
/// 导致取消后的新请求全部立即 429。
/// 默认适配器通过 HttpClientRequest.abort() 在任意阶段真正中断请求。
@Riverpod(keepAlive: true)
Dio imageGenerationDioClient(Ref ref) {
  // 监听代理设置变化触发重建：默认适配器在创建 HttpClient 时
  // 才读取 HttpOverrides.global，代理变更后需要新实例
  ref.watch(currentProxyAddressProvider);

  final dio = Dio(
    BaseOptions(
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: ApiConstants.defaultHeaders,
    ),
  );

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(ErrorInterceptor(ref));

  AppLogger.d(
    'Image generation Dio using HTTP/1.1 adapter (abortable)',
    'NETWORK',
  );

  return dio;
}

/// 认证拦截器 - 自动添加 Bearer Token 并支持 401 自动刷新
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  /// 是否正在刷新中（防止并发刷新）
  bool _isRefreshing = false;

  static final RegExp _bearerPrefixRegex = RegExp(
    r'^Bearer\s+',
    caseSensitive: false,
  );
  static final RegExp _allWhitespaceRegex = RegExp(r'\s+');

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
      // 规范化并确保使用 Bearer 前缀
      final normalizedExisting = _normalizeToken(existingAuth.toString());
      final authHeader = 'Bearer $normalizedExisting';
      options.headers['Authorization'] = authHeader;
      AppLogger.d(
        'Using existing auth header: normalized_length=${normalizedExisting.length}',
        'DIO',
      );
      handler.next(options);
      return;
    }

    // 获取存储的 Token
    final storage = _ref.read(secureStorageServiceProvider);
    final token = await storage.getAccessToken();

    if (token != null && token.isNotEmpty) {
      final normalizedToken = _normalizeToken(token);
      if (normalizedToken.isEmpty) {
        AppLogger.w('Stored token is empty after normalization', 'DIO');
        handler.next(options);
        return;
      }

      // 所有 token 都使用 Bearer 前缀（与 NAI-Generator-Flutter 保持一致）
      final authHeader = 'Bearer $normalizedToken';

      options.headers['Authorization'] = authHeader;
      AppLogger.d(
        'Added auth header from storage, token length: ${normalizedToken.length}',
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
          final tokenRefreshService = _ref.read(
            tokenRefreshServiceProvider.notifier,
          );
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
              final normalizedToken = _normalizeToken(newToken);

              if (normalizedToken.isEmpty) {
                _isRefreshing = false;
                handler.next(err);
                return;
              }

              // 更新请求头（统一使用 Bearer 前缀）
              err.requestOptions.headers['Authorization'] =
                  'Bearer $normalizedToken';

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
        await _ref
            .read(authNotifierProvider.notifier)
            .logout(errorCode: AuthErrorCode.authFailed, httpStatusCode: 401);
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
}

/// 错误处理拦截器
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor(this._ref);

  final Ref _ref;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message =
        'DIO Error: ${err.type.name}\n'
        'Status: ${err.response?.statusCode}\n'
        'URL: ${err.requestOptions.uri}\n'
        'Response Data: ${formatDioErrorResponseDataForLog(err.response?.data)}';

    // 非致命网络抖动降级为 warning，避免错误日志噪音
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.cancel) {
      AppLogger.w(message, 'DIO');
    } else {
      AppLogger.e(message, null, null, 'DIO');
    }

    // 统一错误处理
    final error = _mapError(err);
    handler.next(error);
  }

  DioException _mapError(DioException err) {
    final l10n = lookupAppLocalizations(_ref.read(localeNotifierProvider));
    final message = switch (err.type) {
      DioExceptionType.connectionTimeout => l10n.networkError_connectionTimeout,
      DioExceptionType.sendTimeout => l10n.networkError_sendTimeout,
      DioExceptionType.receiveTimeout => l10n.networkError_receiveTimeout,
      DioExceptionType.badResponse => _parseResponseError(err.response, l10n),
      DioExceptionType.cancel => l10n.networkError_requestCancelled,
      DioExceptionType.connectionError => l10n.networkError_connection,
      _ => err.message ?? l10n.networkError_unknown,
    };

    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: err.error,
      message: message,
    );
  }

  String _parseResponseError(Response? response, AppLocalizations l10n) {
    if (response == null) return l10n.networkError_noResponse;

    // 生成接口使用 bytes/stream 响应类型，失败时 JSON 错误体也可能以
    // Uint8List 返回。先还原服务端信息，避免把具体原因降级成“请求参数错误”。
    final responseDetails = parseDioErrorResponseDetails(response.data);
    if (responseDetails != null) return responseDetails;

    // 根据状态码返回错误信息
    return switch (response.statusCode) {
      400 => l10n.networkError_badRequest,
      401 => l10n.networkError_authFailed,
      402 => l10n.networkError_insufficientAnlas,
      403 => l10n.networkError_forbidden,
      404 => l10n.networkError_notFound,
      409 => l10n.networkError_conflict,
      429 => l10n.networkError_rateLimited,
      500 => l10n.networkError_serverInternal,
      502 => l10n.networkError_badGateway,
      503 => l10n.networkError_unavailable,
      final code => l10n.networkError_requestFailed(code ?? 0),
    };
  }
}
