import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/browser_identity/browser_headers_interceptor.dart';
import 'package:nai_launcher/core/network/browser_identity/chrome_identity.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _buildDio(_RecordingAdapter adapter, {String language = 'en-US,en;q=0.9'}) {
  final dio = Dio(
    BaseOptions(headers: const {'Content-Type': 'application/json'}),
  );
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    BrowserHeadersInterceptor(
      identity: const ChromeIdentity(platform: ChromePlatform.windows),
      resolveAcceptLanguage: () => language,
    ),
  );
  return dio;
}

void main() {
  test('adds the headers Chrome attaches automatically', () async {
    final adapter = _RecordingAdapter();
    await _buildDio(adapter).get<dynamic>('https://api.novelai.net/user/data');

    final headers = adapter.requests.single.headers;
    expect(
      headers['user-agent'],
      const ChromeIdentity(platform: ChromePlatform.windows).userAgent,
    );
    expect(
      headers['sec-ch-ua'],
      '"Chromium";v="152", "Not?A_Brand";v="24", "Google Chrome";v="152"',
    );
    expect(headers['sec-ch-ua-mobile'], '?0');
    expect(headers['sec-ch-ua-platform'], '"Windows"');
    expect(headers['sec-fetch-dest'], 'empty');
    expect(headers['sec-fetch-mode'], 'cors');
    expect(headers['sec-fetch-site'], 'same-site');
    expect(headers['origin'], 'https://novelai.net');
    expect(headers['referer'], 'https://novelai.net/');
    expect(headers['accept'], '*/*');
    expect(headers['accept-language'], 'en-US,en;q=0.9');
    expect(headers['content-type'], 'application/json');
  });

  test('reads accept-language on every request', () async {
    final adapter = _RecordingAdapter();
    var language = 'zh-CN,zh;q=0.9';
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      BrowserHeadersInterceptor(
        identity: const ChromeIdentity(platform: ChromePlatform.windows),
        resolveAcceptLanguage: () => language,
      ),
    );

    await dio.get<dynamic>('https://api.novelai.net/user/data');
    language = 'ja,en-US;q=0.9,en;q=0.8';
    await dio.get<dynamic>('https://api.novelai.net/user/data');

    expect(adapter.requests[0].headers['accept-language'], 'zh-CN,zh;q=0.9');
    expect(
      adapter.requests[1].headers['accept-language'],
      'ja,en-US;q=0.9,en;q=0.8',
    );
  });

  test('keeps an explicitly requested Accept', () async {
    final adapter = _RecordingAdapter();
    await _buildDio(adapter).get<dynamic>(
      'https://api.novelai.net/user/data',
      options: Options(headers: {'Accept': 'application/x-msgpack'}),
    );

    expect(
      adapter.requests.single.headers['accept'],
      'application/x-msgpack',
    );
  });

  test('adds tracking headers in the official shape', () async {
    final adapter = _RecordingAdapter();
    await _buildDio(adapter).get<dynamic>('https://api.novelai.net/user/data');

    final headers = adapter.requests.single.headers;
    expect(headers['x-correlation-id'], matches(r'^[A-Za-km-z1-9]{6}$'));
    expect(
      headers['x-initiated-at'],
      matches(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$'),
    );
  });

  test('omits tracking headers when the request opts out', () async {
    final adapter = _RecordingAdapter();
    await _buildDio(adapter).get<dynamic>(
      'https://image.novelai.net/ai/generate-image/suggest-tags',
      options: Options(extra: omitTrackingHeadersExtra()),
    );

    final headers = adapter.requests.single.headers;
    expect(headers.containsKey('x-correlation-id'), isFalse);
    expect(headers.containsKey('x-initiated-at'), isFalse);
    expect(headers['user-agent'], isNotNull);
  });

  test('does not replace a correlation id set by the caller', () async {
    final adapter = _RecordingAdapter();
    await _buildDio(adapter).post<dynamic>(
      'https://image.novelai.net/ai/generate-image',
      data: utf8.encode('{}'),
      options: Options(headers: {'x-correlation-id': 'AbCdEf'}),
    );

    expect(adapter.requests.single.headers['x-correlation-id'], 'AbCdEf');
  });
}
