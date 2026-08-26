import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/weighted_selector.dart';

void main() {
  final selector = WeightedSelector();

  test('same seed produces the same sequence', () {
    final tags = [
      const WeightedTag(tag: 'a', weight: 1),
      const WeightedTag(tag: 'b', weight: 3),
      const WeightedTag(tag: 'c', weight: 6),
    ];
    final firstRandom = Random(42);
    final secondRandom = Random(42);

    final first = List.generate(
      100,
      (_) => selector.select(tags, random: firstRandom),
    );
    final second = List.generate(
      100,
      (_) => selector.select(tags, random: secondRandom),
    );

    expect(first, second);
  });

  test('merges duplicates, filters invalid entries and respects weights', () {
    final tags = [
      const WeightedTag(tag: 'common', weight: 3),
      const WeightedTag(tag: 'COMMON', weight: 3),
      const WeightedTag(tag: 'rare', weight: 2),
      const WeightedTag(tag: 'ignored', weight: 0),
      const WeightedTag(tag: ' ', weight: 100),
    ];
    final random = Random(7);
    final counts = <String, int>{};

    for (var i = 0; i < 20000; i++) {
      final value = selector.select(tags, random: random);
      counts[value] = (counts[value] ?? 0) + 1;
    }

    expect(counts.keys, unorderedEquals(['common', 'rare']));
    final commonRatio = counts['common']! / 20000;
    expect(commonRatio, inInclusiveRange(0.73, 0.77));
  });

  test('reports empty and ineligible inputs explicitly', () {
    expect(() => selector.select(const []), throwsArgumentError);
    expect(
      () => selector.select([const WeightedTag(tag: 'disabled', weight: 0)]),
      throwsStateError,
    );
  });
}
