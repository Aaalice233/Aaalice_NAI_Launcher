import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/bulk_tag_edit_utils.dart';

void main() {
  test(
    'parses comma variants and newlines with case-insensitive deduplication',
    () {
      expect(parseBulkTagInput([' Cat, dog，BIRD\ncat\r\n dog ']), [
        'Cat',
        'dog',
        'BIRD',
      ]);
    },
  );

  test('applies additions and removals using canonical tag keys', () {
    expect(
      applyBulkTagChanges(
        ['Cat', 'dog', 'DOG'],
        tagsToAdd: ['bird', 'CAT'],
        tagsToRemove: ['dOg'],
      ),
      ['Cat', 'bird'],
    );
  });

  test('removal wins for conflicting external requests', () {
    expect(
      applyBulkTagChanges(['cat'], tagsToAdd: ['DOG'], tagsToRemove: ['dog']),
      ['cat'],
    );
  });
}
