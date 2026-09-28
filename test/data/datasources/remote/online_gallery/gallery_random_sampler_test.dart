import 'dart:collection';
import 'dart:math';

// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_random_sampler.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

void main() {
  group('GalleryRandomCache', () {
    late GalleryRandomCache<String> cache;

    setUp(() {
      cache = GalleryRandomCache<String>(
        maxSize: 3,
        ttl: Duration(milliseconds: 100),
      );
    });

    test('stores and retrieves values', () {
      cache.put('key1', 'value1');
      expect(cache.get('key1'), equals('value1'));
    });

    test('returns null for non-existent keys', () {
      expect(cache.get('nonexistent'), isNull);
    });

    test('evicts oldest entries when max size exceeded', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      cache.put('key4', 'value4'); // Should evict key1

      expect(cache.get('key1'), isNull);
      expect(cache.get('key2'), equals('value2'));
      expect(cache.get('key3'), equals('value3'));
      expect(cache.get('key4'), equals('value4'));
    });

    test('expires entries after TTL', () async {
      cache.put('key1', 'value1');
      expect(cache.get('key1'), equals('value1'));

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 150));
      expect(cache.get('key1'), isNull);
    });

    test('updates access order on get', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');

      // Access key1 to move it to end of LRU
      cache.get('key1');

      // Add key4, should evict key2 (oldest unaccessed)
      cache.put('key4', 'value4');

      expect(cache.get('key1'), equals('value1'));
      expect(cache.get('key2'), isNull);
      expect(cache.get('key3'), equals('value3'));
      expect(cache.get('key4'), equals('value4'));
    });

    test('clears all entries', () {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.clear();

      expect(cache.get('key1'), isNull);
      expect(cache.get('key2'), isNull);
    });
  });

  group('DanbooruIdBoundary', () {
    test('validates correct boundaries', () {
      const boundary = DanbooruIdBoundary(
        minId: 100,
        maxId: 1000,
        oldestPageSize: 50,
        newestPageSize: 60,
      );
      expect(boundary.isValid, isTrue);
    });

    test('invalidates incorrect boundaries', () {
      const invalidBoundaries = [
        DanbooruIdBoundary(
          minId: 1000,
          maxId: 100,
          oldestPageSize: 50,
          newestPageSize: 60,
        ), // min > max
        DanbooruIdBoundary(
          minId: 100,
          maxId: 1000,
          oldestPageSize: 0,
          newestPageSize: 60,
        ), // zero page size
        DanbooruIdBoundary(
          minId: 100,
          maxId: 1000,
          oldestPageSize: 50,
          newestPageSize: 0,
        ), // zero page size
      ];

      for (final boundary in invalidBoundaries) {
        expect(boundary.isValid, isFalse);
      }
    });
  });

  group('AiTagTotalInfo', () {
    test('calculates total pages correctly', () {
      const info1 = AiTagTotalInfo(totalCount: 100, pageSize: 25);
      expect(info1.totalPages, equals(4));

      const info2 = AiTagTotalInfo(totalCount: 101, pageSize: 25);
      expect(info2.totalPages, equals(5)); // Ceil division

      const info3 = AiTagTotalInfo(totalCount: 0, pageSize: 25);
      expect(info3.totalPages, equals(0));
    });

    test('validates info correctly', () {
      const validInfo = AiTagTotalInfo(totalCount: 100, pageSize: 25);
      expect(validInfo.isValid, isTrue);

      const invalidInfos = [
        AiTagTotalInfo(totalCount: 0, pageSize: 25),
        AiTagTotalInfo(totalCount: 100, pageSize: 0),
        AiTagTotalInfo(totalCount: 0, pageSize: 0),
      ];

      for (final info in invalidInfos) {
        expect(info.isValid, isFalse);
      }
    });
  });

  group('DanbooruRankingWindow', () {
    late DanbooruRankingWindow window;

    setUp(() {
      window = DanbooruRankingWindow(windowSize: 4, pageSize: 20);
    });

    test('initializes available pages correctly', () {
      window.initialize(10);
      final pages = window.getNextWindow(Random(42));
      expect(pages.length, equals(4));
      expect(pages.every((page) => page >= 1 && page <= 10), isTrue);
    });

    test('encodes and decodes cursor correctly', () {
      final originalPages = [1, 3, 5, 7, 9];
      final cursor = window.encodeNextCursor(originalPages);
      expect(cursor.startsWith('rw:'), isTrue);

      final decodedPages = window.decodeNextCursor(cursor);
      expect(decodedPages, equals(originalPages));
    });

    test('handles invalid cursor', () {
      expect(window.decodeNextCursor(null), isNull);
      expect(window.decodeNextCursor('invalid'), isNull);
      expect(window.decodeNextCursor('rw:invalid_base64'), isNull);
    });

    test('resets when insufficient pages remaining', () {
      window.initialize(5); // Only 5 pages available

      // Get first window (4 pages)
      final firstWindow = window.getNextWindow(Random(42));
      expect(firstWindow.length, equals(4));

      // Getting second window should reset and provide 4 pages again
      final secondWindow = window.getNextWindow(Random(42));
      expect(secondWindow.length, equals(4));
    });
  });

  group('GalleryRandomCacheKeys', () {
    test('generates consistent danbooru boundary keys', () {
      final key1 = GalleryRandomCacheKeys.danbooruBoundary(
        query: 'cat girl',
        ratings: {'g', 's'},
        dateStart: DateTime(2023, 1, 1),
        dateEnd: DateTime(2023, 12, 31),
        userHash: 'user123',
      );

      final key2 = GalleryRandomCacheKeys.danbooruBoundary(
        query: 'cat girl',
        ratings: {'s', 'g'}, // Different order
        dateStart: DateTime(2023, 1, 1),
        dateEnd: DateTime(2023, 12, 31),
        userHash: 'user123',
      );

      expect(key1, equals(key2)); // Should be same due to sorting
    });

    test('generates different keys for different parameters', () {
      final baseParams = {
        'query': 'cat girl',
        'ratings': {'g', 's'},
        'dateStart': DateTime(2023, 1, 1),
        'dateEnd': DateTime(2023, 12, 31),
        'userHash': 'user123',
      };

      final key1 = GalleryRandomCacheKeys.danbooruBoundary(
        query: baseParams['query'] as String,
        ratings: baseParams['ratings'] as Set<String>,
        dateStart: baseParams['dateStart'] as DateTime,
        dateEnd: baseParams['dateEnd'] as DateTime,
        userHash: baseParams['userHash'] as String,
      );

      // Change query
      final key2 = GalleryRandomCacheKeys.danbooruBoundary(
        query: 'dog girl',
        ratings: baseParams['ratings'] as Set<String>,
        dateStart: baseParams['dateStart'] as DateTime,
        dateEnd: baseParams['dateEnd'] as DateTime,
        userHash: baseParams['userHash'] as String,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('generates consistent AI TAG total keys', () {
      final key1 = GalleryRandomCacheKeys.aiTagTotal(
        query: 'landscape',
        prompt: 'beautiful scenery',
        timeRange: 'y2023',
      );

      final key2 = GalleryRandomCacheKeys.aiTagTotal(
        query: 'landscape',
        prompt: 'beautiful scenery',
        timeRange: 'y2023',
      );

      expect(key1, equals(key2));
    });

    test('normalizes queries consistently', () {
      final key1 = GalleryRandomCacheKeys.aiTagTotal(
        query: '  Cat   Girl  ',
        prompt: 'test',
        timeRange: 'all',
      );

      final key2 = GalleryRandomCacheKeys.aiTagTotal(
        query: 'cat girl',
        prompt: 'test',
        timeRange: 'all',
      );

      expect(key1, equals(key2));
    });

    test('generates consistent ranking keys', () {
      final key1 = GalleryRandomCacheKeys.aiTagRankingTotal(
        period: 'monthly',
        query: 'test',
        prompt: 'prompt',
      );

      final key2 = GalleryRandomCacheKeys.aiTagRankingTotal(
        period: 'monthly',
        query: 'test',
        prompt: 'prompt',
      );

      expect(key1, equals(key2));
    });
  });

  group('GalleryRandomScope and sampler', () {
    test('any scope field changes the stable key', () {
      final base = GalleryRandomScope(
        sourceId: GallerySourceId.danbooru,
        feedKind: GalleryFeedKind.search,
        fields: const {'query': '1girl', 'ratings': 'g'},
      ).stableKey;
      final changed = GalleryRandomScope(
        sourceId: GallerySourceId.danbooru,
        feedKind: GalleryFeedKind.search,
        fields: const {'query': '1girl', 'ratings': 's'},
      ).stableKey;

      expect(changed, isNot(base));
    });

    test('scope key is independent of field insertion order', () {
      final first = GalleryRandomScope(
        sourceId: GallerySourceId.aiTag,
        feedKind: GalleryFeedKind.ranking,
        fields: const {'query': 'x', 'period': 'month'},
      ).stableKey;
      final second = GalleryRandomScope(
        sourceId: GallerySourceId.aiTag,
        feedKind: GalleryFeedKind.ranking,
        fields: const {'period': 'month', 'query': 'x'},
      ).stableKey;

      expect(second, first);
    });

    test(
      'sampler performs deterministic Fisher-Yates with an injected seed',
      () {
        final first = GalleryRandomSampler(
          random: Random(9),
        ).shuffle([1, 2, 3, 4]);
        final second = GalleryRandomSampler(
          random: Random(9),
        ).shuffle([1, 2, 3, 4]);

        expect(first, second);
        expect(first.toSet(), {1, 2, 3, 4});
      },
    );

    test('permutation slices cover the input exactly once across pages', () {
      final sampler = GalleryRandomSampler(random: Random(1));
      final values = List<int>.generate(101, (index) => index);
      final sampled = <int>[];
      for (var offset = 0; offset < values.length; offset += 13) {
        sampled.addAll(
          sampler.permutationSlice(values, seed: 77, offset: offset, count: 13),
        );
      }

      expect(sampled, hasLength(values.length));
      expect(sampled.toSet(), values.toSet());
    });

    test('permutation does not collapse into a fixed modular stride', () {
      final values = List<int>.generate(257, (index) => index);
      final sampled = GalleryRandomSampler().permutationSlice(
        values,
        seed: 77,
        offset: 0,
        count: values.length,
      );
      final strides = <int>{
        for (var index = 1; index < sampled.length; index++)
          (sampled[index] - sampled[index - 1]) % values.length,
      };

      expect(strides.length, greaterThan(32));
    });

    test('permutation slice work is bounded by the requested result count', () {
      final values = _CountingList(1000000);
      final sampled = GalleryRandomSampler().permutationSlice(
        values,
        seed: 123,
        offset: 600,
        count: 60,
      );

      expect(sampled, hasLength(60));
      expect(values.readCount, 60);
    });
  });
}

class _CountingList extends ListBase<int> {
  _CountingList(this._length);

  final int _length;
  int readCount = 0;

  @override
  int get length => _length;

  @override
  int operator [](int index) {
    readCount++;
    return index;
  }

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('read only');

  @override
  set length(int value) => throw UnsupportedError('fixed length');
}
