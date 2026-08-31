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

      expect(result.subscriptionUnsupported, isFalse);
      expect(result.subscriptionInfo?['tier'], 3);
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

        final result = await service.validateToken(
          'compatible-token',
          endpoint: endpoint,
          allowAnyTokenFormat: true,
        );

        expect(result.subscriptionUnsupported, isFalse);
        expect(result.subscriptionInfo, isNotNull);
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

  group('third-party subscription fallback', () {
    final endpoint = NaiApiEndpointConfig.fromInput(
      mainBaseUrl: 'https://relay.example',
      imageBaseUrl: 'https://images.relay.example',
    );

    NAIAuthApiService serviceWith(_ScriptedDioAdapter adapter) {
      final dio = Dio()..httpClientAdapter = adapter;
      return NAIAuthApiService(dio);
    }

    _ScriptedDioAdapter adapterWith({
      required ResponseBody Function(RequestOptions options) onSubscription,
      required ResponseBody Function(RequestOptions options) onProbe,
    }) {
      return _ScriptedDioAdapter((options) {
        if (options.path.endsWith(ApiConstants.userSubscriptionEndpoint)) {
          return onSubscription(options);
        }
        if (options.path.endsWith(ApiConstants.generateImageEndpoint)) {
          return onProbe(options);
        }
        fail('Unexpected request: ${options.uri}');
      });
    }

    test(
      'missing /user/subscription falls back to image endpoint probe',
      () async {
        final adapter = adapterWith(
          onSubscription: (_) => _jsonResponse({'detail': 'Not Found'}, 404),
          onProbe: (_) => _jsonResponse({'error': '提示词不能为空'}, 400),
        );
        final service = serviceWith(adapter);

        final result = await service.validateToken(
          'sk-relay-token',
          endpoint: endpoint,
          allowAnyTokenFormat: true,
        );

        expect(result.subscriptionUnsupported, isTrue);
        expect(result.subscriptionInfo, isNull);
        expect(adapter.requests, hasLength(2));
        final probe = adapter.requests[1];
        expect(
          probe.uri.toString(),
          'https://images.relay.example${ApiConstants.generateImageEndpoint}',
        );
        expect(probe.method, 'POST');
        expect(probe.headers['Authorization'], 'Bearer sk-relay-token');
      },
    );

    test('subscription 200 with HTML body also falls back to probe', () async {
      final adapter = adapterWith(
        onSubscription: (_) =>
            _htmlResponse('<!doctype html><html></html>', 200),
        onProbe: (_) => _jsonResponse({'error': 'validation failed'}, 422),
      );
      final service = serviceWith(adapter);

      final result = await service.validateToken(
        'sk-relay-token',
        endpoint: endpoint,
        allowAnyTokenFormat: true,
      );

      expect(result.subscriptionUnsupported, isTrue);
      expect(adapter.requests, hasLength(2));
    });

    test('probe 401 fails login with auth error', () async {
      final adapter = adapterWith(
        onSubscription: (_) => _jsonResponse({'detail': 'Not Found'}, 404),
        onProbe: (_) => _jsonResponse({'error': 'invalid_api_key'}, 401),
      );
      final service = serviceWith(adapter);

      await expectLater(
        service.validateToken(
          'sk-wrong-token',
          endpoint: endpoint,
          allowAnyTokenFormat: true,
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('probe 404 reports incompatible endpoint', () async {
      final adapter = adapterWith(
        onSubscription: (_) => _jsonResponse({'detail': 'Not Found'}, 404),
        onProbe: (_) => _htmlResponse('Cannot POST /ai/generate-image', 404),
      );
      final service = serviceWith(adapter);

      await expectLater(
        service.validateToken(
          'sk-relay-token',
          endpoint: endpoint,
          allowAnyTokenFormat: true,
        ),
        throwsA(
          isA<NaiEndpointIncompatibleException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('probe 5xx surfaces server error instead of success', () async {
      final adapter = adapterWith(
        onSubscription: (_) => _jsonResponse({'detail': 'Not Found'}, 404),
        onProbe: (_) => _jsonResponse({'error': 'bad gateway'}, 502),
      );
      final service = serviceWith(adapter);

      await expectLater(
        service.validateToken(
          'sk-relay-token',
          endpoint: endpoint,
          allowAnyTokenFormat: true,
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
    });

    test('official 404 keeps failing without probe', () async {
      final adapter = _ScriptedDioAdapter(
        (_) => _jsonResponse({'message': 'Not Found'}, 404),
      );
      final service = serviceWith(adapter);

      await expectLater(
        service.validateToken('pst-validTokenForEndpointRouting'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, hasLength(1));
    });
  });
}

ResponseBody _jsonResponse(Object payload, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _htmlResponse(String body, int statusCode) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    },
  );
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

    return _jsonResponse(response, 200);
  }

  @override
  void close({bool force = false}) {}
}

class _ScriptedDioAdapter implements HttpClientAdapter {
  _ScriptedDioAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
