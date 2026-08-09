import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/donmai_gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

void main() {
  group('DonmaiGallerySourceAdapter', () {
    test(
      'keeps Safebooru search on donmai and omits unsupported ratings',
      () async {
        final http = _RecordingHttpAdapter((request) {
          expect(request.uri.host, 'safebooru.donmai.us');
          expect(request.uri.path, '/posts.json');
          expect(request.queryParameters['page'], 'b500');
          final tags = request.queryParameters['tags']!.toString();
          expect(tags, contains('cat_girl'));
          expect(tags, contains('date:2026-01-01..2026-01-31'));
          expect(tags, contains('-guro'));
          expect(tags, isNot(contains('rating:')));
          return [_donmaiPost(499)];
        });
        final adapter = DonmaiGallerySourceAdapter(
          sourceId: GallerySourceId.safebooru,
          dio: Dio()..httpClientAdapter = http,
        );

        final page = await adapter.search(
          GallerySearchRequest(
            cursor: 'b500',
            pageSize: 60,
            query: 'cat_girl',
            ratings: const {'g'},
            dateStart: DateTime(2026, 1, 1),
            dateEnd: DateTime(2026, 1, 31),
            blacklistTags: const {'guro'},
          ),
        );

        expect(page.items.single.sourceId, GallerySourceId.safebooru);
        expect(page.nextCursor, 'b499');
      },
    );

    test('sends real scale, date, and page to Safebooru ranking', () async {
      final http = _RecordingHttpAdapter((request) {
        expect(request.uri.host, 'safebooru.donmai.us');
        expect(request.uri.path, '/explore/posts/popular.json');
        expect(request.queryParameters['scale'], 'week');
        expect(request.queryParameters['date'], '2026-08-03');
        expect(request.queryParameters['page'], 2);
        return [_donmaiPost(21)];
      });
      final adapter = DonmaiGallerySourceAdapter(
        sourceId: GallerySourceId.safebooru,
        dio: Dio()..httpClientAdapter = http,
      );

      final page = await adapter.ranking(
        GalleryRankingRequest(
          cursor: '2',
          pageSize: 40,
          kind: GalleryRankingKind.week,
          date: DateTime(2026, 8, 3),
        ),
      );

      expect(page.items.single.sourceId, GallerySourceId.safebooru);
      expect(page.items.single.rank, 41);
      expect(page.nextCursor, '3');
    });

    test(
      'uses before-id cursor for deterministic search continuation',
      () async {
        final http = _RecordingHttpAdapter(
          (_) => [_donmaiPost(30), _donmaiPost(20)],
        );
        final adapter = DonmaiGallerySourceAdapter(
          sourceId: GallerySourceId.danbooru,
          dio: Dio()..httpClientAdapter = http,
        );

        final page = await adapter.search(
          const GallerySearchRequest(
            cursor: '1',
            pageSize: 2,
            query: '1girl',
            ratings: {'g', 's', 'q', 'e'},
          ),
        );

        expect(page.nextCursor, 'b20');
        expect(http.requests.single.queryParameters['tags'], '1girl');
      },
    );
  });

  group('AiTagGallerySourceAdapter', () {
    test(
      'caches config and sends composable q, prompt, and time_range',
      () async {
        final http = _RecordingHttpAdapter((request) {
          if (request.uri.path == '/api/config') return _configJson;
          expect(request.uri.path, '/api/ai_works_search');
          expect(request.queryParameters['q'], 'artist name');
          expect(request.queryParameters['prompt'], '::artist:');
          expect(request.queryParameters['time_range'], 'q2026Q2');
          expect(request.queryParameters['page'], 2);
          return {
            'page': 2,
            'page_size': 60,
            'total': 121,
            'items': [
              _aiWork(100),
              'bad',
              {'id': 'invalid'},
            ],
          };
        });
        final adapter = AiTagGallerySourceAdapter(
          dio: Dio()..httpClientAdapter = http,
        );

        final firstConfig = await adapter.getConfig();
        final secondConfig = await adapter.getConfig();
        final page = await adapter.search(
          const GallerySearchRequest(
            cursor: '2',
            pageSize: 60,
            query: 'artist name',
            prompt: '::artist:',
            timeRange: 'q2026Q2',
          ),
        );

        expect(identical(firstConfig, secondConfig), isTrue);
        expect(
          http.requests.where((r) => r.uri.path == '/api/config'),
          hasLength(1),
        );
        expect(firstConfig.rankMonths.first, '2026-07');
        expect(
          firstConfig.timeRanges.keys,
          containsAll(['all', 'y2026', 'q2026Q2', 'older']),
        );
        expect(page.items.map((item) => item.id), [100]);
        expect(page.hasMore, isTrue);
        expect(page.nextCursor, '3');
      },
    );

    test(
      'uses live, fixed month, and older monthly ranking contracts',
      () async {
        final http = _RecordingHttpAdapter((request) {
          if (request.uri.path == '/api/config') return _configJson;
          return {
            'page': 1,
            'page_size': 60,
            'total': 1,
            'items': [_aiWork(101)],
          };
        });
        final adapter = AiTagGallerySourceAdapter(
          dio: Dio()..httpClientAdapter = http,
        );

        for (final period in ['current', '2026-07', 'older']) {
          await adapter.ranking(
            GalleryRankingRequest(
              cursor: '1',
              pageSize: 60,
              kind: GalleryRankingKind.aiTagMonthly,
              period: period,
              query: 'NAI',
              prompt: 'artist:',
            ),
          );
        }

        final rankRequests = http.requests
            .where(
              (request) => request.uri.path.startsWith('/api/rank/monthly'),
            )
            .toList();
        expect(rankRequests[0].uri.path, '/api/rank/monthly/real');
        expect(rankRequests[1].uri.path, '/api/rank/monthly/fixed');
        expect(rankRequests[1].queryParameters['month'], '2026-07');
        expect(rankRequests[2].queryParameters['month'], 'older');
        expect(
          rankRequests.every((r) => r.queryParameters['q'] == 'NAI'),
          isTrue,
        );
        expect(
          rankRequests.every((r) => r.queryParameters['prompt'] == 'artist:'),
          isTrue,
        );
      },
    );

    test(
      'recognizes rank_processing instead of returning an empty ranking',
      () async {
        final http = _RecordingHttpAdapter((request) {
          if (request.uri.path == '/api/config') return _configJson;
          return {'error': 'rank_processing', 'items': <Object?>[]};
        });
        final adapter = AiTagGallerySourceAdapter(
          dio: Dio()..httpClientAdapter = http,
        );

        expect(
          () => adapter.ranking(
            const GalleryRankingRequest(
              cursor: '1',
              pageSize: 60,
              kind: GalleryRankingKind.aiTagMonthly,
            ),
          ),
          throwsA(
            isA<GallerySourceException>().having(
              (error) => error.code,
              'code',
              GallerySourceErrorCode.rankingProcessing,
            ),
          ),
        );
      },
    );

    test('builds all CDN media in _pN order and preserves metadata', () async {
      final http = _RecordingHttpAdapter((request) {
        if (request.uri.path == '/api/config') return _configJson;
        if (request.uri.path == '/api/work/501') {
          return {
            'work': _aiWork(501),
            'images': [
              _aiImage('501_p10'),
              _aiImage('501_p2'),
              _comfyAiImage('501_p3'),
              {'file_name': 'broken'},
              _aiImage('501_p0'),
            ],
          };
        }
        throw StateError('Unexpected request ${request.uri}');
      });
      final adapter = AiTagGallerySourceAdapter(
        dio: Dio()..httpClientAdapter = http,
      );
      const item = GalleryItem(
        id: 501,
        sourceId: GallerySourceId.aiTag,
        createdAt: '',
        uploaderId: 9,
        cover: GalleryMedia(
          id: 'pending',
          previewUrl: '',
          displayUrl: '',
          downloadUrl: '',
        ),
      );

      final detail = await adapter.detail(item);

      expect(detail.media.map((media) => media.id), [
        '501_p0',
        '501_p2',
        '501_p3',
        '501_p10',
      ]);
      expect(
        detail.media.first.displayUrl,
        'https://cdn.example/SD/9/501_p0.webp',
      );
      expect(detail.media.first.prompt, contains('1girl'));
      expect(detail.media.first.negativePrompt, contains('lowres'));
      expect(detail.media.first.rawMetadata, contains('Negative prompt'));
      expect(detail.media[2].metadataFormat, 'ComfyUI');
      expect(detail.media[2].prompt, 'comfy positive');
      expect(detail.media[2].negativePrompt, 'comfy negative');
      expect(detail.item.mediaCount, 4);
    });
  });
}

const _configJson = {
  'asset_base_url': 'https://cdn.example/',
  'page_size': 60,
  'available_years': [2026, 2025, 2024, 2023],
  'available_months': ['2026-07', '2026-06', '2023-10'],
};

Map<String, Object?> _donmaiPost(int id) => {
  'id': id,
  'created_at': '2026-08-09T12:00:00Z',
  'uploader_id': 1,
  'score': 10,
  'source': '',
  'md5': 'abc$id',
  'last_comment_bumped_at': null,
  'rating': 'g',
  'image_width': 768,
  'image_height': 1024,
  'tag_string': '1girl solo',
  'fav_count': 2,
  'file_ext': 'jpg',
  'file_size': 100,
  'image_id': id,
  'parent_id': null,
  'has_children': false,
  'tag_count_general': 2,
  'tag_count_artist': 0,
  'tag_count_character': 0,
  'tag_count_copyright': 0,
  'file_url': 'https://cdn.example/$id.jpg',
  'large_file_url': 'https://cdn.example/$id-large.jpg',
  'preview_file_url': 'https://cdn.example/$id-preview.jpg',
};

Map<String, Object?> _aiWork(int id) => {
  'id': id,
  'userId': 9,
  'userName': 'Alice',
  'title': 'Work $id',
  'caption': '<b>Hello</b><br>World',
  'tags': '["tag one", "tag_two"]',
  'create_date': '2026-07-20T12:00:00',
  'AI_type': 'SD',
  'total_view': 12,
  'total_bookmarks': 3,
  'image_count': 3,
  'original_urls': '["https://i.pximg.net/forbidden.png"]',
};

Map<String, Object?> _comfyAiImage(String fileName) => {
  'id': fileName.hashCode,
  'work_id': 501,
  'author_id': 9,
  'image_type': 'ComfyUI',
  'file_name': fileName,
  'ai_json': jsonEncode({
    '1': {
      'class_type': 'KSampler',
      'inputs': {'sampler_name': 'euler', 'steps': 20, 'cfg': 7.0, 'seed': 123},
    },
    '2': {
      'class_type': 'CLIPTextEncode',
      'inputs': {'text': 'comfy positive'},
    },
    '3': {
      'class_type': 'CLIPTextEncode',
      'inputs': {'text': 'comfy negative'},
    },
  }),
};

Map<String, Object?> _aiImage(String fileName) => {
  'id': fileName.hashCode,
  'work_id': 501,
  'author_id': 9,
  'image_type': 'SD',
  'file_name': fileName,
  'ai_json': jsonEncode({
    'parameters':
        '1girl, solo\nNegative prompt: lowres, bad hands\nSteps: 24, Sampler: Euler a, CFG scale: 6, Seed: 42, Size: 768x1152',
  }),
};

class _RecordingHttpAdapter implements HttpClientAdapter {
  _RecordingHttpAdapter(this.handler);

  final Object? Function(RequestOptions request) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final value = handler(options);
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
