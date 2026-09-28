import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/network_failure_diagnostics.dart';

void main() {
  test('diagnostics omit credentials, query data, and user-provided paths', () {
    final error = DioException(
      requestOptions: RequestOptions(
        path: 'https://danbooru.donmai.us/wiki_pages/private-tag.json',
        method: 'GET',
        queryParameters: const {'api_key': 'secret-api-key'},
        headers: const {'Authorization': 'Basic secret-token'},
      ),
      error: const SocketException('test failure'),
      type: DioExceptionType.connectionError,
    );

    final message = formatNetworkFailureDiagnostic(
      scope: 'Danbooru API',
      error: error,
    );

    expect(message, contains('origin=https://danbooru.donmai.us'));
    expect(message, contains('type=connectionError'));
    expect(message, isNot(contains('private-tag')));
    expect(message, isNot(contains('secret-api-key')));
    expect(message, isNot(contains('secret-token')));
  });

  test('diagnostics preserve the original network failure', () async {
    final dio = Dio()..httpClientAdapter = _FailingAdapter();
    addNetworkFailureDiagnostics(dio, scope: 'test');
    addTearDown(dio.close);

    await expectLater(
      dio.get<void>(
        'https://danbooru.donmai.us/posts.json',
        queryParameters: const {'api_key': 'must-not-be-logged'},
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.error,
          'cause',
          isA<SocketException>(),
        ),
      ),
    );
  });
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw const SocketException('test failure');
  }

  @override
  void close({bool force = false}) {}
}
