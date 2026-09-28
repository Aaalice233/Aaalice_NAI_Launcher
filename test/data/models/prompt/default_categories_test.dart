import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/default_categories.dart';
import 'package:nai_launcher/data/models/prompt/tag_category.dart';
import 'package:nai_launcher/data/models/prompt/tag_scope.dart';

void main() {
  test('default recipe exposes every production generation stage', () {
    final categories = DefaultCategories.createDefault();

    expect(categories.map((category) => category.key), [
      'hairColor',
      'eyeColor',
      'hairStyle',
      'expression',
      'pose',
      'clothing',
      'bodyFeature',
      'accessory',
      'style',
      'background',
      'scene',
      'composition',
      'prop',
      'effect',
      'year',
      'detail',
    ]);
    expect(categories.every((category) => category.isBuiltin), isTrue);
    expect(
      categories
          .expand((category) => category.groups)
          .every(
            (group) => TagSubCategory.values.any(
              (source) => source.name == group.sourceId,
            ),
          ),
      isTrue,
    );

    final composition = categories.singleWhere(
      (category) => category.key == 'composition',
    );
    expect(composition.groups.map((group) => group.sourceId), [
      'camera',
      'framing',
      'focus',
    ]);
    expect(
      composition.groups.every((group) => group.scope == TagScope.global),
      isTrue,
    );

    final detail = categories.singleWhere(
      (category) => category.key == 'detail',
    );
    expect(detail.groups.single.sourceId, TagSubCategory.detail.name);
    expect(detail.probability, greaterThan(0));
  });

  test(
    'migration appends missing built-ins without replacing user choices',
    () {
      final original = DefaultCategories.createDefault().first.copyWith(
        enabled: false,
        probability: 0.17,
        groups: [
          DefaultCategories.createDefault().first.groups.first.copyWith(
            probability: 0.23,
          ),
        ],
      );

      final migrated = DefaultCategories.mergeMissingBuiltins([original]);

      final preserved = migrated.first;
      expect(preserved.key, original.key);
      expect(preserved.enabled, isFalse);
      expect(preserved.probability, 0.17);
      expect(preserved.groups.first.probability, 0.23);
      expect(
        migrated.map((category) => category.key).toSet(),
        DefaultCategories.createDefault()
            .map((category) => category.key)
            .toSet(),
      );
    },
  );
}
