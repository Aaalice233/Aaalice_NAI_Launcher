import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/chunked_gallery_items.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';

void main() {
  group('ChunkedGalleryItems', () {
    late GalleryItem item1, item2, item3, item4, item5;

    setUp(() {
      item1 = const GalleryItem(id: 1, site: 'test');
      item2 = const GalleryItem(id: 2, site: 'test');
      item3 = const GalleryItem(id: 3, site: 'test');
      item4 = const GalleryItem(id: 4, site: 'test');
      item5 = const GalleryItem(id: 5, site: 'test');
    });

    test('creates empty instance', () {
      final chunked = ChunkedGalleryItems();
      expect(chunked.length, 0);
      expect(chunked.isEmpty, true);
      expect(chunked.chunkCount, 0);
    });

    test('creates from empty iterable', () {
      final chunked = ChunkedGalleryItems.from([]);
      expect(chunked.length, 0);
      expect(chunked.isEmpty, true);
      expect(chunked.chunkCount, 0);
    });

    test('creates from single item', () {
      final chunked = ChunkedGalleryItems.from([item1]);
      expect(chunked.length, 1);
      expect(chunked[0], item1);
      expect(chunked.chunkCount, 1);
      expect(chunked.chunkSizes, [1]);
    });

    test('stores one response as one immutable chunk', () {
      final chunked = ChunkedGalleryItems.from([item1, item2, item3]);
      expect(chunked.length, 3);
      expect(chunked[0], item1);
      expect(chunked[1], item2);
      expect(chunked[2], item3);
      expect(chunked.chunkCount, 1);
      expect(chunked.chunkSizes, [3]);
    });

    test('provides List<GalleryItem> semantics', () {
      final items = [item1, item2, item3];
      final chunked = ChunkedGalleryItems.from(items);

      // Test List interface
      expect(chunked.length, 3);
      expect(chunked.isEmpty, false);
      expect(chunked.isNotEmpty, true);
      expect(chunked.first, item1);
      expect(chunked.last, item3);

      // Test iteration
      final iteratedItems = <GalleryItem>[];
      for (final item in chunked) {
        iteratedItems.add(item);
      }
      expect(iteratedItems, items);

      // Test toList
      expect(chunked.toList(), items);
    });

    test('binary search indexing works correctly', () {
      final items = List.generate(10, (i) => GalleryItem(id: i, site: 'test'));
      var chunked = ChunkedGalleryItems();
      for (var start = 0; start < items.length; start += 3) {
        chunked = chunked.appendPage(items.skip(start).take(3));
      }

      expect(chunked.chunkCount, 4);
      expect(chunked.chunkSizes, [3, 3, 3, 1]);

      // Test access to all indices
      for (int i = 0; i < 10; i++) {
        expect(chunked[i].id, i);
      }
    });

    test('throws on out-of-bounds access', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      expect(() => chunked[-1], throwsA(isA<RangeError>()));
      expect(() => chunked[2], throwsA(isA<RangeError>()));
    });

    test('is read-only', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      expect(() => chunked[0] = item3, throwsUnsupportedError);
      expect(() => chunked.length = 5, throwsUnsupportedError);
    });

    test('appendPage with empty list returns same instance', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      final result = chunked.appendPage([]);
      expect(identical(result, chunked), true);
    });

    test('appendPage adds new items', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      final result = chunked.appendPage([item3, item4]);

      expect(result.length, 4);
      expect(result[0], item1);
      expect(result[1], item2);
      expect(result[2], item3);
      expect(result[3], item4);
      expect(result.chunkCount, 2);
      expect(result.chunkSizes, [2, 2]);
    });

    test('appendPage keeps each response in a separate chunk', () {
      final chunked = ChunkedGalleryItems.from([item1]);
      final result = chunked.appendPage([item2, item3, item4]);

      expect(result.length, 4);
      expect(result.chunkCount, 2);
      expect(result.chunkSizes, [1, 3]);
    });

    test('appendPage deduplicates by stableKey', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      // Try to add item1 again (same stableKey)
      final result = chunked.appendPage([item1, item3]);

      expect(result.length, 3);
      expect(result[0], item1); // Original position preserved
      expect(result[1], item2);
      expect(result[2], item3); // Only item3 was added
    });

    test('appendPage with all duplicates returns same instance', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      final result = chunked.appendPage([item1, item2]);
      expect(identical(result, chunked), true);
    });

    test('mergePage deduplicates and enriches its first incoming page', () {
      final brief = item1.copyWith(title: 'brief');
      final complete = item1.copyWith(title: 'complete');

      final result = ChunkedGalleryItems().mergePage([
        brief,
        complete,
        item2,
      ], mergeDuplicate: (_, incoming) => incoming);

      expect(result.map((item) => item.id), [1, 2]);
      expect(result.first.title, 'complete');
      expect(result.indexOfStableKey(item2.stableKey), 1);
    });

    test('mergePage replaces a duplicate in place and appends new items', () {
      final original = item1.copyWith(title: 'brief');
      final richer = item1.copyWith(title: 'complete');
      final chunked = ChunkedGalleryItems.from([original, item2]);

      final result = chunked.mergePage(
        [richer, item3],
        mergeDuplicate: (current, incoming) =>
            (incoming.title?.length ?? 0) > (current.title?.length ?? 0)
            ? incoming
            : current,
      );

      expect(result.map((item) => item.id), [1, 2, 3]);
      expect(result.first.title, 'complete');
      expect(result.chunkCount, 2);
      expect(chunked.first.title, 'brief');
    });

    test('removeStableKeys preserves order, chunks, and indices', () {
      final chunked = ChunkedGalleryItems.from([
        item1,
        item2,
      ]).appendPage([item3, item4]);

      final result = chunked.removeStableKeys({
        item2.stableKey,
        item3.stableKey,
      });

      expect(result.map((item) => item.id), [1, 4]);
      expect(result.chunkSizes, [1, 1]);
      expect(result.indexOfStableKey(item1.stableKey), 0);
      expect(result.indexOfStableKey(item4.stableKey), 1);
      expect(result.containsStableKey(item2.stableKey), isFalse);
      expect(chunked.map((item) => item.id), [1, 2, 3, 4]);
    });

    test('removeStableKeys returns the same instance without matches', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);

      expect(identical(chunked.removeStableKeys(const {}), chunked), isTrue);
      expect(
        identical(chunked.removeStableKeys({item3.stableKey}), chunked),
        isTrue,
      );
    });

    test('containsStableKey works correctly', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      expect(chunked.containsStableKey(item1.stableKey), true);
      expect(chunked.containsStableKey(item2.stableKey), true);
      expect(chunked.containsStableKey(item3.stableKey), false);
    });

    test('indexOfStableKey returns correct indices', () {
      final chunked = ChunkedGalleryItems.from([item1, item2, item3]);
      expect(chunked.indexOfStableKey(item1.stableKey), 0);
      expect(chunked.indexOfStableKey(item2.stableKey), 1);
      expect(chunked.indexOfStableKey(item3.stableKey), 2);
      expect(chunked.indexOfStableKey(item4.stableKey), null);
    });

    test('maintains stable key mapping after append', () {
      final chunked = ChunkedGalleryItems.from([item1, item2]);
      final result = chunked.appendPage([item3, item4]);

      expect(result.indexOfStableKey(item1.stableKey), 0);
      expect(result.indexOfStableKey(item2.stableKey), 1);
      expect(result.indexOfStableKey(item3.stableKey), 2);
      expect(result.indexOfStableKey(item4.stableKey), 3);
    });

    test('handles large datasets efficiently', () {
      final items = List.generate(
        1000,
        (i) => GalleryItem(id: i, site: 'test'),
      );
      var chunked = ChunkedGalleryItems();
      for (var start = 0; start < items.length; start += 100) {
        chunked = chunked.appendPage(items.skip(start).take(100));
      }

      expect(chunked.length, 1000);
      expect(chunked.chunkCount, 10);
      expect(chunked.chunkSizes.every((size) => size == 100), true);

      // Test random access performance
      expect(chunked[0].id, 0);
      expect(chunked[500].id, 500);
      expect(chunked[999].id, 999);
    });

    test('preserves order during deduplication', () {
      final chunked = ChunkedGalleryItems.from([item1, item3, item5]);
      // Insert item2 and item4 in the middle, plus duplicate item3
      final result = chunked.appendPage([item2, item3, item4]);

      expect(result.length, 5);
      expect(result[0], item1); // Original order preserved
      expect(result[1], item3);
      expect(result[2], item5);
      expect(result[3], item2); // New items added at end
      expect(result[4], item4);
    });

    test('edge case: single chunk with exact chunk size', () {
      final items = [item1, item2];
      final chunked = ChunkedGalleryItems.from(items);

      expect(chunked.chunkCount, 1);
      expect(chunked.chunkSizes, [2]);

      final result = chunked.appendPage([item3]);
      expect(result.chunkCount, 2);
      expect(result.chunkSizes, [2, 1]);
    });

    test('stableKey generation is consistent', () {
      const item = GalleryItem(id: 123, site: 'test');
      final chunked1 = ChunkedGalleryItems.from([item]);
      final chunked2 = ChunkedGalleryItems();
      final result = chunked2.appendPage([item]);

      expect(chunked1.containsStableKey(item.stableKey), true);
      expect(result.containsStableKey(item.stableKey), true);
      expect(
        chunked1.indexOfStableKey(item.stableKey),
        result.indexOfStableKey(item.stableKey),
      );
    });
  });
}
