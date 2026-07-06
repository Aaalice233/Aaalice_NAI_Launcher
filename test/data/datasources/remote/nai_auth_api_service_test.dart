import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';

void main() {
  group('NAI subscription endpoint routing', () {
    test('validateToken uses the official image host', () async {
      final adapter = _RecordingDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = NAIAuthApiService(dio);

      await service.validateToken('pst-validTokenForEndpointRouting');

      expect(
        adapter.requests.single.uri.toString(),
        '${ApiConstants.imageBaseUrl}${ApiConstants.userSubscriptionEndpoint}',
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer pst-validTokenForEndpointRouting',
      );
    });

    test('getUserSubscription uses the current image host', () async {
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
    return ResponseBody.fromString(
      jsonEncode({
        'tier': 3,
        'active': true,
        'trainingStepsLeft': {
          'fixedTrainingStepsLeft': 0,
          'purchasedTrainingSteps': 0,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
