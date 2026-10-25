import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/llm_helpers.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/agent_wire_helpers.dart';

const _provider = ProviderConfig(
  id: 'provider',
  name: 'Provider',
  protocol: ProviderProtocol.openaiChatCompletions,
  baseUrl: 'https://example.test',
);

bool _retryable(String errorMessage) => isRetryableAssistantError(
  AssistantMessage(
    content: const [],
    stopReason: StopReason.error,
    errorMessage: errorMessage,
  ),
);

void main() {
  final options = RequestOptions(path: 'https://example.test');

  group('transport failures become retryable network errors', () {
    final cases = <String, Object>{
      'dropped stream': const HttpException(
        'Connection closed while receiving data',
      ),
      'dropped before headers': const HttpException(
        'Connection closed before full header was received',
      ),
      'socket failure while awaiting headers': const HttpException(
        'Read failed',
      ),
      'localized socket reset': const SocketException(
        '远程主机强迫关闭了一个现有的连接。',
      ),
      'timeout': TimeoutException('no data'),
      'handshake termination': const HandshakeException(
        'Connection terminated during handshake',
      ),
      'dio connection timeout': DioException.connectionTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: options,
      ),
      'dio send timeout': DioException.sendTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: options,
      ),
      'dio connection error': DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
        error: const SocketException('Connection refused'),
      ),
      'dio receive timeout': DioException.receiveTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: options,
      ),
      'dio wrapping a socket error': DioException(
        requestOptions: options,
        error: const SocketException('远程主机强迫关闭了一个现有的连接。'),
      ),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final message = agentWireErrorFrom(entry.value, _provider).message;
        expect(message, contains('network error'));
        expect(message, contains('provider=Provider'));
        expect(_retryable(message), isTrue);
      });
    }

    test('wrapped transport detail stays visible', () {
      final message = agentWireErrorFrom(
        DioException(
          requestOptions: options,
          error: const SocketException('Connection reset by peer'),
        ),
        _provider,
      ).message;
      expect(message, contains('Connection reset by peer'));
    });
  });

  group('HTTP and local failures keep their meaning', () {
    DioException badResponse(int statusCode, Object data) =>
        DioException.badResponse(
          statusCode: statusCode,
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: statusCode,
            data: data,
          ),
        );

    test('5xx is retryable by status, not as a network error', () {
      final message = agentWireErrorFrom(
        badResponse(503, {
          'error': {'message': 'Service busy'},
        }),
        _provider,
      ).message;
      expect(message, contains('HTTP 503'));
      expect(message, isNot(contains('network error')));
      expect(message, contains('Service busy'));
      expect(_retryable(message), isTrue);
    });

    test('authentication and quota failures are not retried', () {
      expect(
        _retryable(
          agentWireErrorFrom(
            badResponse(401, 'invalid api key'),
            _provider,
          ).message,
        ),
        isFalse,
      );
      expect(
        _retryable(
          agentWireErrorFrom(
            badResponse(429, {
              'error': {'message': 'insufficient_quota'},
            }),
            _provider,
          ).message,
        ),
        isFalse,
      );
    });

    test('malformed responses and local bugs are not network errors', () {
      for (final error in [
        const HttpException('Invalid response status code with 1'),
        const HttpException('Content-Length must contain only digits'),
        StateError('invalid local state'),
        DioException.badCertificate(requestOptions: options),
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      ]) {
        final message = agentWireErrorFrom(error, _provider).message;
        expect(message, isNot(contains('network error')));
        expect(_retryable(message), isFalse);
      }
    });

    test('cancellation stays an abort', () {
      expect(
        agentWireErrorFrom(
          DioException.requestCancelled(
            requestOptions: options,
            reason: 'cancelled by user',
          ),
          _provider,
        ).message,
        'aborted',
      );
    });
  });
}
