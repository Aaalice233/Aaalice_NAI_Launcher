import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_cache_database.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/danbooru_completion_source.dart';

void main() {
  test(
    'sends only the token and filters empty, deprecated, and invalid categories',
    () async {
      final adapter = _QueueAdapter([
        ResponseBody.fromString(
          jsonEncode([
            {
              'name': 'blue_eyes',
              'category': 0,
              'post_count': 100,
              'is_deprecated': false,
            },
            {
              'name': 'blue_artist',
              'category': 1,
              'post_count': 20,
              'is_deprecated': false,
            },
            {
              'name': 'e621_only',
              'category': 7,
              'post_count': 999,
              'is_deprecated': false,
            },
            {
              'name': 'empty',
              'category': 0,
              'post_count': 0,
              'is_deprecated': false,
            },
            {
              'name': 'old',
              'category': 0,
              'post_count': 10,
              'is_deprecated': true,
            },
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
        ..httpClientAdapter = adapter;
      final source = DanbooruCompletionSource(dio: dio, cache: _MemoryCache());

      final results = await source.search(_query('blue'));

      expect(results.map((candidate) => candidate.canonicalTag), [
        'blue_eyes',
        'blue_artist',
      ]);
      final request = adapter.requests.single;
      expect(request.path, '/tags.json');
      expect(request.queryParameters['search[name_matches]'], '*blue*');
      expect(request.queryParameters['limit'], 50);
      expect(request.queryParameters.values, isNot(contains('secret prompt')));
    },
  );

  test(
    'uses prefix matching for short tokens and a five-minute memory cache',
    () async {
      final adapter = _QueueAdapter([
        ResponseBody.fromString(
          '[{"name":"1girl","category":0,"post_count":100}]',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
        ..httpClientAdapter = adapter;
      final source = DanbooruCompletionSource(dio: dio, cache: _MemoryCache());

      await source.search(_query('1g'));
      await source.search(_query('1g'));

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.queryParameters['search[name_matches]'],
        '1g*',
      );
    },
  );

  test('parses nested related-tag records with official categories', () async {
    final adapter = _QueueAdapter([
      ResponseBody.fromString(
        jsonEncode({
          'related_tags': [
            {
              'tag': {
                'name': 'solo',
                'category': 0,
                'post_count': 1000,
                'is_deprecated': false,
              },
              'frequency': 0.8,
              'count': 800,
            },
            {
              'tag': {'name': 'unsupported', 'category': 7, 'post_count': 20},
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
      ..httpClientAdapter = adapter;
    final source = DanbooruCompletionSource(dio: dio, cache: _MemoryCache());

    final results = await source.relatedTags('1girl');

    expect(results, hasLength(1));
    expect(results.single.canonicalTag, 'solo');
    expect(results.single.postCount, 1000);
    expect(results.single.relatedScore, 0.8);
    expect(results.single.cooccurrenceCount, 800);
    expect(adapter.requests.single.path, '/related_tag.json');
    expect(adapter.requests.single.queryParameters, {
      'query': '1girl',
      'limit': 20,
      'order': 'jaccard',
    });
  });

  test('fetches up to twice the visible result target', () async {
    final adapter = _QueueAdapter([
      ResponseBody.fromString(
        '[]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
      ..httpClientAdapter = adapter;
    final source = DanbooruCompletionSource(dio: dio, cache: _MemoryCache());

    await source.search(_query('blue', limit: 100));

    expect(adapter.requests.single.queryParameters['limit'], 200);
  });

  test('paginates exhaustive searches until the final API page', () async {
    Map<String, dynamic> tag(int index) => {
      'name': 'blue_archive_$index',
      'category': 0,
      'post_count': 2000 - index,
      'is_deprecated': false,
    };
    final adapter = _QueueAdapter([
      ResponseBody.fromString(
        jsonEncode(List.generate(1000, tag)),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        jsonEncode([tag(1000), tag(1001)]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
      ..httpClientAdapter = adapter;
    final source = DanbooruCompletionSource(dio: dio, cache: _MemoryCache());

    final results = await source.search(
      _query('blue_archive', limit: CompletionResultLimits.all),
    );

    expect(results, hasLength(1002));
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.queryParameters['limit'], 1000);
    expect(adapter.requests.first.queryParameters, isNot(contains('page')));
    expect(adapter.requests.last.queryParameters['page'], 2);
  });

  test('opens the circuit for thirty seconds after three failures', () async {
    final adapter = _QueueAdapter(
      List.generate(3, (_) => ResponseBody.fromString('failed', 500)),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
      ..httpClientAdapter = adapter;
    final source = DanbooruCompletionSource(dio: dio, cache: _MemoryCache());

    await source.search(_query('blue'));
    await source.search(_query('green'));
    await source.search(_query('red'));
    final result = await source.search(_query('yellow'));

    expect(source.circuitOpen, isTrue);
    expect(adapter.requests, hasLength(3));
    expect(result, isEmpty);
  });
}

CompletionQuery _query(String token, {int limit = 20}) => CompletionQuery(
  fullText: 'secret prompt, $token',
  cursorPosition: token.length,
  token: token,
  replacementRange: TextReplacementRange(start: 0, end: token.length),
  existingTags: const {},
  limit: limit,
  locale: 'en',
);

class _MemoryCache extends AutocompleteCacheDatabase {
  final Map<String, CachedAutocompletePayload> values = {};

  @override
  Future<CachedAutocompletePayload?> getRemote(String key) async => values[key];

  @override
  Future<void> putRemote(String key, List<Map<String, dynamic>> payload) async {
    values[key] = CachedAutocompletePayload(
      payload: payload,
      fetchedAt: DateTime.now().toUtc(),
    );
  }
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<ResponseBody> responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responses.isEmpty) {
      throw StateError('No queued response');
    }
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}
