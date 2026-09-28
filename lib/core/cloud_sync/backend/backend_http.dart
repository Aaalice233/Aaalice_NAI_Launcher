import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../operation.dart';
import 'backend_http_metrics.dart';
import 'cloud_sync_backend.dart';

typedef BackendHttpClock = DateTime Function();
typedef BackendHttpSleeper = Future<void> Function(Duration duration);
typedef BackendHttpJitter = Duration Function(Duration delay, int attempt);
typedef BackendHttpRetryResponse = bool Function(Response<Uint8List> response);

class BackendHttp {
  BackendHttp({
    Dio? dio,
    BackendHttpRequestObserver? observer,
    BackendHttpClock? clock,
    BackendHttpSleeper? sleeper,
    BackendHttpJitter? jitter,
  }) : dio = dio ?? Dio(),
       _observer = observer,
       _clock = clock ?? _systemClock,
       _sleeper = sleeper ?? Future<void>.delayed,
       _jitter = jitter ?? _fullJitter;

  final Dio dio;
  final BackendHttpRequestObserver? _observer;
  final BackendHttpClock _clock;
  final BackendHttpSleeper _sleeper;
  final BackendHttpJitter _jitter;

  var _concurrentRequests = 0;
  var _maxConcurrentRequests = 0;

  Future<Response<Uint8List>> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? data,
    CancelToken? cancelToken,
    int maxResponseBytes = 1024 * 1024,
    CloudBackendErrorKind tooLargeKind = CloudBackendErrorKind.invalidResponse,
    bool? retryable,
    BackendHttpRetryResponse? retryResponse,
    bool followRedirects = true,
    Duration receiveTimeout = const Duration(minutes: 2),
    BackendHttpEndpointCategory endpointCategory =
        BackendHttpEndpointCategory.unspecified,
  }) async {
    final operation = OperationToken.current;
    operation?.throwIfCancelled();
    final effectiveCancelToken = operation == null
        ? cancelToken
        : CancelToken();
    void Function()? removeOperationListener;
    if (operation != null) {
      final linked = effectiveCancelToken!;
      removeOperationListener = operation.addCancellationListener(
        () => linked.cancel(const OperationCancelledException()),
      );
      if (cancelToken != null) {
        if (cancelToken.isCancelled) {
          linked.cancel(cancelToken.cancelError);
        } else {
          unawaited(
            cancelToken.whenCancel.then<void>((error) => linked.cancel(error)),
          );
        }
      }
    }

    final normalizedMethod = method.toUpperCase();
    final normalizedData = data is List<int> && data is! Uint8List
        ? Uint8List.fromList(data)
        : data;
    final mayRetry =
        retryable ??
        const {'GET', 'HEAD', 'OPTIONS', 'PROPFIND'}.contains(normalizedMethod);
    final observesRequest = _observer != null;
    final requestBytes = observesRequest ? _requestBytes(normalizedData) : null;
    if (observesRequest) {
      _concurrentRequests++;
      if (_concurrentRequests > _maxConcurrentRequests) {
        _maxConcurrentRequests = _concurrentRequests;
      }
    }
    try {
      const maxAttempts = 3;
      for (var attempt = 1; ; attempt++) {
        final startedAt = observesRequest ? _clock() : null;
        Response<Uint8List> response;
        try {
          response = await _request(
            normalizedMethod,
            uri,
            headers: headers,
            data: normalizedData,
            cancelToken: effectiveCancelToken,
            maxResponseBytes: maxResponseBytes,
            tooLargeKind: tooLargeKind,
            receiveTimeout: receiveTimeout,
            redirectsRemaining: followRedirects ? 5 : 0,
            returnRedirectResponse: !followRedirects,
          );
        } on CloudBackendException catch (error, stackTrace) {
          final retry =
              mayRetry &&
              attempt < maxAttempts &&
              error.kind == CloudBackendErrorKind.network;
          _record(
            method: normalizedMethod,
            endpointCategory: endpointCategory,
            attempt: attempt,
            statusCode: error.statusCode,
            requestBytes: requestBytes,
            responseBytes: null,
            retry: retry,
            startedAt: startedAt,
          );
          if (!retry) {
            Error.throwWithStackTrace(error, stackTrace);
          }
          await _waitBeforeRetry(
            _retryDelay(null, attempt),
            effectiveCancelToken,
          );
          continue;
        } on Object catch (error, stackTrace) {
          _record(
            method: normalizedMethod,
            endpointCategory: endpointCategory,
            attempt: attempt,
            statusCode: null,
            requestBytes: requestBytes,
            responseBytes: null,
            retry: false,
            startedAt: startedAt,
          );
          Error.throwWithStackTrace(error, stackTrace);
        }

        final retry =
            mayRetry &&
            attempt < maxAttempts &&
            (_transientStatuses.contains(response.statusCode) ||
                (retryResponse?.call(response) ?? false));
        _record(
          method: normalizedMethod,
          endpointCategory: endpointCategory,
          attempt: attempt,
          statusCode: response.statusCode,
          requestBytes: requestBytes,
          responseBytes: response.data?.length ?? 0,
          retry: retry,
          startedAt: startedAt,
        );
        if (!retry) return response;
        await _waitBeforeRetry(
          _retryDelay(response, attempt),
          effectiveCancelToken,
        );
      }
    } catch (error, stackTrace) {
      if (operation?.isCancelled ?? false) {
        Error.throwWithStackTrace(
          const OperationCancelledException(),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      removeOperationListener?.call();
      if (observesRequest) _concurrentRequests--;
    }
  }

  static const _transientStatuses = {408, 425, 429, 500, 502, 503, 504};

  Future<void> _waitBeforeRetry(
    Duration duration,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await _sleeper(duration);
      return;
    }
    await Future.any<void>([
      _sleeper(duration),
      cancelToken.whenCancel.then<void>((error) => throw error),
    ]);
  }

  Duration _retryDelay(Response<Uint8List>? response, int attempt) {
    const maximumDelay = Duration(seconds: 30);
    Duration bounded(Duration delay) {
      if (delay.isNegative) return Duration.zero;
      return delay > maximumDelay ? maximumDelay : delay;
    }

    final retryAfter = response?.headers.value('retry-after');
    final seconds = int.tryParse(retryAfter ?? '');
    if (seconds != null) {
      return bounded(Duration(seconds: seconds));
    }
    if (retryAfter != null) {
      final date = _parseHttpDate(retryAfter);
      if (date != null) {
        final delay = date.difference(_clock().toUtc());
        if (!delay.isNegative) return bounded(delay);
      }
    }
    final base = Duration(milliseconds: attempt == 1 ? 300 : 900);
    final jittered = _jitter(base, attempt);
    return bounded(jittered);
  }

  void _record({
    required String method,
    required BackendHttpEndpointCategory endpointCategory,
    required int attempt,
    required int? statusCode,
    required int? requestBytes,
    required int? responseBytes,
    required bool retry,
    required DateTime? startedAt,
  }) {
    final observer = _observer;
    if (observer == null || startedAt == null) return;
    final measured = _clock().difference(startedAt);
    observer(
      BackendHttpRequestMetric(
        method: method,
        endpointCategory: endpointCategory,
        attempt: attempt,
        statusCode: statusCode,
        requestBytes: requestBytes,
        responseBytes: responseBytes,
        retry: retry,
        concurrentRequests: _concurrentRequests,
        maxConcurrentRequests: _maxConcurrentRequests,
        elapsed: measured.isNegative ? Duration.zero : measured,
      ),
    );
  }

  static int? _requestBytes(Object? data) {
    if (data == null) return 0;
    if (data is Uint8List) return data.length;
    if (data is String) return utf8.encode(data).length;
    return null;
  }

  static DateTime _systemClock() => DateTime.now().toUtc();

  static final Random _jitterRandom = Random.secure();

  static Duration _fullJitter(Duration delay, int attempt) {
    final maximum = delay.inMilliseconds;
    if (maximum <= 0) return Duration.zero;
    return Duration(milliseconds: _jitterRandom.nextInt(maximum + 1));
  }

  static DateTime? _parseHttpDate(String value) {
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      return DateTime.tryParse(value)?.toUtc();
    }
  }

  Future<Response<Uint8List>> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? data,
    CancelToken? cancelToken,
    required int maxResponseBytes,
    required CloudBackendErrorKind tooLargeKind,
    required Duration receiveTimeout,
    required int redirectsRemaining,
    required bool returnRedirectResponse,
  }) async {
    try {
      final streamed = await dio.request<ResponseBody>(
        uri.toString(),
        data: data,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: receiveTimeout,
        ),
      );
      final response = await _bufferResponse(
        streamed,
        maxResponseBytes: maxResponseBytes,
        tooLargeKind: tooLargeKind,
      );
      final status = response.statusCode ?? 0;
      if ({301, 302, 303, 307, 308}.contains(status)) {
        if (returnRedirectResponse) return response;
        final location = response.headers.value('location');
        if (location == null || redirectsRemaining == 0) {
          throw CloudBackendException(
            CloudBackendErrorKind.redirectRejected,
            '服务器返回了无效或过多的重定向。',
            statusCode: status,
          );
        }
        final target = uri.resolve(location);
        if (!_sameOrigin(uri, target)) {
          throw CloudBackendException(
            CloudBackendErrorKind.redirectRejected,
            '服务器尝试重定向到其他主机；请求已拦截，认证信息未发送。',
            statusCode: status,
          );
        }
        final becomesGet =
            status == 303 ||
            ((status == 301 || status == 302) && method == 'POST');
        return _request(
          becomesGet ? 'GET' : method,
          target,
          headers: headers,
          data: becomesGet ? null : data,
          cancelToken: cancelToken,
          maxResponseBytes: maxResponseBytes,
          tooLargeKind: tooLargeKind,
          receiveTimeout: receiveTimeout,
          redirectsRemaining: redirectsRemaining - 1,
          returnRedirectResponse: false,
        );
      }
      return response;
    } on CloudBackendException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw CloudBackendException(
        CloudBackendErrorKind.network,
        _networkMessage(error.type),
        cause: error,
      );
    }
  }

  static String _networkMessage(DioExceptionType type) => switch (type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => '网络连接超时，请检查网络或代理后重试。',
    DioExceptionType.badCertificate => '无法验证服务器证书，请检查服务地址或证书配置。',
    DioExceptionType.connectionError => '无法连接服务器，请检查网络、代理和服务地址后重试。',
    _ => '网络请求失败，请检查网络、代理和服务地址后重试。',
  };

  Future<Response<Uint8List>> _bufferResponse(
    Response<ResponseBody> response, {
    required int maxResponseBytes,
    required CloudBackendErrorKind tooLargeKind,
  }) async {
    if (maxResponseBytes < 0) throw ArgumentError.value(maxResponseBytes);
    final declared = int.tryParse(
      response.headers.value('content-length') ?? '',
    );
    final status = response.statusCode ?? 0;
    final method = response.requestOptions.method.toUpperCase();
    final responseMustBeBodyless =
        method == 'HEAD' ||
        status == 204 ||
        status == 304 ||
        (status >= 100 && status < 200);
    if (responseMustBeBodyless) {
      final body = response.data;
      if (body != null) {
        final subscription = body.stream.listen((_) {});
        await subscription.cancel();
      }
      return _copyResponse(response, Uint8List(0));
    }
    if (declared != null && declared > maxResponseBytes) {
      final body = response.data;
      if (body != null) {
        final subscription = body.stream.listen((_) {});
        await subscription.cancel();
      }
      throw CloudBackendException(
        tooLargeKind,
        '服务器响应超过允许的大小上限。',
        statusCode: response.statusCode,
      );
    }
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk
        in response.data?.stream ?? const Stream<Uint8List>.empty()) {
      received += chunk.length;
      if (received > maxResponseBytes) {
        throw CloudBackendException(
          tooLargeKind,
          '服务器响应超过允许的大小上限。',
          statusCode: response.statusCode,
        );
      }
      builder.add(chunk);
    }
    return _copyResponse(response, builder.takeBytes());
  }

  static Response<Uint8List> _copyResponse(
    Response<ResponseBody> response,
    Uint8List bytes,
  ) {
    return Response<Uint8List>(
      data: bytes,
      headers: response.headers,
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      redirects: response.redirects,
      extra: response.extra,
      isRedirect: response.isRedirect,
    );
  }

  static Uint8List bytesOf(Response<Uint8List> response) =>
      response.data ?? Uint8List(0);

  static String textOf(Response<Uint8List> response, {int max = 512}) {
    final text = rawTextOf(response).trim();
    final withoutHtml = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final normalized = withoutHtml.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= max ? normalized : normalized.substring(0, max);
  }

  static String rawTextOf(Response<Uint8List> response) =>
      utf8.decode(bytesOf(response), allowMalformed: true);

  static bool _sameOrigin(Uri first, Uri second) =>
      first.scheme.toLowerCase() == second.scheme.toLowerCase() &&
      first.host.toLowerCase() == second.host.toLowerCase() &&
      first.port == second.port;
}
