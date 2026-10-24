import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/llm_request_retry_policy.dart';

final _options = RequestOptions(path: '/v1/chat/completions');

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
