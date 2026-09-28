import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/no_repeat_round_sampler.dart';

void main() {
  const sampler = NoRepeatRoundSampler();

  test('emits every distinct item once before starting a new round', () {
    const items = ['a', 'b', 'c', 'a'];
    final firstRound = List.generate(
      3,
      (cursor) => sampler.select(items: items, key: 'group', cursor: cursor),
    );
    final secondRound = List.generate(
      3,
      (index) => sampler.select(items: items, key: 'group', cursor: index + 3),
    );

    expect(firstRound.toSet(), {'a', 'b', 'c'});
    expect(secondRound.toSet(), {'a', 'b', 'c'});
  });

  test('is deterministic for the same key and cursor', () {
    final first = List.generate(
      20,
      (cursor) => sampler.select(
        items: const [1, 2, 3, 4],
        key: 'stable',
        cursor: cursor,
      ),
    );
    final second = List.generate(
      20,
      (cursor) => sampler.select(
        items: const [1, 2, 3, 4],
        key: 'stable',
        cursor: cursor,
      ),
    );

    expect(first, second);
  });

  test('rejects empty input and negative cursors', () {
    expect(
      () => sampler.select(items: const <int>[], key: 'empty', cursor: 0),
      throwsArgumentError,
    );
    expect(
      () => sampler.select(items: const [1], key: 'negative', cursor: -1),
      throwsArgumentError,
    );
  });
}
