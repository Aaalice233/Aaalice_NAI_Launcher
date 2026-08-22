// ignore_for_file: prefer_const_constructors

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

class TestAdapter extends GallerySourceAdapter {
  TestAdapter({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  GallerySourceId get sourceId => GallerySourceId.danbooru;

  @override
  Random get randomGenerator => _random;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    cancelToken,
  }) async {
    // Mock implementation
    return GalleryPage(
      items: [_createMockItem(1), _createMockItem(2)],
      cursor: request.cursor,
      nextCursor: '2',
      hasMore: true,
      rawItemCount: 2,
    );
  }

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    cancelToken,
  }) async {
    final items = [_createMockItem(1), _createMockItem(2), _createMockItem(3)];

    final shuffled = shuffleGalleryItems(items, randomGenerator);

    return GalleryPage(
      items: shuffled,
      cursor: 'random',
      nextCursor: null,
      hasMore: false,
      rawItemCount: items.length,
    );
  }

  GalleryItem _createMockItem(int id) {
    return GalleryItem(
      id: id,
      sourceId: sourceId,
      title: 'Mock Item $id',
      cover: GalleryMedia(id: id.toString()),
      createdAt: '2023-01-01T00:00:00.000Z',
      tags: ['tag$id'],
      rating: 'g',
    );
  }
}

void main() {
  group('Gallery Adapter Integration', () {
    test('adapter implements random method correctly', () async {
      final adapter = TestAdapter(random: Random(42));

      const request = GalleryRandomSearchRequest(pageSize: 10);
      final result = await adapter.random(request);

      expect(result.items.length, equals(3));
      expect(result.cursor, equals('random'));
      expect(result.hasMore, isFalse);

      // Items should be shuffled but still contain all original items
      final itemIds = result.items.map((item) => item.id).toSet();
      expect(itemIds, equals({1, 2, 3}));
    });

    test('adapter random requests have proper type hierarchy', () {
      const searchReq = GalleryRandomSearchRequest(pageSize: 10);
      const rankingReq = GalleryRandomRankingRequest(pageSize: 10);
      const favReq = GalleryRandomFavoritesRequest(
        pageSize: 10,
        username: 'user',
      );

      expect(searchReq, isA<GalleryRandomRequest>());
      expect(rankingReq, isA<GalleryRandomRequest>());
      expect(favReq, isA<GalleryRandomRequest>());

      expect(searchReq.pageSize, equals(10));
      expect(rankingReq.pageSize, equals(10));
      expect(favReq.pageSize, equals(10));
    });

    test('shuffle function maintains determinism with same seed', () {
      final items = [
        GalleryItem(
          id: 1,
          sourceId: GallerySourceId.danbooru,
          cover: GalleryMedia(id: '1'),
          createdAt: '2023-01-01T00:00:00.000Z',
          tags: ['tag1'],
          rating: 'g',
        ),
        GalleryItem(
          id: 2,
          sourceId: GallerySourceId.danbooru,
          cover: GalleryMedia(id: '2'),
          createdAt: '2023-01-01T00:00:00.000Z',
          tags: ['tag2'],
          rating: 'g',
        ),
        GalleryItem(
          id: 3,
          sourceId: GallerySourceId.danbooru,
          cover: GalleryMedia(id: '3'),
          createdAt: '2023-01-01T00:00:00.000Z',
          tags: ['tag3'],
          rating: 'g',
        ),
      ];

      final shuffled1 = shuffleGalleryItems(items, Random(123));
      final shuffled2 = shuffleGalleryItems(items, Random(123));

      expect(shuffled1.map((i) => i.id), equals(shuffled2.map((i) => i.id)));
    });

    test('random request properties work correctly', () {
      final date = DateTime(2023, 6, 15);

      const searchReq = GalleryRandomSearchRequest(
        pageSize: 20,
        query: 'test query',
        prompt: 'test prompt',
        timeRange: 'y2023',
        ratings: {'g', 's'},
        blacklistTags: {'nsfw'},
      );

      final rankingReq = GalleryRandomRankingRequest(
        pageSize: 15,
        kind: GalleryRankingKind.week,
        date: date,
        period: 'current',
        query: 'ranking query',
        prompt: 'ranking prompt',
        ratings: {'g'},
        blacklistTags: {'explicit'},
      );

      const favReq = GalleryRandomFavoritesRequest(
        pageSize: 25,
        username: 'testuser',
        ratings: {'q', 'e'},
        blacklistTags: {'gore'},
      );

      // Verify search request
      expect(searchReq.query, equals('test query'));
      expect(searchReq.prompt, equals('test prompt'));
      expect(searchReq.timeRange, equals('y2023'));
      expect(searchReq.ratings, equals({'g', 's'}));
      expect(searchReq.blacklistTags, equals({'nsfw'}));

      // Verify ranking request
      expect(rankingReq.kind, equals(GalleryRankingKind.week));
      expect(rankingReq.date, equals(date));
      expect(rankingReq.period, equals('current'));
      expect(rankingReq.query, equals('ranking query'));
      expect(rankingReq.prompt, equals('ranking prompt'));
      expect(rankingReq.ratings, equals({'g'}));
      expect(rankingReq.blacklistTags, equals({'explicit'}));

      // Verify favorites request
      expect(favReq.username, equals('testuser'));
      expect(favReq.ratings, equals({'q', 'e'}));
      expect(favReq.blacklistTags, equals({'gore'}));
    });
  });
}
