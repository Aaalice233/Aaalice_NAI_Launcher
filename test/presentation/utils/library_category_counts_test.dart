import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/utils/library_category_counts.dart';

void main() {
  test(
    'sidebar counts include descendants once and preserve empty categories',
    () {
      expect(
        libraryCategoryCounts(
          {'a': null, 'b': 'a', 'c': 'b', 'empty': null},
          ['a', 'b', 'c', 'c', null, 'missing'],
        ),
        {'a': 4, 'b': 3, 'c': 2, 'empty': 0},
      );
    },
  );
  test('invalid cycles fail explicitly', () {
    expect(
      () => libraryCategoryCounts({'a': 'b', 'b': 'a'}, ['a']),
      throwsStateError,
    );
  });
}
