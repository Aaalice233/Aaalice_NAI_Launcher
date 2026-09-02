import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/dio_error_response_parser.dart';

void main() {
  group('parseDioErrorResponseDetails', () {
    test('decodes byte JSON returned by image generation endpoints', () {
      final body = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'message': '参数错误',
            'code': 'INVALID_PARAMETERS',
            'request_id': 'request-209',
          }),
        ),
      );

      expect(
        parseDioErrorResponseDetails(body),
        '参数错误 (code: INVALID_PARAMETERS) [request_id: request-209]',
      );
    });

    test('extracts nested OpenAI-style errors', () {
      expect(
        parseDioErrorResponseDetails({
          'error': {
            'message': 'Model is unavailable',
            'code': 'MODEL_UNAVAILABLE',
          },
          'requestId': 'request-nested',
        }),
        'Model is unavailable (code: MODEL_UNAVAILABLE) '
        '[request_id: request-nested]',
      );
    });

    test('preserves a plain-text server error', () {
      expect(
        parseDioErrorResponseDetails(
          utf8.encode('failed to read multipart request'),
        ),
        'failed to read multipart request',
      );
    });

    test('ignores binary response data', () {
      expect(
        parseDioErrorResponseDetails(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
        isNull,
      );
    });
  });

  test('bounds response data written to logs', () {
    final output = formatDioErrorResponseDataForLog('x' * 5000);

    expect(output.length, lessThan(4200));
    expect(output, endsWith('… [truncated]'));
  });
}
