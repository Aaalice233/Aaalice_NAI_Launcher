import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart';

AiTagGallerySourceAdapter aiTagCharacterGallery() => AiTagGallerySourceAdapter(
  dio: Dio()..httpClientAdapter = _AiTagHttp(),
  random: Random(1),
);

class _AiTagHttp implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = switch (options.uri.path) {
      '/api/config' => {'asset_base_url': 'https://example.test/images/'},
      '/api/ai_works_search' || '/api/rank/monthly/real' => {
        'page': 1,
        'page_size': 60,
        'total': 2,
        'items': [_work(11), _work(22)],
      },
      '/api/work/11' => _detail(11),
      '/api/work/22' => _detail(22),
      _ => throw StateError('Unexpected AI TAG request: ${options.uri.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _work(int id) => {
  'id': id,
  'tags': ['anchor'],
  'title': 'Title only',
  'image_count': 2,
};

Map<String, dynamic> _detail(int id) => {
  'work': _work(id),
  'images': [
    for (var page = 0; page < 2; page++)
      {
        'file_name': '${id}_p$page',
        'image_type': 'NovelAI',
        'author_id': '7',
        'ai_json': {
          'prompt': 'sunset',
          'uc': 'blue cape, main negative',
          'seed': 123,
          'steps': 28,
          'v4_prompt': {
            'caption': {
              'base_caption': 'sunset',
              'char_captions': [
                {
                  'char_caption': id == 11 && page == 1
                      ? '1.2::brass badge::, {{green eyes}}, [silver ribbon], (blue cape:1.2)'
                      : 'round glasses',
                },
              ],
            },
          },
          'v4_negative_prompt': {
            'caption': {
              'base_caption': 'blue cape, main negative',
              'char_captions': [
                {
                  'char_caption':
                      'brass badge, green eyes, silver ribbon, character negative',
                },
              ],
            },
          },
        },
      },
  ],
};
