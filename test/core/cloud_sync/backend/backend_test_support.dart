import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class TestHttpResponse {
  const TestHttpResponse(
    this.status, [
    this.body = '',
    this.headers = const {},
  ]);

  final int status;
  final String body;
  final Map<String, List<String>> headers;
}

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final FutureOr<TestHttpResponse> Function(RequestOptions request) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await handler(options);
    return ResponseBody.fromString(
      response.body,
      response.status,
      headers: response.headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

String jsonBody(Object? value) => jsonEncode(value);
