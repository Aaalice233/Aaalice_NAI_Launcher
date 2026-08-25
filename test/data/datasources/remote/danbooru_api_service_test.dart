import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';

void main() {
  test(
    'fetch preserves Danbooru rule lines instead of splitting terms',
    () async {
      final adapter = _RecordingAdapter(
        profile: {
          'id': 42,
          'name': 'tester',
          'blacklisted_tags': 'simple_tag\nfurry -rating:g\nstatus:any',
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = DanbooruApiService(dio)..setAuthHeader('Basic test');

      final rules = await service.fetchBlacklistRules();

      expect(rules, ['simple_tag', 'furry -rating:g', 'status:any']);
    },
  );

  test('update enforces Danbooru rule, term, and payload limits', () async {
    final adapter = _RecordingAdapter(profile: {'id': 42, 'name': 'tester'});
    final dio = Dio()..httpClientAdapter = adapter;
    final service = DanbooruApiService(dio)..setAuthHeader('Basic test');

    await expectLater(
      service.updateBlacklistRules([
        for (var index = 0; index < 5001; index++) 'tag_$index',
      ]),
      throwsA(isA<FormatException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('account-bound update never resolves a replacement account', () async {
    final adapter = _RecordingAdapter(profile: {'id': 99, 'name': 'other'});
    final dio = Dio()..httpClientAdapter = adapter;
    final service = DanbooruApiService(dio)..setAuthHeader('Basic test');

    await service.updateBlacklistRules(['simple_tag'], expectedUserId: 42);

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, endsWith('/users/42.json'));
  });

  test(
    'update sends one newline document and falls back from PUT to PATCH',
    () async {
      final adapter = _RecordingAdapter(
        profile: {'id': 42, 'name': 'tester'},
        rejectPut: true,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = DanbooruApiService(dio)
        ..setAuthHeader('Basic dGVzdGVyOmFwaS1rZXk=');

      await service.updateBlacklistRules(['simple_tag', 'furry -rating:g']);

      expect(adapter.requests.map((request) => request.method), [
        'GET',
        'PUT',
        'PATCH',
      ]);
      final patch = adapter.requests.last;
      expect(patch.path, endsWith('/users/42.json'));
      expect(patch.queryParameters, {'login': 'tester', 'api_key': 'api-key'});
      expect(patch.data, {
        'user[blacklisted_tags]': 'simple_tag\nfurry -rating:g',
      });
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.profile, this.rejectPut = false});

  final Map<String, Object?> profile;
  final bool rejectPut;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path.endsWith('/profile.json')) {
      return ResponseBody.fromString(
        jsonEncode(profile),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (rejectPut && options.method == 'PUT') {
      return ResponseBody.fromString('not allowed', 405);
    }
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
