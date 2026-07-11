import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';

void main() {
  group('NAI user endpoint routing', () {
    test('validateToken uses the official image user endpoint', () async {
      final adapter = _RecordingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = NAIAuthApiService(dio);

      final result = await service.validateToken(
        'pst-validTokenForEndpointRouting',
        endpoint: NaiApiEndpointConfig.official,
      );

      expect(result['tier'], 3);
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.uri.toString(),
        '${ApiConstants.imageBaseUrl}${ApiConstants.userSubscriptionEndpoint}',
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer pst-validTokenForEndpointRouting',
      );
    });

    test(
      'validateToken keeps third-party user endpoints on main host',
      () async {
        final adapter = _RecordingDioAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final service = NAIAuthApiService(dio);
        final endpoint = NaiApiEndpointConfig.fromInput(
          mainBaseUrl: 'https://compatible.example',
          imageBaseUrl: 'https://images.compatible.example',
        );

        await service.validateToken(
          'compatible-token',
          endpoint: endpoint,
          allowAnyTokenFormat: true,
        );

        expect(
          adapter.requests.single.uri.toString(),
          'https://compatible.example${ApiConstants.userSubscriptionEndpoint}',
        );
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer compatible-token',
        );
      },
    );

    test('getUserSubscription uses the current official image host', () async {
      final adapter = _RecordingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final endpointService = NaiApiEndpointService();
      final service = NAIUserInfoApiService(dio, endpointService);

      await service.getUserSubscription();

      expect(
        adapter.requests.single.uri.toString(),
        '${ApiConstants.imageBaseUrl}${ApiConstants.userSubscriptionEndpoint}',
      );
    });

    test('routes official login requests through the image host', () async {
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
        '${ApiConstants.imageBaseUrl}${ApiConstants.loginEndpoint}',
      );
    });

    test('keeps third-party login requests on the main host', () async {
      final adapter = _RecordingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = NAIAuthApiService(dio);
      final endpoint = NaiApiEndpointConfig.fromInput(
        mainBaseUrl: 'https://compatible.example',
        imageBaseUrl: 'https://images.compatible.example',
      );

      await service.loginWithKey('access-key', endpoint: endpoint);

      expect(
        adapter.requests.single.uri.toString(),
        'https://compatible.example${ApiConstants.loginEndpoint}',
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
            'active': true,
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
