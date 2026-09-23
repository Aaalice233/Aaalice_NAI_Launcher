import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/browser_identity/browser_headers_interceptor.dart';
import 'package:nai_launcher/core/network/browser_identity/chrome_identity.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_tag_suggestion_api_service.dart';

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
      '{"tags":[{"tag":"1girl","count":12,"category":0}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

NAITagSuggestionApiService _buildService(_RecordingAdapter adapter) {
  final dio = Dio(
    BaseOptions(headers: Map<String, String>.of(ApiConstants.defaultHeaders)),
  )..httpClientAdapter = adapter;
  dio.interceptors.add(
    BrowserHeadersInterceptor(
      identity: const ChromeIdentity(platform: ChromePlatform.windows),
      resolveAcceptLanguage: () => 'en-US,en;q=0.9',
    ),
  );
  return NAITagSuggestionApiService(dio, NaiApiEndpointService());
}

void main() {
  test('puts the model before the prompt and adds the V5 tag set', () async {
    final adapter = _RecordingAdapter();

    final suggestions = await _buildService(
      adapter,
    ).suggestTags('sunset', model: ImageModels.animeDiffusionV5Full);

    expect(suggestions.single.tag, '1girl');
    expect(
      adapter.requests.single.uri.query,
      'model=nai-diffusion-5-full&prompt=sunset&type=animev5',
    );
  });

  test('omits the tag set for models before V5', () async {
    final adapter = _RecordingAdapter();

    await _buildService(
      adapter,
    ).suggestTags('sunset', model: ImageModels.animeDiffusionV45Full);

    expect(
      adapter.requests.single.uri.query,
      'model=nai-diffusion-4-5-full&prompt=sunset',
    );
  });

  test('sends no tracking headers on the suggestion endpoint', () async {
    final adapter = _RecordingAdapter();

    await _buildService(
      adapter,
    ).suggestTags('sunset', model: ImageModels.animeDiffusionV5Full);

    final headers = adapter.requests.single.headers;
    expect(headers.containsKey('x-correlation-id'), isFalse);
    expect(headers.containsKey('x-initiated-at'), isFalse);
    expect(headers['content-type'], 'application/json');
    expect(headers['user-agent'], isNotNull);
  });
}
