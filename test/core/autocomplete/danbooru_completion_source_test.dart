import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_cache_database.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/danbooru_completion_source.dart';

import '../../helpers/database_error_probe.dart';
import '../../helpers/log_capture.dart';

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

  test('cache write failures never quote the typed tag into the log', () async {
    final adapter = _QueueAdapter([
      ResponseBody.fromString(
        '[{"name":"lighthouse","category":0,"post_count":10}]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      ResponseBody.fromString(
        '{"related_tags":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    ]);
    final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
      ..httpClientAdapter = adapter;
    final source = DanbooruCompletionSource(
      dio: dio,
      cache: _FailingWriteCache(),
    );

    final logs = await captureLogs(() async {
      await source.search(_query('lighthouse'));
      await source.relatedTags('lighthouse');
    });

    expect(logs.where((line) => line.contains('Danbooru')), hasLength(2));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });

  group('memory cache bounds', () {
    test('evicts the least recently used entry beyond the entry cap', () async {
      final cache = _MemoryCache();
      String token(int index) => 'aa${index.toString().padLeft(3, '0')}';
      for (var index = 0; index <= 64; index++) {
        cache.seed(_tagKey(token(index)), _payload(token(index), 1));
      }
      final source = DanbooruCompletionSource(
        dio: Dio()..httpClientAdapter = _QueueAdapter([]),
        cache: cache,
      );

      for (var index = 0; index < 64; index++) {
        await source.search(_query(token(index)));
      }
      await source.search(_query(token(0)));
      await source.search(_query(token(64)));
      final readsBeforeRevisit = cache.getRemoteCalls;

      await source.search(_query(token(0)));
      await source.search(_query(token(64)));
      expect(cache.getRemoteCalls, readsBeforeRevisit);

      await source.search(_query(token(1)));
      expect(cache.getRemoteCalls, readsBeforeRevisit + 1);
    });

    test('keeps the total candidate count within the memory budget', () async {
      final cache = _MemoryCache()
        ..seed(_tagKey('first'), _payload('first', 20000))
        ..seed(_tagKey('second'), _payload('second', 20000))
        ..seed(_tagKey('third'), _payload('third', 20000));
      final source = DanbooruCompletionSource(
        dio: Dio()..httpClientAdapter = _QueueAdapter([]),
        cache: cache,
      );

      await source.search(_query('first'));
      await source.search(_query('second'));
      await source.search(_query('third'));
      final readsBeforeRevisit = cache.getRemoteCalls;

      expect(await source.search(_query('third')), hasLength(20000));
      expect(await source.search(_query('second')), hasLength(20000));
      expect(cache.getRemoteCalls, readsBeforeRevisit);

      expect(await source.search(_query('first')), hasLength(20000));
      expect(cache.getRemoteCalls, readsBeforeRevisit + 1);
    });

    test(
      'never keeps a single result larger than the budget in memory',
      () async {
        final cache = _MemoryCache()
          ..seed(_tagKey('huge'), _payload('huge', 50001));
        final source = DanbooruCompletionSource(
          dio: Dio()..httpClientAdapter = _QueueAdapter([]),
          cache: cache,
        );

        expect(await source.search(_query('huge')), hasLength(50001));
        expect(await source.search(_query('huge')), hasLength(50001));

        expect(cache.getRemoteCalls, 2);
      },
    );

    test('deletes expired entries instead of only skipping them', () async {
      var now = DateTime.now();
      final cache = _MemoryCache()
        ..seed(_tagKey('first'), _payload('first', 3))
        ..seed(_tagKey('second'), _payload('second', 2))
        ..seed('related:v3:unseen:20', _payload('unseen', 1));
      final source = DanbooruCompletionSource(
        dio: Dio()..httpClientAdapter = _QueueAdapter([]),
        cache: cache,
        now: () => now,
      );

      await source.search(_query('first'));
      expect(source.memoryEntryCount, 1);
      expect(source.memoryCandidateCount, 3);

      now = now.add(DanbooruCompletionSource.memoryTtl);
      await source.search(_query('second'));
      expect(source.memoryEntryCount, 1);
      expect(source.memoryCandidateCount, 2);

      final readsBeforeExpiry = cache.getRemoteCalls;
      await source.search(_query('second'));
      expect(cache.getRemoteCalls, readsBeforeExpiry);
      now = now.add(DanbooruCompletionSource.memoryTtl);
      await source.relatedTags('unseen');
      expect(source.memoryEntryCount, 1);
      expect(source.memoryCandidateCount, 1);
      await source.search(_query('second'));
      expect(cache.getRemoteCalls, readsBeforeExpiry + 2);
    });
  });

  test('dropped connections never quote the request URI into the log', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://danbooru.donmai.us'))
      ..httpClientAdapter = _DroppedConnectionAdapter();
    final source = DanbooruCompletionSource(dio: dio, cache: _MemoryCache());

    final logs = await captureLogs(() async {
      await source.search(_query('lighthouse'));
      await source.relatedTags('lighthouse');
    });

    expect(logs.where((line) => line.contains(' failed')), hasLength(2));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
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

String _tagKey(String token, {int limit = 20}) => 'tags:$token:all:$limit';

List<Map<String, dynamic>> _payload(String prefix, int count) => [
  for (var index = 0; index < count; index++)
    {
      'tag': '${prefix}_$index',
      'category': 0,
      'postCount': count - index,
      'matchKind': CompletionMatchKind.fullText.name,
    },
];

class _MemoryCache extends AutocompleteCacheDatabase {
  final Map<String, CachedAutocompletePayload> values = {};
  int getRemoteCalls = 0;

  void seed(String key, List<Map<String, dynamic>> payload) {
    values[key] = CachedAutocompletePayload(
      payload: payload,
      fetchedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<CachedAutocompletePayload?> getRemote(String key) async {
    getRemoteCalls++;
    return values[key];
  }

  @override
  Future<void> putRemote(String key, List<Map<String, dynamic>> payload) async {
    values[key] = CachedAutocompletePayload(
      payload: payload,
      fetchedAt: DateTime.now().toUtc(),
    );
  }
}

class _FailingWriteCache extends _MemoryCache {
  @override
  Future<void> putRemote(String key, List<Map<String, dynamic>> payload) async {
    throw await databaseErrorCarrying(key);
  }
}

class _DroppedConnectionAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw HttpException(
      'Connection closed before full header was received',
      uri: options.uri,
    );
  }

  @override
  void close({bool force = false}) {}
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
