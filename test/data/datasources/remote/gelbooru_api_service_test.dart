import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/gelbooru_api_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';

void main() {
  const credentials = GelbooruCredentials(
    userId: 24680,
    apiKey: 'secret-gelbooru-api-key',
  );

  group('GelbooruApiService', () {
    test(
      'verifies credentials with a parseable one-post DAPI request',
      () async {
        final adapter = _RecordingAdapter.json({
          '@attributes': {'count': 0},
        });
        final service = _service(adapter);

        await service.verifyCredentials(credentials);

        final request = adapter.requests.single;
        expect(request.uri.toString(), startsWith(GelbooruApiService.endpoint));
        expect(request.queryParameters['page'], 'dapi');
        expect(request.queryParameters['s'], 'post');
        expect(request.queryParameters['q'], 'index');
        expect(request.queryParameters['json'], 1);
        expect(request.queryParameters['limit'], 1);
        expect(request.queryParameters['pid'], 0);
        expect(request.queryParameters['user_id'], credentials.userId);
        expect(request.queryParameters['api_key'], credentials.apiKey);
      },
    );

    test('parses nested posts, dimensions, ratings, and pagination', () async {
      final adapter = _RecordingAdapter.json({
        '@attributes': {'count': 1},
        'post': [
          {
            'id': '42',
            'score': '7',
            'rating': 'questionable',
            'width': '1280',
            'height': 720,
            'tags': 'solo blue_hair',
            'file_url': 'https://img3.gelbooru.com/images/a/b/file.png',
            'preview_url':
                'https://img3.gelbooru.com/thumbnails/a/b/thumbnail.jpg',
          },
        ],
      });
      final service = _service(adapter);

      final page = await service.searchPosts(
        credentials: credentials,
        tags: 'solo rating:questionable',
        pid: 3,
        limit: 40,
      );

      expect(page.rawCount, 1);
      expect(page.posts, hasLength(1));
      expect(page.posts.single.id, 42);
      expect(page.posts.single.site, 'gelbooru');
      expect(page.posts.single.rating, 'q');
      expect(page.posts.single.width, 1280);
      expect(page.posts.single.height, 720);
      expect(adapter.requests.single.queryParameters['pid'], 3);
      expect(adapter.requests.single.queryParameters['limit'], 40);
      expect(
        adapter.requests.single.queryParameters['tags'],
        'solo rating:questionable',
      );
    });

    test('uses the documented fast favorites search expression', () async {
      final adapter = _RecordingAdapter.json(<dynamic>[]);
      final service = _service(adapter);

      await service.getFavorites(credentials: credentials, pid: 2, limit: 40);

      expect(
        adapter.requests.single.queryParameters['tags'],
        'fav:24680 sort:id:desc',
      );
      expect(adapter.requests.single.queryParameters['pid'], 2);
    });

    for (final status in [401, 403]) {
      test('$status becomes a safe invalid-credentials error', () async {
        final adapter = _RecordingAdapter.error(status);
        final service = _service(adapter);

        final future = service.searchPosts(
          credentials: credentials,
          tags: 'solo',
          pid: 0,
        );

        await expectLater(
          future,
          throwsA(
            isA<GelbooruApiException>()
                .having(
                  (error) => error.type,
                  'type',
                  GelbooruApiErrorType.invalidCredentials,
                )
                .having((error) => error.statusCode, 'statusCode', status)
                .having(
                  (error) => error.toString(),
                  'safe text',
                  allOf(
                    isNot(contains(credentials.apiKey)),
                    isNot(contains('user_id')),
                    isNot(contains('https://')),
                  ),
                ),
          ),
        );
      });
    }

    test('preserves rate-limit classification without exposing the URI', () {
      final service = _service(_RecordingAdapter.error(429));

      expectLater(
        service.searchPosts(credentials: credentials, tags: 'solo', pid: 0),
        throwsA(
          isA<GelbooruApiException>()
              .having(
                (error) => error.type,
                'type',
                GelbooruApiErrorType.rateLimited,
              )
              .having((error) => error.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('classifies server errors', () {
      final service = _service(_RecordingAdapter.error(503));

      expectLater(
        service.searchPosts(credentials: credentials, tags: 'solo', pid: 0),
        throwsA(
          isA<GelbooruApiException>().having(
            (error) => error.type,
            'type',
            GelbooruApiErrorType.server,
          ),
        ),
      );
    });

    test('classifies timeouts', () {
      final service = _service(
        _RecordingAdapter.dioError(DioExceptionType.receiveTimeout),
      );

      expectLater(
        service.searchPosts(credentials: credentials, tags: 'solo', pid: 0),
        throwsA(
          isA<GelbooruApiException>().having(
            (error) => error.type,
            'type',
            GelbooruApiErrorType.timeout,
          ),
        ),
      );
    });

    test('cancellation does not become an authentication failure', () {
      final service = _service(_RecordingAdapter.json(<dynamic>[]));
      final cancelToken = CancelToken()..cancel('test');

      expectLater(
        service.searchPosts(
          credentials: credentials,
          tags: 'solo',
          pid: 0,
          cancelToken: cancelToken,
        ),
        throwsA(
          isA<GelbooruApiException>().having(
            (error) => error.type,
            'type',
            GelbooruApiErrorType.cancelled,
          ),
        ),
      );
    });

    test('rejects a successful but unparseable response', () {
      final service = _service(_RecordingAdapter.text('<html>blocked</html>'));

      expectLater(
        service.verifyCredentials(credentials),
        throwsA(
          isA<GelbooruApiException>().having(
            (error) => error.type,
            'type',
            GelbooruApiErrorType.malformedResponse,
          ),
        ),
      );
    });
  });
}

GelbooruApiService _service(_RecordingAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return GelbooruApiService(dio);
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Future<ResponseBody> Function(RequestOptions options) _handler;

  _RecordingAdapter._(this._handler);

  factory _RecordingAdapter.json(dynamic body) {
    return _RecordingAdapter._(
      (_) async => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  factory _RecordingAdapter.text(String body) {
    return _RecordingAdapter._(
      (_) async => ResponseBody.fromString(
        body,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.textPlainContentType],
        },
      ),
    );
  }

  factory _RecordingAdapter.error(int statusCode) {
    return _RecordingAdapter._((options) async {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: statusCode,
          data: 'sensitive response body',
        ),
        type: DioExceptionType.badResponse,
      );
    });
  }

  factory _RecordingAdapter.dioError(DioExceptionType type) {
    return _RecordingAdapter._((options) async {
      throw DioException(requestOptions: options, type: type);
    });
  }

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
