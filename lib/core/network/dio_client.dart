import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/services/token_refresh_service.dart';
import '../../l10n/app_localizations.dart';
import '../../data/services/auth_provider.dart';
import '../services/auth_error_service.dart';
import '../utils/locale_provider.dart';
import 'proxy_settings_provider.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';
import 'browser_identity/accept_language.dart';
import 'browser_identity/browser_headers_interceptor.dart';
import 'browser_identity/chrome_identity.dart';
import 'dio_error_response_parser.dart';
import 'js_compatible_json.dart';

part 'dio_client.g.dart';

/// 让请求形态对齐 Chrome 上的官网前端。
BrowserHeadersInterceptor _browserHeadersInterceptor(Ref ref) {
  return BrowserHeadersInterceptor(
    identity: ChromeIdentity.current(),
    resolveAcceptLanguage: () =>
        acceptLanguageForLocale(ref.read(localeNotifierProvider)),
  );
}

/// 所有 NAI 兼容请求共用的 HTTP/1.1 客户端。
///
/// 默认适配器兼容第三方 HTTPS 的 ALPN 和本地明文 HTTP，
/// 并通过 HttpClientRequest.abort() 真正中断生成请求。
/// 不使用 Http2Adapter，避免协议回退缺口及取消后仍占用生成额度。
@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  // 路由会即时更新；设置变化时也重建客户端，避免继续复用旧连接池。
  final proxyAddress = ref.watch(currentProxyAddressProvider);

  final dio = Dio(
    BaseOptions(
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: ApiConstants.defaultHeaders,
    ),
  );

  dio.transformer = JsCompatibleJsonTransformer();

  // 添加认证拦截器
  dio.interceptors.add(AuthInterceptor(ref));

  dio.interceptors.add(_browserHeadersInterceptor(ref));

  // 添加错误处理拦截器
  dio.interceptors.add(ErrorInterceptor(ref));

  final route = proxyAddress != null && proxyAddress.isNotEmpty
      ? 'proxy: $proxyAddress'
      : 'direct';
  AppLogger.d('Dio using HTTP/1.1 adapter ($route)', 'NETWORK');

  // 注意：不要在 dispose 时关闭 Dio，因为 Provider 可能会被重建
  // ref.onDispose(dio.close);

  return dio;
}

/// 认证拦截器 - 自动添加 Bearer Token 并支持 401 自动刷新
class AuthInterceptor extends Interceptor {
  final Ref _ref;

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
    // 登录失败不参与刷新，避免刷新登录自身的 401 递归或影响未登录状态。
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains(ApiConstants.loginEndpoint) ||
        !_ref.read(authNotifierProvider).isAuthenticated) {
      handler.next(err);
      return;
    }

    final storage = _ref.read(secureStorageServiceProvider);
    try {
      final sessionToken = await storage.getAccessToken();
      if (!_wasSentWithSessionToken(err.requestOptions, sessionToken)) {
        AppLogger.w(
          '[AuthInterceptor] 401 belongs to a previous session, ignoring',
          'DIO',
        );
        handler.next(err);
        return;
      }

      // 服务共享进行中的刷新；每个 401 都等待结果并重试自己的请求。
      final outcome = await _ref
          .read(tokenRefreshServiceProvider.notifier)
          .refreshCurrentToken();
      if (outcome == TokenRefreshOutcome.sessionChanged) {
        handler.next(err);
        return;
      }
      if (outcome == TokenRefreshOutcome.refreshed) {
        final newToken = await storage.getAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          final normalizedToken = _normalizeToken(newToken);
          if (normalizedToken.isEmpty) {
            handler.next(err);
            return;
          }
          err.requestOptions.headers['Authorization'] =
              'Bearer $normalizedToken';
          final response = await _retryRequest(err.requestOptions);
          handler.resolve(response);
          return;
        }
      }
    } catch (e) {
      AppLogger.e(
        '[AuthInterceptor] Token refresh/retry failed: $e',
        e,
        null,
        'DIO',
      );
    }

    // 刷新期间会话可能已被退出或切换，登出只能作用于发出这个请求的会话。
    final latestSessionToken = await storage.getAccessToken();
    if (_wasSentWithSessionToken(err.requestOptions, latestSessionToken)) {
      AppLogger.w(
        '[AuthInterceptor] Token refresh failed, logging out...',
        'DIO',
      );
      await _ref
          .read(authNotifierProvider.notifier)
          .logout(errorCode: AuthErrorCode.authFailed, httpStatusCode: 401);
    }
    handler.next(err);
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions options) async {
    // 重试不再经过认证拦截器，防止持续 401 时循环刷新。
    final retryDio = Dio()..transformer = JsCompatibleJsonTransformer();
    try {
      return await retryDio.fetch<dynamic>(options);
    } finally {
      retryDio.close();
    }
  }

  /// 401 只说明请求当时携带的 token 失效；会话已换成别的 token 时不能据此刷新或登出
  bool _wasSentWithSessionToken(RequestOptions options, String? sessionToken) {
    final sent = options.headers['Authorization']?.toString();
    if (sent == null || sessionToken == null) return false;
    final normalizedSession = _normalizeToken(sessionToken);
    return normalizedSession.isNotEmpty &&
        _normalizeToken(sent) == normalizedSession;
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
