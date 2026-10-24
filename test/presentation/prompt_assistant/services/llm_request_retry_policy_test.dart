import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/llm_request_retry_policy.dart';

final _options = RequestOptions(path: '/v1/chat/completions');

DioException _status(int status, {Object? data}) => DioException(
  requestOptions: _options,
  response: Response<dynamic>(
    requestOptions: _options,
    statusCode: status,
    data: data,
  ),
  type: DioExceptionType.badResponse,
);

DioException _transport(DioExceptionType type, {Object? cause}) =>
    DioException(requestOptions: _options, type: type, error: cause);

Response<dynamic> _headers(Map<String, String> values) => _repeatedHeaders({
  for (final entry in values.entries) entry.key: [entry.value],
});

Response<dynamic> _repeatedHeaders(Map<String, List<String>> values) =>
    Response<dynamic>(
      requestOptions: _options,
      statusCode: 429,
      headers: Headers.fromMap(values),
    );

void main() {
  group('classifyLlmRequestFailure', () {
    final cases = <String, (Object, LlmRequestFailureKind)>{
      '429': (_status(429), LlmRequestFailureKind.congestion),
      '503': (_status(503), LlmRequestFailureKind.congestion),
      '529': (_status(529), LlmRequestFailureKind.congestion),
      '429 quota': (
        _status(429, data: {'error': 'insufficient_quota'}),
        LlmRequestFailureKind.terminal,
      ),
      '503 billing': (
        _status(503, data: 'Billing hard limit reached'),
        LlmRequestFailureKind.terminal,
      ),
      '502': (_status(502), LlmRequestFailureKind.transient),
      '504': (_status(504), LlmRequestFailureKind.transient),
      '500': (_status(500), LlmRequestFailureKind.terminal),
      '400': (_status(400), LlmRequestFailureKind.terminal),
      '401': (_status(401), LlmRequestFailureKind.terminal),
      'connectionError': (
        _transport(DioExceptionType.connectionError),
        LlmRequestFailureKind.transient,
      ),
      'closed before headers': (
        _transport(
          DioExceptionType.connectionError,
          cause: const HttpException(
            'Connection closed before full header was received',
          ),
        ),
        LlmRequestFailureKind.transient,
      ),
      'connectionTimeout': (
        _transport(DioExceptionType.connectionTimeout),
        LlmRequestFailureKind.transient,
      ),
      'sendTimeout': (
        _transport(DioExceptionType.sendTimeout),
        LlmRequestFailureKind.transient,
      ),
      'receiveTimeout': (
        _transport(DioExceptionType.receiveTimeout),
        LlmRequestFailureKind.terminal,
      ),
      'cancel': (
        _transport(DioExceptionType.cancel),
        LlmRequestFailureKind.terminal,
      ),
      'badCertificate': (
        _transport(DioExceptionType.badCertificate),
        LlmRequestFailureKind.terminal,
      ),
      'unknown socket': (
        _transport(
          DioExceptionType.unknown,
          cause: const SocketException('Connection reset by peer'),
        ),
        LlmRequestFailureKind.transient,
      ),
      'unknown http': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException('Connection closed while receiving data'),
        ),
        LlmRequestFailureKind.transient,
      ),
      'reset while awaiting headers': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException('Read failed'),
        ),
        LlmRequestFailureKind.transient,
      ),
      'closed before response': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException(
            'Connection closed before response was received',
          ),
        ),
        LlmRequestFailureKind.transient,
      ),
      'redirect limit': (
        _transport(
          DioExceptionType.unknown,
          cause: const RedirectException('Redirect limit exceeded', []),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'proxy refused tunnel': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException(
            'Proxy failed to establish tunnel '
            '(407 Proxy Authentication Required)',
          ),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'malformed status line': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException('Invalid response line'),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'malformed header': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException('Invalid header field name, with 32'),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'unparsable framing': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException(
            'Failed to parse HTTP, 10 does not match 13',
          ),
        ),
        LlmRequestFailureKind.terminal,
      ),
      for (final part in [
        'Method',
        'Reason phrase',
        'Header field',
        'Header value',
      ])
        '$part over size limit': (
          _transport(
            DioExceptionType.unknown,
            cause: HttpException('$part exceeds the 1048576 size limit'),
          ),
          LlmRequestFailureKind.terminal,
        ),
      'proxy without port': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException(
            'Invalid proxy configuration PROXY 127.0.0.1',
          ),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'proxy with unreadable port': (
        _transport(
          DioExceptionType.unknown,
          cause: const HttpException(
            "Invalid proxy configuration PROXY 127.0.0.1:abc, "
            "invalid port 'abc'",
          ),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'handshake interrupted': (
        _transport(
          DioExceptionType.unknown,
          cause: const HandshakeException(
            'Connection terminated during handshake',
          ),
        ),
        LlmRequestFailureKind.transient,
      ),
      'certificate rejected': (
        _transport(
          DioExceptionType.unknown,
          cause: const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'unknown without cause': (
        _transport(DioExceptionType.unknown),
        LlmRequestFailureKind.terminal,
      ),
      'unknown format error': (
        _transport(
          DioExceptionType.unknown,
          cause: const FormatException('bad json'),
        ),
        LlmRequestFailureKind.terminal,
      ),
      'raw socket error': (
        const SocketException('not wrapped by dio'),
        LlmRequestFailureKind.terminal,
      ),
      'raw timeout': (
        TimeoutException('not wrapped by dio'),
        LlmRequestFailureKind.terminal,
      ),
    };
    for (final MapEntry(key: name, value: (error, expected)) in cases.entries) {
      test(name, () {
        expect(classifyLlmRequestFailure(error), expected);
      });
    }
  });

  group('llmRetryBackoff', () {
    test('doubles per retry and caps the base at four seconds', () {
      expect(
        [
          for (var retry = 0; retry < 5; retry++)
            llmRetryBackoff(retry, jitter: 0),
        ],
        const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
          Duration(seconds: 4),
          Duration(seconds: 4),
        ],
      );
    });

    test('jitter only lengthens the wait, by at most half', () {
      expect(
        llmRetryBackoff(0, jitter: 0.5),
        const Duration(milliseconds: 1250),
      );
      expect(
        llmRetryBackoff(1, jitter: 0.999),
        const Duration(milliseconds: 2999),
      );
      expect(llmRetryBackoff(1, jitter: 1), const Duration(milliseconds: 3000));
    });

    test('out-of-range jitter is clamped', () {
      expect(llmRetryBackoff(0, jitter: -3), const Duration(seconds: 1));
      expect(llmRetryBackoff(0, jitter: 7), const Duration(milliseconds: 1500));
    });
  });

  group('llmRetryAfter', () {
    final now = DateTime.utc(2026, 10, 24, 12);

    test('absent headers and responses ask for no wait', () {
      expect(llmRetryAfter(null, now: now), isNull);
      expect(llmRetryAfter(_headers({}), now: now), isNull);
    });

    test('reads seconds, fractions and milliseconds', () {
      expect(
        llmRetryAfter(_headers({'retry-after': '7'}), now: now),
        const Duration(seconds: 7),
      );
      expect(
        llmRetryAfter(_headers({'retry-after': '0.25'}), now: now),
        const Duration(milliseconds: 250),
      );
      expect(
        llmRetryAfter(
          _headers({'retry-after-ms': '1500', 'retry-after': '30'}),
          now: now,
        ),
        const Duration(milliseconds: 1500),
      );
    });

    test('reads HTTP dates and treats past dates as no wait', () {
      expect(
        llmRetryAfter(
          _headers({
            'retry-after': HttpDate.format(
              now.add(const Duration(seconds: 12)),
            ),
          }),
          now: now,
        ),
        const Duration(seconds: 12),
      );
      expect(
        llmRetryAfter(
          _headers({
            'retry-after': HttpDate.format(
              now.subtract(const Duration(minutes: 1)),
            ),
          }),
          now: now,
        ),
        Duration.zero,
      );
    });

    test('caps every form at sixty seconds without overflowing', () {
      for (final headers in [
        {'retry-after': '3600'},
        {'retry-after': '1e308'},
        {'retry-after-ms': '86400000'},
        {'retry-after': HttpDate.format(now.add(const Duration(days: 1)))},
      ]) {
        expect(
          llmRetryAfter(_headers(headers), now: now),
          llmRetryAfterLimit,
          reason: '$headers',
        );
      }
      expect(llmRetryAfterLimit, const Duration(seconds: 60));
    });

    test('malformed values are ignored instead of thrown', () {
      for (final headers in [
        {'retry-after': 'soon'},
        {'retry-after': '-5'},
        {'retry-after': 'NaN'},
        {'retry-after-ms': 'later'},
      ]) {
        expect(
          llmRetryAfter(_headers(headers), now: now),
          isNull,
          reason: '$headers',
        );
      }
      expect(
        llmRetryAfter(
          _headers({'retry-after-ms': 'later', 'retry-after': '3'}),
          now: now,
        ),
        const Duration(seconds: 3),
      );
    });

    test('repeated headers use the first readable value without throwing', () {
      final cases = <Map<String, List<String>>, Duration?>{
        {
          'retry-after': ['5', '7'],
        }: const Duration(
          seconds: 5,
        ),
        {
          'retry-after-ms': ['1', '2'],
        }: const Duration(
          milliseconds: 1,
        ),
        {
          'retry-after': ['soon', '7'],
        }: const Duration(
          seconds: 7,
        ),
        {
          'retry-after-ms': ['later', 'never'],
          'retry-after': ['3', '4'],
        }: const Duration(
          seconds: 3,
        ),
        {
          'retry-after': ['soon', 'later'],
        }: null,
        {'retry-after': <String>[], 'retry-after-ms': <String>[]}: null,
      };
      for (final MapEntry(key: headers, value: expected) in cases.entries) {
        expect(
          llmRetryAfter(_repeatedHeaders(headers), now: now),
          expected,
          reason: '$headers',
        );
      }
    });
  });
}
