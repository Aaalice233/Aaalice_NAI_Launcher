import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/app_logger.dart';

/// 在线画廊重试拦截器
///
/// 专门用于在线画廊 API 请求，提供智能重试逻辑：
/// - 仅对 GET/HEAD 请求重试
/// - 连接错误、超时错误、429、5xx 错误时最多重试 2 次
/// - 支持 Retry-After 头部（秒数和 HTTP 日期格式）
/// - 401/403/404、解析错误、业务错误和主动取消不重试
/// - 重试等待期间可被原 CancelToken 立即中止
/// - 保留原始请求的所有配置，防止递归重试
class OnlineGalleryRetryInterceptor extends Interceptor {
  static const int _maxRetries = 2;
  static const String _attemptCountKey = '_retry_attempt_count';

  /// 延迟注入函数，用于测试
  final Future<void> Function(Duration duration, CancelToken? cancelToken)?
  _delayFn;

  /// 时钟注入函数，用于测试
  final DateTime Function()? _clockFn;

  /// 原始在线画廊客户端，重试必须保留其代理、Adapter 与拦截器配置。
  final Dio? _dio;

  /// HTTP 客户端工厂函数，用于测试注入
  final Dio Function()? _dioFactory;

  /// 构造函数
  ///
  /// [delayFn] - 延迟函数注入，用于测试
  /// [clockFn] - 时钟函数注入，用于测试
  /// [dioFactory] - Dio 实例工厂函数注入，用于测试
  OnlineGalleryRetryInterceptor({
    Dio? dio,
    Future<void> Function(Duration duration, CancelToken? cancelToken)? delayFn,
    DateTime Function()? clockFn,
    Dio Function()? dioFactory,
  }) : _dio = dio,
       _delayFn = delayFn,
       _clockFn = clockFn,
       _dioFactory = dioFactory;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    // 检查是否应该重试
    if (!_shouldRetry(err, options)) {
      handler.next(err);
      return;
    }

    final attemptCount = options.extra[_attemptCountKey] as int? ?? 0;
    final newAttemptCount = attemptCount + 1;

    AppLogger.d(
      'OnlineGalleryRetryInterceptor: Retrying request '
          '(attempt $newAttemptCount/$_maxRetries) to ${options.path}',
      'NETWORK',
    );

    // 计算重试延迟
    final delayDuration = _calculateRetryDelay(err.response, newAttemptCount);

    try {
      // 执行延迟，支持取消
      await _executeDelay(delayDuration, options.cancelToken);

      // 创建新的请求选项，防止递归
      final retryOptions = options.copyWith(
        extra: {...options.extra, _attemptCountKey: newAttemptCount},
      );

      // 执行重试请求
      final retryDio =
          _dioFactory?.call() ??
          _dio ??
          Dio(
            BaseOptions(
              connectTimeout: retryOptions.connectTimeout,
              receiveTimeout: retryOptions.receiveTimeout,
              sendTimeout: retryOptions.sendTimeout,
              headers: retryOptions.headers,
            ),
          );

      final response = await retryDio.fetch(retryOptions);
      handler.resolve(response);
    } on OperationCancelledError {
      // 延迟期间被取消
      AppLogger.d(
        'OnlineGalleryRetryInterceptor: Retry cancelled during delay for ${options.path}',
        'NETWORK',
      );
      handler.next(err);
    } catch (retryError) {
      // 重试请求失败
      if (retryError is DioException) {
        AppLogger.w(
          'OnlineGalleryRetryInterceptor: Retry failed for ${options.path}: ${retryError.type.name}',
          'NETWORK',
        );
        // 递归处理重试错误
        onError(retryError, handler);
      } else {
        AppLogger.e(
          'OnlineGalleryRetryInterceptor: Unexpected retry error for ${options.path}',
          retryError,
          null,
          'NETWORK',
        );
        handler.next(err);
      }
    }
  }

  /// 判断是否应该重试
  bool _shouldRetry(DioException err, RequestOptions options) {
    // 检查请求方法：仅 GET/HEAD 可重试
    if (!_isRetriableMethod(options.method)) {
      return false;
    }

    // 检查重试次数
    final attemptCount = options.extra[_attemptCountKey] as int? ?? 0;
    if (attemptCount >= _maxRetries) {
      return false;
    }

    // 检查是否为可重试的错误
    return _isRetriableError(err);
  }

  /// 检查请求方法是否可重试
  bool _isRetriableMethod(String method) {
    final upperMethod = method.toUpperCase();
    return upperMethod == 'GET' || upperMethod == 'HEAD';
  }

  /// 检查错误是否可重试
  bool _isRetriableError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        if (statusCode == null) return false;

        // 429 Too Many Requests - 可重试
        if (statusCode == 429) return true;

        // 5xx 服务器错误 - 可重试
        if (statusCode >= 500 && statusCode < 600) {
          return statusCode == 500 || // Internal Server Error
              statusCode == 502 || // Bad Gateway
              statusCode == 503 || // Service Unavailable
              statusCode == 504; // Gateway Timeout
        }

        // 4xx 客户端错误 - 不重试（401/403/404 等）
        return false;

      case DioExceptionType.cancel:
        // 主动取消 - 不重试
        return false;

      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        // 解析错误、证书错误、转换超时、其他未知错误 - 不重试
        return false;
    }
  }

  /// 计算重试延迟时间
  Duration _calculateRetryDelay(Response? response, int attemptCount) {
    // 检查 Retry-After 头部
    final retryAfterHeader = response?.headers.value('retry-after');
    if (retryAfterHeader != null && retryAfterHeader.isNotEmpty) {
      final retryAfterDuration = _parseRetryAfter(retryAfterHeader);
      if (retryAfterDuration != null) {
        // 限制最大延迟时间（避免过长的等待）
        const maxDelay = Duration(minutes: 5);
        return retryAfterDuration > maxDelay ? maxDelay : retryAfterDuration;
      }
    }

    // 默认递增延迟：第一次 500ms，第二次 1000ms
    return Duration(milliseconds: attemptCount * 500);
  }

  /// 解析 Retry-After 头部
  ///
  /// 支持两种格式：
  /// - 秒数：如 "120"
  /// - HTTP 日期：如 "Fri, 31 Dec 1999 23:59:59 GMT"
  Duration? _parseRetryAfter(String retryAfterValue) {
    final trimmedValue = retryAfterValue.trim();

    // 尝试解析为秒数
    final seconds = int.tryParse(trimmedValue);
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }

    // 尝试解析为 HTTP 日期
    try {
      final retryDateTime = HttpDate.parse(trimmedValue);
      final now = _clockFn?.call() ?? DateTime.now();
      final delay = retryDateTime.difference(now);

      // 只有未来的时间才有效
      return delay.isNegative ? null : delay;
    } catch (e) {
      AppLogger.w(
        'OnlineGalleryRetryInterceptor: Failed to parse Retry-After header: $trimmedValue',
        'NETWORK',
      );
      return null;
    }
  }

  /// 执行延迟，支持取消
  Future<void> _executeDelay(
    Duration duration,
    CancelToken? cancelToken,
  ) async {
    if (_delayFn != null) {
      // 使用注入的延迟函数（用于测试）
      await _delayFn(duration, cancelToken);
    } else {
      // 使用真实延迟
      await _realDelay(duration, cancelToken);
    }
  }

  /// 真实延迟实现
  Future<void> _realDelay(Duration duration, CancelToken? cancelToken) async {
    if (duration <= Duration.zero) return;

    final completer = Completer<void>();
    late final Timer timer;
    StreamSubscription? cancelSubscription;

    // 设置延迟定时器
    timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // 监听取消事件
    if (cancelToken != null) {
      cancelSubscription = cancelToken.whenCancel.asStream().listen((_) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(OperationCancelledError());
        }
      });
    }

    try {
      await completer.future;
    } finally {
      timer.cancel();
      await cancelSubscription?.cancel();
    }
  }
}

/// 操作取消错误
class OperationCancelledError extends Error {
  @override
  String toString() => 'OperationCancelledError: The operation was cancelled';
}
