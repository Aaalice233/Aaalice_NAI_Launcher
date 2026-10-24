import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/utils/lru_cache.dart';

void main() {
  group('without a weigher', () {
    test('evicts the least recently used entry at maxSize', () {
      final cache = LRUCache<String, int>(maxSize: 2)
        ..put('a', 1)
        ..put('b', 2);
      expect(cache.get('a'), 1);

      cache.put('c', 3);

      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.size, 2);
      expect(cache.totalWeight, 0);
      expect(cache.statistics['evictionCount'], 1);
    });

    test('replacing a key does not evict another entry', () {
      final cache = LRUCache<String, int>(maxSize: 2)
        ..put('a', 1)
        ..put('b', 2)
        ..put('a', 10);

      expect(cache.get('a'), 10);
      expect(cache.get('b'), 2);
      expect(cache.statistics['evictionCount'], 0);
    });
  });

  group('with a weight budget', () {
    LRUCache<String, List<int>> weighted({int maxSize = 10}) => LRUCache(
      maxSize: maxSize,
      maxWeight: 10,
      weigher: (value) => value.length,
    );

    test('evicts oldest entries until the new value fits', () {
      final cache = weighted()
        ..put('a', List.filled(4, 0))
        ..put('b', List.filled(4, 0));
      expect(cache.get('a'), hasLength(4));

      cache.put('c', List.filled(5, 0));

      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.totalWeight, 9);
    });

    test('still honours maxSize for light entries', () {
      final cache = weighted(maxSize: 2)
        ..put('a', const [])
        ..put('b', const [])
        ..put('c', const []);

      expect(cache.size, 2);
      expect(cache.containsKey('a'), isFalse);
    });

    test('rejects a value heavier than the whole budget', () {
      final cache = weighted()
        ..put('a', List.filled(3, 0))
        ..put('b', List.filled(2, 0))
        ..put('a', List.filled(11, 0));

      expect(cache.containsKey('a'), isFalse);
      expect(cache.get('b'), hasLength(2));
      expect(cache.totalWeight, 2);
    });

    test('replacing a key releases its previous weight', () {
      final cache = weighted()
        ..put('a', List.filled(6, 0))
        ..put('b', List.filled(4, 0))
        ..put('a', List.filled(2, 0));

      expect(cache.size, 2);
      expect(cache.totalWeight, 6);
    });

    test('removeWhere and remove keep the weight total exact', () {
      final cache = weighted()
        ..put('a', List.filled(1, 0))
        ..put('b', List.filled(2, 0))
        ..put('c', List.filled(3, 0));

      expect(cache.removeWhere((key, _) => key != 'b'), 2);
      expect(cache.totalWeight, 2);
      expect(cache.remove('b'), isTrue);
      expect(cache.remove('b'), isFalse);
      expect(cache.totalWeight, 0);
      expect(cache.isEmpty, isTrue);
    });

    test('releases the weight recorded at put after the value mutates', () {
      final grown = [1, 2];
      final shrunk = [1, 2, 3, 4];
      final cache = weighted()
        ..put('grown', grown)
        ..put('shrunk', shrunk);
      grown.addAll([3, 4, 5]);
      shrunk.length = 1;

      expect(cache.remove('grown'), isTrue);
      expect(cache.totalWeight, 4);
      expect(cache.removeWhere((key, _) => key == 'shrunk'), 1);
      expect(cache.totalWeight, 0);
    });

    test('eviction releases the recorded weight of a mutated value', () {
      final mutated = List.filled(4, 0, growable: true);
      final cache = weighted()..put('a', mutated);
      mutated.addAll(List.filled(5, 0));

      cache.put('b', List.filled(10, 0));

      expect(cache.containsKey('a'), isFalse);
      expect(cache.totalWeight, 10);
    });

    test('removeWhere keeps the recency order of survivors', () {
      final cache = weighted(maxSize: 3)
        ..put('a', const [])
        ..put('b', const [])
        ..put('c', const []);
      cache.get('a');

      cache
        ..removeWhere((key, _) => key == 'c')
        ..put('d', const [])
        ..put('e', const []);

      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('a'), isTrue);
    });

    test('clear resets the weight total', () {
      final cache = weighted()..put('a', List.filled(5, 0));

      cache.clear();

      expect(cache.totalWeight, 0);
      cache.put('b', List.filled(10, 0));
      expect(cache.containsKey('b'), isTrue);
    });
  });
}
