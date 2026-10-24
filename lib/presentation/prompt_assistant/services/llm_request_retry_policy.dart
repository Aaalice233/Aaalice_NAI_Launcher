import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// How a failed non-streaming LLM request may be retried.
enum LlmRequestFailureKind {
  /// The provider is shedding load, so the whole endpoint should slow down.
  congestion,

  /// Only this request failed in transit and may be sent again.
  transient,

  /// Another attempt cannot change the outcome.
  terminal,
}

/// Longest server-requested wait honored before retrying.
const llmRetryAfterLimit = Duration(seconds: 60);

const _congestionStatuses = {429, 503, 529};
const _transientStatuses = {502, 504};

final _exhaustedQuota = RegExp(
  r'insufficient_quota|insufficient.balance|billing|daily.quota',
);

// dart:io reports these with the same HttpException type as dropped sockets.
const _deterministicHttpFailures = [
  'proxy failed to establish tunnel',
  'invalid response',
  'invalid header',
  'failed to parse',
  'illegal value',
  'invalid proxy configuration',
];

final _headerSizeLimitExceeded = RegExp(r' exceeds the \d+ size limit$');

LlmRequestFailureKind classifyLlmRequestFailure(Object error) {
  if (error is! DioException) return LlmRequestFailureKind.terminal;
  final response = error.response;
  final status = response?.statusCode;
  if (status != null) {
    if (_congestionStatuses.contains(status)) {
      final detail = response?.data.toString().toLowerCase() ?? '';
      return _exhaustedQuota.hasMatch(detail)
          ? LlmRequestFailureKind.terminal
          : LlmRequestFailureKind.congestion;
    }
    return _transientStatuses.contains(status)
        ? LlmRequestFailureKind.transient
        : LlmRequestFailureKind.terminal;
  }
  // receiveTimeout is user-configured; retrying would multiply that wait.
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout => LlmRequestFailureKind.transient,
    DioExceptionType.unknown when _isTransientNetworkFailure(error.error) =>
      LlmRequestFailureKind.transient,
    _ => LlmRequestFailureKind.terminal,
  };
}

const _backoffJitterRatio = 0.5;

// Jitter only lengthens the wait, so batches that failed together spread out.
Duration llmRetryBackoff(int retry, {required double jitter}) {
  final base = 1000 << math.min(retry, 2);
  final spread = jitter.clamp(0.0, 1.0) * _backoffJitterRatio;
  return Duration(milliseconds: (base * (1 + spread)).round());
}

/// Wait requested through `retry-after-ms` or `Retry-After`, capped at
/// [llmRetryAfterLimit]; null when the response does not ask for one.
Duration? llmRetryAfter(Response<dynamic>? response, {required DateTime now}) {
  final headers = response?.headers;
  if (headers == null) return null;
  // Headers.value throws once a relay repeats a header, so every copy is read.
  return _firstReadable(headers['retry-after-ms'], _parseRetryAfterMs) ??
      _firstReadable(
        headers['retry-after'],
        (value) => _parseRetryAfter(value, now),
      );
}

Duration? _firstReadable(
  List<String>? values,
  Duration? Function(String value) parse,
) {
  for (final value in values ?? const <String>[]) {
    final delay = parse(value);
    if (delay != null) return delay;
  }
  return null;
}

Duration? _parseRetryAfterMs(String value) {
  final milliseconds = _nonNegativeNumber(value);
  return milliseconds == null ? null : _cappedMilliseconds(milliseconds);
}

Duration? _parseRetryAfter(String value, DateTime now) {
  final seconds = _nonNegativeNumber(value);
  if (seconds != null) return _cappedMilliseconds(seconds * 1000);
  try {
    final delay = HttpDate.parse(value.trim()).difference(now);
    if (delay.isNegative) return Duration.zero;
    return delay > llmRetryAfterLimit ? llmRetryAfterLimit : delay;
  } on HttpException {
    // HttpDate.parse reports malformed dates as HttpException, not FormatException.
    return null;
  }
}

bool _isTransientNetworkFailure(Object? cause) {
  if (cause is HandshakeException) {
    // Certificate rejections need a configuration change, not another attempt.
    return cause.message.toLowerCase().contains(
      'connection terminated during handshake',
    );
  }
  if (cause is RedirectException) return false;
  if (cause is HttpException) {
    final message = cause.message.toLowerCase();
    return !_deterministicHttpFailures.any(message.startsWith) &&
        !_headerSizeLimitExceeded.hasMatch(message);
  }
  return cause is SocketException;
}

double? _nonNegativeNumber(String value) {
  final number = double.tryParse(value.trim());
  return number != null && number.isFinite && number >= 0 ? number : null;
}

Duration _cappedMilliseconds(double milliseconds) => Duration(
  milliseconds: math
      .min(milliseconds, llmRetryAfterLimit.inMilliseconds.toDouble())
      .ceil(),
);
