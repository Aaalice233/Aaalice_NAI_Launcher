import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

void main() {
  group('AiTagGallerySourceAdapter empty list 404', () {
    test('search treats a 404 with empty items as an empty page', () async {
      final http = _FakeHttpAdapter((request) {
        if (request.uri.path == '/api/config') return _configJson;
        expect(request.uri.path, '/api/ai_works_search');
        return const _FakeResponse({
          'page': 1,
          'page_size': 60,
          'total': 0,
          'items': [],
        }, statusCode: 404);
      });
      final adapter = AiTagGallerySourceAdapter(
        dio: Dio()..httpClientAdapter = http,
      );

      final page = await adapter.search(
        const GallerySearchRequest(
          cursor: '1',
          pageSize: 60,
          query: 'zzqqxxnomatch',
        ),
      );

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
      expect(page.total, 0);
      expect(page.cursor, '1');
    });

    test(
      'fixed month ranking treats no_content 404 as an empty page',
      () async {
        final http = _FakeHttpAdapter((request) {
          if (request.uri.path == '/api/config') return _configJson;
          expect(request.uri.path, '/api/rank/monthly/fixed');
          expect(request.queryParameters['month'], '2026-07');
          return const _FakeResponse({'error': 'no_content'}, statusCode: 404);
        });
        final adapter = AiTagGallerySourceAdapter(
          dio: Dio()..httpClientAdapter = http,
        );

        final page = await adapter.ranking(
          const GalleryRankingRequest(
            cursor: '1',
            pageSize: 60,
            kind: GalleryRankingKind.aiTagMonthly,
            period: '2026-07',
            query: 'zzqqxxnomatch',
          ),
        );

        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
        expect(page.nextCursor, isNull);
        expect(page.total, isNull);
      },
    );

    test('live ranking past the last page keeps total but stops', () async {
      final http = _FakeHttpAdapter((request) {
        if (request.uri.path == '/api/config') return _configJson;
        expect(request.uri.path, '/api/rank/monthly/real');
        return const _FakeResponse({
          'page': 999,
          'page_size': 60,
          'total': 29412,
          'items': [],
        }, statusCode: 404);
      });
      final adapter = AiTagGallerySourceAdapter(
        dio: Dio()..httpClientAdapter = http,
      );

      final page = await adapter.ranking(
        const GalleryRankingRequest(
          cursor: '999',
          pageSize: 60,
          kind: GalleryRankingKind.aiTagMonthly,
        ),
      );

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
      expect(page.total, 29412);
    });

    test('random search with no hits returns an empty page', () async {
      var listRequests = 0;
      final http = _FakeHttpAdapter((request) {
        if (request.uri.path == '/api/config') return _configJson;
        listRequests++;
        return const _FakeResponse({
          'page': 1,
          'page_size': 60,
          'total': 0,
          'items': [],
        }, statusCode: 404);
      });
      final adapter = AiTagGallerySourceAdapter(
        dio: Dio()..httpClientAdapter = http,
        random: Random(1),
      );

      final page = await adapter.random(
        const GalleryRandomSearchRequest(
          pageSize: 60,
          query: 'empty_random_probe_no_match',
        ),
      );

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(listRequests, 1);
    });

    test(
      'list 404 without an empty-list body still maps to not found',
      () async {
        final http = _FakeHttpAdapter((request) {
          if (request.uri.path == '/api/config') return _configJson;
          return const _FakeResponse({'error': 'not_found'}, statusCode: 404);
        });
        final adapter = AiTagGallerySourceAdapter(
          dio: Dio()..httpClientAdapter = http,
        );

        await expectLater(
          adapter.search(const GallerySearchRequest(cursor: '1', pageSize: 60)),
          throwsA(_notFound),
        );
      },
    );

    test('detail 404 still maps to detailNotFound', () async {
      final http = _FakeHttpAdapter((request) {
        if (request.uri.path == '/api/config') return _configJson;
        expect(request.uri.path, '/api/work/404');
        return const _FakeResponse({
          'page': 1,
          'page_size': 60,
          'total': 0,
          'items': [],
        }, statusCode: 404);
      });
      final adapter = AiTagGallerySourceAdapter(
        dio: Dio()..httpClientAdapter = http,
      );

      await expectLater(
        adapter.detail(
          const GalleryItem(id: 404, sourceId: GallerySourceId.aiTag),
        ),
        throwsA(_notFound),
      );
    });
  });
}

final _notFound = isA<GallerySourceException>()
    .having(
      (error) => error.code,
      'code',
      GallerySourceErrorCode.detailNotFound,
    )
    .having((error) => error.statusCode, 'statusCode', 404);

const _configJson = {
  'asset_base_url': 'https://cdn.example/',
  'page_size': 60,
  'available_years': [2026, 2025],
  'available_months': ['2026-07', '2026-06'],
};

class _FakeResponse {
  const _FakeResponse(this.data, {required this.statusCode});

  final Object? data;
  final int statusCode;
}

class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter(this.handler);

  final FutureOr<Object?> Function(RequestOptions request) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final value = await handler(options);
    final response = value is _FakeResponse
        ? value
        : _FakeResponse(value, statusCode: 200);
    return ResponseBody.fromString(
      jsonEncode(response.data),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
