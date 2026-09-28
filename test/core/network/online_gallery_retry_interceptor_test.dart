// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nai_launcher/core/network/online_gallery_retry_interceptor.dart';

class MockDio extends Mock implements Dio {}

class MockCancelToken extends Mock implements CancelToken {}

class MockResponse extends Mock implements Response {}

class FakeResponse extends Fake implements Response {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  group('OnlineGalleryRetryInterceptor', () {
    late OnlineGalleryRetryInterceptor interceptor;
    late List<Duration> recordedDelays;
    late List<CancelToken?> recordedCancelTokens;
    late DateTime mockNow;
    late MockDio mockDio;

    // 测试用的延迟注入函数
    Future<void> mockDelayFn(
      Duration duration,
      CancelToken? cancelToken,
    ) async {
      recordedDelays.add(duration);
      recordedCancelTokens.add(cancelToken);

      // 模拟短暂延迟
      await Future.delayed(Duration(milliseconds: 1));

      // 检查是否被取消
      if (cancelToken?.isCancelled == true) {
        throw OperationCancelledError();
      }
    }

    // 测试用的时钟注入函数
    DateTime mockClockFn() => mockNow;

    // 测试用的 Dio 工厂函数
    Dio mockDioFactory() => mockDio;

    setUpAll(() {
      // 注册 fallback 值
      registerFallbackValue(RequestOptions(path: '/test'));
      registerFallbackValue(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      registerFallbackValue(FakeResponse());
    });

    setUp(() {
      recordedDelays = [];
      recordedCancelTokens = [];
      mockNow = DateTime.parse('2023-01-01T12:00:00Z');
      mockDio = MockDio();

      // Mock 成功的 fetch 调用
      when(() => mockDio.fetch(any())).thenAnswer((_) async => FakeResponse());

      interceptor = OnlineGalleryRetryInterceptor(
        delayFn: mockDelayFn,
        clockFn: mockClockFn,
        dioFactory: mockDioFactory,
      );
    });

    group('shouldRetry logic', () {
      test('should retry GET requests', () async {
        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        // 监听 onError 调用但不等待结果
        interceptor.onError(err, handler);

        // 等待延迟被记录
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(
          recordedDelays.first,
          Duration(milliseconds: 500),
        ); // 第一次重试 500ms
      });

      test('should retry HEAD requests', () async {
        final options = RequestOptions(path: '/test', method: 'HEAD');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
      });

      test('should not retry POST requests', () async {
        final options = RequestOptions(path: '/test', method: 'POST');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.next(any())).thenReturn(null);

        interceptor.onError(err, handler);

        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, isEmpty);
        verify(() => handler.next(err)).called(1);
      });

      test('should not retry PUT requests', () async {
        final options = RequestOptions(path: '/test', method: 'PUT');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.next(any())).thenReturn(null);

        interceptor.onError(err, handler);

        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, isEmpty);
        verify(() => handler.next(err)).called(1);
      });
    });

    group('retriable errors', () {
      final retriableErrorTypes = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ];

      for (final errorType in retriableErrorTypes) {
        test('should retry $errorType', () async {
          final options = RequestOptions(path: '/test', method: 'GET');
          final err = DioException(requestOptions: options, type: errorType);

          final handler = MockErrorInterceptorHandler();
          when(() => handler.resolve(any())).thenReturn(null);

          interceptor.onError(err, handler);
          await Future.delayed(Duration(milliseconds: 50));

          expect(recordedDelays, hasLength(1));
        });
      }

      test('should retry 429 Too Many Requests', () async {
        final response = MockResponse();
        when(() => response.statusCode).thenReturn(429);
        when(() => response.headers).thenReturn(Headers());

        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
      });

      final retriableStatusCodes = [500, 502, 503, 504];
      for (final statusCode in retriableStatusCodes) {
        test('should retry HTTP $statusCode', () async {
          final response = MockResponse();
          when(() => response.statusCode).thenReturn(statusCode);
          when(() => response.headers).thenReturn(Headers());

          final options = RequestOptions(path: '/test', method: 'GET');
          final err = DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: response,
          );

          final handler = MockErrorInterceptorHandler();
          when(() => handler.resolve(any())).thenReturn(null);

          interceptor.onError(err, handler);
          await Future.delayed(Duration(milliseconds: 50));

          expect(recordedDelays, hasLength(1));
        });
      }
    });

    group('non-retriable errors', () {
      test('should not retry cancel errors', () async {
        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.next(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, isEmpty);
        verify(() => handler.next(err)).called(1);
      });

      final nonRetriableStatusCodes = [401, 403, 404, 400, 409];
      for (final statusCode in nonRetriableStatusCodes) {
        test('should not retry HTTP $statusCode', () async {
          final response = MockResponse();
          when(() => response.statusCode).thenReturn(statusCode);

          final options = RequestOptions(path: '/test', method: 'GET');
          final err = DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: response,
          );

          final handler = MockErrorInterceptorHandler();
          when(() => handler.next(any())).thenReturn(null);

          interceptor.onError(err, handler);
          await Future.delayed(Duration(milliseconds: 50));

          expect(recordedDelays, isEmpty);
          verify(() => handler.next(err)).called(1);
        });
      }

      test('should not retry unknown errors', () async {
        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.next(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, isEmpty);
        verify(() => handler.next(err)).called(1);
      });

      test('should not retry bad certificate errors', () async {
        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badCertificate,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.next(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, isEmpty);
        verify(() => handler.next(err)).called(1);
      });
    });

    group('retry limits', () {
      test('should not retry more than 2 times', () async {
        final options = RequestOptions(
          path: '/test',
          method: 'GET',
          extra: {'_retry_attempt_count': 2}, // 已经重试过 2 次
        );
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.next(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, isEmpty);
        verify(() => handler.next(err)).called(1);
      });

      test('should increment attempt count correctly', () async {
        final options = RequestOptions(
          path: '/test',
          method: 'GET',
          extra: {'_retry_attempt_count': 1}, // 第一次重试
        );
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(
          recordedDelays.first,
          Duration(milliseconds: 1000),
        ); // 第二次重试 1000ms
      });
    });

    group('Retry-After header parsing', () {
      test('should parse Retry-After as seconds', () async {
        final headers = Headers();
        headers.set('retry-after', '30');

        final response = MockResponse();
        when(() => response.statusCode).thenReturn(429);
        when(() => response.headers).thenReturn(headers);

        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(recordedDelays.first, Duration(seconds: 30));
      });

      test('should parse Retry-After as HTTP date', () async {
        // 设置为 30 秒后的时间
        final futureTime = mockNow.add(Duration(seconds: 30));
        final httpDate = HttpDate.format(futureTime);

        final headers = Headers();
        headers.set('retry-after', httpDate);

        final response = MockResponse();
        when(() => response.statusCode).thenReturn(503);
        when(() => response.headers).thenReturn(headers);

        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(recordedDelays.first.inSeconds, closeTo(30, 1));
      });

      test('should cap Retry-After at 5 minutes', () async {
        final headers = Headers();
        headers.set('retry-after', '600'); // 10 分钟

        final response = MockResponse();
        when(() => response.statusCode).thenReturn(429);
        when(() => response.headers).thenReturn(headers);

        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(recordedDelays.first, Duration(minutes: 5)); // 限制为 5 分钟
      });

      test('should ignore past HTTP dates', () async {
        // 设置为过去的时间
        final pastTime = mockNow.subtract(Duration(seconds: 30));
        final httpDate = HttpDate.format(pastTime);

        final headers = Headers();
        headers.set('retry-after', httpDate);

        final response = MockResponse();
        when(() => response.statusCode).thenReturn(503);
        when(() => response.headers).thenReturn(headers);

        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(recordedDelays.first, Duration(milliseconds: 500)); // 使用默认延迟
      });

      test('should use default delay for invalid Retry-After', () async {
        final headers = Headers();
        headers.set('retry-after', 'invalid');

        final response = MockResponse();
        when(() => response.statusCode).thenReturn(429);
        when(() => response.headers).thenReturn(headers);

        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(recordedDelays.first, Duration(milliseconds: 500)); // 使用默认延迟
      });
    });

    group('cancellation handling', () {
      test('should pass cancel token to delay function', () async {
        final cancelToken = MockCancelToken();
        when(() => cancelToken.isCancelled).thenReturn(false);

        final options = RequestOptions(
          path: '/test',
          method: 'GET',
          cancelToken: cancelToken,
        );
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedCancelTokens, hasLength(1));
        expect(recordedCancelTokens.first, cancelToken);
      });

      test('should handle cancellation during delay', () async {
        final cancelToken = MockCancelToken();
        when(() => cancelToken.isCancelled).thenReturn(true);

        final options = RequestOptions(
          path: '/test',
          method: 'GET',
          cancelToken: cancelToken,
        );
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.next(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        // 应该调用 handler.next 而不是重试
        verify(() => handler.next(err)).called(1);
      });
    });

    group('default delay calculation', () {
      test('should use 500ms for first retry', () async {
        final options = RequestOptions(path: '/test', method: 'GET');
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(recordedDelays.first, Duration(milliseconds: 500));
      });

      test('should use 1000ms for second retry', () async {
        final options = RequestOptions(
          path: '/test',
          method: 'GET',
          extra: {'_retry_attempt_count': 1},
        );
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

        final handler = MockErrorInterceptorHandler();
        when(() => handler.resolve(any())).thenReturn(null);

        interceptor.onError(err, handler);
        await Future.delayed(Duration(milliseconds: 50));

        expect(recordedDelays, hasLength(1));
        expect(recordedDelays.first, Duration(milliseconds: 1000));
      });
    });
  });
}
