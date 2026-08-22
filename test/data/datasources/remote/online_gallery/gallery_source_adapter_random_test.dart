import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

class MockRandom extends Mock implements Random {}

void main() {
  group('GallerySourceAdapter', () {
    test(
      'shuffleGalleryItems produces different orders with different randoms',
      () {
        final items = [
          _createMockGalleryItem(1),
          _createMockGalleryItem(2),
          _createMockGalleryItem(3),
          _createMockGalleryItem(4),
          _createMockGalleryItem(5),
        ];

        // Test with fixed seed random
        final random1 = Random(42);
        final random2 = Random(43);

        final shuffled1 = shuffleGalleryItems(items, random1);
        final shuffled2 = shuffleGalleryItems(items, random2);

        // Should have same items but potentially different order
        expect(shuffled1.length, equals(items.length));
        expect(shuffled2.length, equals(items.length));

        for (final item in items) {
          expect(shuffled1.contains(item), isTrue);
          expect(shuffled2.contains(item), isTrue);
        }

        // With different seeds, order should likely be different
        // (This could theoretically fail but is extremely unlikely)
        expect(
          shuffled1.map((i) => i.id),
          isNot(equals(shuffled2.map((i) => i.id))),
        );
      },
    );

    test('shuffleGalleryItems preserves all items', () {
      final items = [
        _createMockGalleryItem(1),
        _createMockGalleryItem(2),
        _createMockGalleryItem(3),
      ];

      final random = Random(42);
      final shuffled = shuffleGalleryItems(items, random);

      expect(shuffled.length, equals(items.length));
      expect(shuffled.toSet(), equals(items.toSet()));
    });

    test('shuffleGalleryItems handles empty list', () {
      final items = <GalleryItem>[];
      final random = Random(42);
      final shuffled = shuffleGalleryItems(items, random);

      expect(shuffled, isEmpty);
    });

    test('shuffleGalleryItems handles single item', () {
      final items = [_createMockGalleryItem(1)];
      final random = Random(42);
      final shuffled = shuffleGalleryItems(items, random);

      expect(shuffled.length, equals(1));
      expect(shuffled[0], equals(items[0]));
    });

    test('shuffleGalleryItems is deterministic with same random seed', () {
      final items = [
        _createMockGalleryItem(1),
        _createMockGalleryItem(2),
        _createMockGalleryItem(3),
        _createMockGalleryItem(4),
        _createMockGalleryItem(5),
      ];

      final shuffled1 = shuffleGalleryItems(items, Random(42));
      final shuffled2 = shuffleGalleryItems(items, Random(42));

      expect(shuffled1.map((i) => i.id), equals(shuffled2.map((i) => i.id)));
    });

    test('mock random integration test', () {
      final mockRandom = MockRandom();

      // Mock sequence: [2, 1] for Fisher-Yates shuffle (3 items = 2 swaps)
      when(() => mockRandom.nextInt(3)).thenReturn(2);
      when(() => mockRandom.nextInt(2)).thenReturn(1);

      final items = [
        _createMockGalleryItem(1),
        _createMockGalleryItem(2),
        _createMockGalleryItem(3),
      ];

      final shuffled = shuffleGalleryItems(items, mockRandom);

      // With the mocked sequence, the result should be predictable
      expect(shuffled.length, equals(3));

      // Verify all items are present
      expect(shuffled.map((i) => i.id).toSet(), equals({1, 2, 3}));

      // Verify the mocked random was called correctly
      verify(() => mockRandom.nextInt(3)).called(1);
      verify(() => mockRandom.nextInt(2)).called(1);
    });
  });

  group('Random Request Types', () {
    test('GalleryRandomSearchRequest creates correctly', () {
      const request = GalleryRandomSearchRequest(
        pageSize: 20,
        query: 'cat girl',
        prompt: 'test prompt',
        timeRange: 'y2023',
        ratings: {'g', 's'},
        blacklistTags: {'tag1', 'tag2'},
      );

      expect(request.pageSize, equals(20));
      expect(request.query, equals('cat girl'));
      expect(request.prompt, equals('test prompt'));
      expect(request.timeRange, equals('y2023'));
      expect(request.ratings, equals({'g', 's'}));
      expect(request.blacklistTags, equals({'tag1', 'tag2'}));
    });

    test('GalleryRandomRankingRequest creates correctly', () {
      final testDate = DateTime(2023, 6, 15);
      final request = GalleryRandomRankingRequest(
        pageSize: 30,
        kind: GalleryRankingKind.week,
        date: testDate,
        period: 'current',
        query: 'test',
        prompt: 'test prompt',
        ratings: {'q', 'e'},
        blacklistTags: {'blacklisted'},
      );

      expect(request.pageSize, equals(30));
      expect(request.kind, equals(GalleryRankingKind.week));
      expect(request.date, equals(testDate));
      expect(request.period, equals('current'));
      expect(request.query, equals('test'));
      expect(request.prompt, equals('test prompt'));
      expect(request.ratings, equals({'q', 'e'}));
      expect(request.blacklistTags, equals({'blacklisted'}));
    });

    test('GalleryRandomFavoritesRequest creates correctly', () {
      const request = GalleryRandomFavoritesRequest(
        pageSize: 25,
        username: 'testuser',
        ratings: {'g'},
        blacklistTags: {'unwanted'},
      );

      expect(request.pageSize, equals(25));
      expect(request.username, equals('testuser'));
      expect(request.ratings, equals({'g'}));
      expect(request.blacklistTags, equals({'unwanted'}));
    });

    test('Random requests use default values correctly', () {
      const searchRequest = GalleryRandomSearchRequest(pageSize: 10);
      expect(searchRequest.query, equals(''));
      expect(searchRequest.prompt, equals(''));
      expect(searchRequest.timeRange, equals('all'));
      expect(searchRequest.ratings, equals({'g', 's', 'q', 'e'}));
      expect(searchRequest.blacklistTags, isEmpty);

      const rankingRequest = GalleryRandomRankingRequest(pageSize: 10);
      expect(rankingRequest.kind, equals(GalleryRankingKind.day));
      expect(rankingRequest.date, isNull);
      expect(rankingRequest.period, equals('current'));
      expect(rankingRequest.query, equals(''));
      expect(rankingRequest.prompt, equals(''));

      const favoritesRequest = GalleryRandomFavoritesRequest(
        pageSize: 10,
        username: 'user',
      );
      expect(favoritesRequest.ratings, equals({'g', 's', 'q', 'e'}));
      expect(favoritesRequest.blacklistTags, isEmpty);
    });
  });
}

GalleryItem _createMockGalleryItem(int id) {
  return GalleryItem(
    id: id,
    sourceId: GallerySourceId.danbooru,
    title: 'Test Item $id',
    cover: GalleryMedia(id: id.toString()),
    author: 'test_author',
    createdAt: '2023-06-15T12:00:00.000-04:00',
    tags: ['test', 'tag$id'],
    rating: 'g',
    score: 100,
  );
}
