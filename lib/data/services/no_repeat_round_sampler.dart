import 'dart:collection';
import 'dart:math';

/// Deterministically shuffles each round and emits every distinct item once.
class NoRepeatRoundSampler {
  const NoRepeatRoundSampler();

  T select<T>({
    required List<T> items,
    required String key,
    required int cursor,
  }) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must not be empty');
    }
    if (cursor < 0) {
      throw ArgumentError.value(cursor, 'cursor', 'must not be negative');
    }

    final distinctItems = LinkedHashSet<T>.of(items).toList(growable: false);
    final round = cursor ~/ distinctItems.length;
    final indexInRound = cursor % distinctItems.length;
    final shuffled = List<T>.from(distinctItems)
      ..shuffle(Random(_stableSeed('$key:$round')));
    return shuffled[indexInRound];
  }

  int _stableSeed(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
