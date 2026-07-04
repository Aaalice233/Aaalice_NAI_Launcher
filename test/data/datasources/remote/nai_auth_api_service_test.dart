import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';

void main() {
  group('NAIAuthApiService', () {
    test('validates official token through image user endpoint', () async {
      final adapter = _RecordingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = NAIAuthApiService(dio);

      final result = await service.validateToken(
        'pst-1234567890abcdef',
        endpoint: NaiApiEndpointConfig.official,
      );

      expect(result['tier'], 3);
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.uri.toString(),
        'https://image.novelai.net/user/subscription',
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer pst-1234567890abcdef',
      );
    });

    test('keeps login requests on main endpoint', () async {
      final adapter = _RecordingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = NAIAuthApiService(dio);

      final result = await service.loginWithKey(
        'access-key',
        endpoint: NaiApiEndpointConfig.official,
      );

      expect(result['accessToken'], 'jwt-token');
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.novelai.net/user/login',
      );
    });
  });
}

class _RecordingDioAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final response = options.path.endsWith(ApiConstants.loginEndpoint)
        ? {'accessToken': 'jwt-token'}
        : {
            'tier': 3,
            'trainingStepsLeft': {
              'fixedTrainingStepsLeft': 100,
              'purchasedTrainingSteps': 20,
            },
          };

    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
