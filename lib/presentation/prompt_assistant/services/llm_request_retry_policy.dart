import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// Longest server-requested wait honored before retrying.
const llmRetryAfterLimit = Duration(seconds: 60);

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

double? _nonNegativeNumber(String value) {
  final number = double.tryParse(value.trim());
  return number != null && number.isFinite && number >= 0 ? number : null;
}

Duration _cappedMilliseconds(double milliseconds) => Duration(
  milliseconds: math
      .min(milliseconds, llmRetryAfterLimit.inMilliseconds.toDouble())
      .ceil(),
);
