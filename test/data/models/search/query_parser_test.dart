import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';

void main() {
  group('QueryParser', () {
    group('Underscore Handling', () {
      test('should preserve underscores in tag text', () {
        // Arrange
        const tagText = 'blue_sky';

        // Act
        final tag = PromptTag.create(text: tagText);

        // Assert
        expect(tag.text, equals('blue_sky'),
            reason: 'Tag text should preserve underscores');
        expect(tag.text, isNot(contains(' ')),
            reason: 'Tag text should not contain spaces');
      });

      test('should convert underscores to spaces in displayName', () {
        // Arrange
        const tagText = 'blue_sky';

        // Act
        final tag = PromptTag.create(text: tagText);

        // Assert
        expect(tag.displayName, equals('blue sky'),
            reason: 'DisplayName should replace underscores with spaces for display');
        expect(tag.displayName, isNot(contains('_')),
            reason: 'DisplayName should not contain underscores');
      });

      test('should handle multiple underscores correctly', () {
        // Arrange
        const tagText = 'long_tag_name_with_many_underscores';

        // Act
        final tag = PromptTag.create(text: tagText);

        // Assert
        expect(tag.text, equals('long_tag_name_with_many_underscores'),
            reason: 'Original text should preserve all underscores');
        expect(tag.displayName, equals('long tag name with many underscores'),
            reason: 'DisplayName should replace all underscores with spaces');
      });

      test('should handle underscores at different positions', () {
        // Arrange & Act
        final tag1 = PromptTag.create(text: '_leading_underscore');
        final tag2 = PromptTag.create(text: 'trailing_underscore_');
        final tag3 = PromptTag.create(text: '_both_underscores_');
        final tag4 = PromptTag.create(text: 'middle_under_score');

        // Assert
        expect(tag1.text, equals('_leading_underscore'),
            reason: 'Should preserve leading underscores');
        expect(tag2.text, equals('trailing_underscore_'),
            reason: 'Should preserve trailing underscores');
        expect(tag3.text, equals('_both_underscores_'),
            reason: 'Should preserve both leading and trailing underscores');
        expect(tag4.text, equals('middle_under_score'),
            reason: 'Should preserve middle underscores');
      });

      test('should handle consecutive underscores', () {
        // Arrange
        const tagText = 'double__underscore';

        // Act
        final tag = PromptTag.create(text: tagText);

        // Assert
        expect(tag.text, equals('double__underscore'),
            reason: 'Should preserve consecutive underscores in original text');
        expect(tag.displayName, equals('double  underscore'),
            reason: 'DisplayName should convert consecutive underscores to multiple spaces');
      });

      test('should handle tags with no underscores', () {
        // Arrange
        const tagText = 'nounderscore';

        // Act
        final tag = PromptTag.create(text: tagText);

        // Assert
        expect(tag.text, equals('nounderscore'),
            reason: 'Text should remain unchanged when no underscores present');
        expect(tag.displayName, equals('nounderscore'),
            reason: 'DisplayName should be same as text when no underscores');
      });

      test('should handle empty string', () {
        // Arrange & Act
        final tag = PromptTag.create(text: '');

        // Assert
        expect(tag.text, equals(''),
            reason: 'Empty text should remain empty');
        expect(tag.displayName, equals(''),
            reason: 'Empty displayName should remain empty');
      });

      test('should handle single underscore only', () {
        // Arrange
        const tagText = '_';

        // Act
        final tag = PromptTag.create(text: tagText);

        // Assert
        expect(tag.text, equals('_'),
            reason: 'Single underscore should be preserved');
        expect(tag.displayName, equals(' '),
            reason: 'Single underscore should be converted to single space');
      });

      test('should handle mixed underscores and special characters', () {
        // Arrange
        const tagText = 'tag_with-special~chars';

        // Act
        final tag = PromptTag.create(text: tagText);

        // Assert
        expect(tag.text, equals('tag_with-special~chars'),
            reason: 'Should preserve underscores and other special characters');
        expect(tag.displayName, contains(' '),
            reason: 'DisplayName should replace underscores with spaces');
        expect(tag.displayName, contains('-'),
            reason: 'DisplayName should preserve other special characters like hyphens');
        expect(tag.displayName, contains('~'),
            reason: 'DisplayName should preserve other special characters like tilde');
      });

      test('should handle underscores in weight syntax', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'blue_sky',
          weight: 1.5,
          syntaxType: WeightSyntaxType.bracket,
        );

        // Act
        final syntaxString = tag.toSyntaxString();

        // Assert
        expect(tag.text, equals('blue_sky'),
            reason: 'Original tag text should preserve underscores');
        expect(syntaxString, contains('blue_sky'),
            reason: 'Weight syntax string should preserve underscores in tag text');
        expect(syntaxString, isNot(contains('blue sky')),
            reason: 'Weight syntax string should not convert underscores to spaces');
      });

      test('should preserve underscores in numeric syntax', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'test_tag',
          weight: 1.5,
          syntaxType: WeightSyntaxType.numeric,
        );

        // Act
        final syntaxString = tag.toSyntaxString();

        // Assert
        expect(syntaxString, contains('test_tag'),
            reason: 'Numeric syntax should preserve underscores');
        expect(syntaxString, isNot(contains('test tag')),
            reason: 'Numeric syntax should not convert underscores to spaces');
      });
    });

    group('Query Normalization', () {
      test('should normalize case while preserving underscores', () {
        // Arrange
        final tag1 = PromptTag.create(text: 'Blue_Sky');
        final tag2 = PromptTag.create(text: 'blue_sky');

        // Act
        final normalized1 = tag1.text.toLowerCase();
        final normalized2 = tag2.text.toLowerCase();

        // Assert
        expect(normalized1, equals(normalized2),
            reason: 'Lowercase normalization should preserve underscores');
        expect(normalized1, equals('blue_sky'),
            reason: 'Underscores should be preserved after case normalization');
      });

      test('should handle mixed case with underscores', () {
        // Arrange
        final tag = PromptTag.create(text: 'MiXeD_CaSe_TaG');

        // Act & Assert
        expect(tag.text, equals('MiXeD_CaSe_TaG'),
            reason: 'Original case should be preserved');
        expect(tag.text.toLowerCase(), equals('mixed_case_tag'),
            reason: 'Lowercasing should preserve underscores');
      });

      test('should preserve whitespace trimming while keeping underscores', () {
        // Arrange
        final tag = PromptTag.create(text: '  blue_sky  ');

        // Act & Assert
        expect(tag.text, equals('blue_sky'),
            reason: 'Whitespace should be trimmed while preserving underscores');
        expect(tag.text, isNot(contains('  ')),
            reason: 'Leading/trailing spaces should be trimmed');
        expect(tag.text, contains('_'),
            reason: 'Internal underscores should be preserved');
      });
    });

    group('Search Query Parsing Edge Cases', () {
      test('should handle tag starting with number and underscore', () {
        // Arrange
        final tag = PromptTag.create(text: '1_2_3_test');

        // Act & Assert
        expect(tag.text, equals('1_2_3_test'),
            reason: 'Should preserve numbers and underscores');
        expect(tag.displayName, equals('1 2 3 test'),
            reason: 'DisplayName should replace underscores with spaces');
      });

      test('should handle very long tag with many underscores', () {
        // Arrange
        final longTagText = 'a_' * 50 + 'end';

        // Act
        final tag = PromptTag.create(text: longTagText);

        // Assert
        expect(tag.text, equals(longTagText),
            reason: 'Should preserve all underscores in long tag');
        expect(tag.displayName.split(' ').length, equals(51),
            reason: 'Should create correct number of space-separated parts');
      });

      test('should handle unicode characters with underscores', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'test_中文_tag',
          translation: 'Chinese Tag Test',
        );

        // Act & Assert
        expect(tag.text, equals('test_中文_tag'),
            reason: 'Should preserve underscores with unicode characters');
        expect(tag.displayName, contains(' '),
            reason: 'DisplayName should replace underscores even with unicode');
      });

      test('should preserve underscores during tag operations', () {
        // Arrange
        final originalTag = PromptTag.create(text: 'original_tag');

        // Act
        final increasedTag = originalTag.increaseWeight();
        final decreasedTag = originalTag.decreaseWeight();
        final toggledTag = originalTag.toggleEnabled();

        // Assert
        expect(increasedTag.text, equals('original_tag'),
            reason: 'Increase weight should preserve tag text with underscores');
        expect(decreasedTag.text, equals('original_tag'),
            reason: 'Decrease weight should preserve tag text with underscores');
        expect(toggledTag.text, equals('original_tag'),
            reason: 'Toggle enabled should preserve tag text with underscores');
      });

      test('should preserve underscores in copyWith operations', () {
        // Arrange
        final originalTag = PromptTag.create(text: 'test_tag');

        // Act
        final copiedTag = originalTag.copyWith(weight: 2.0);

        // Assert
        expect(copiedTag.text, equals('test_tag'),
            reason: 'CopyWith should preserve tag text with underscores');
        expect(copiedTag.text, equals(originalTag.text),
            reason: 'Copied tag text should match original');
      });

      test('should handle tag list operations with underscores', () {
        // Arrange
        final tags = [
          PromptTag.create(text: 'first_tag'),
          PromptTag.create(text: 'second_tag'),
          PromptTag.create(text: 'third_tag'),
        ];

        // Act
        final promptString = tags.toPromptString();

        // Assert
        expect(promptString, contains('first_tag'),
            reason: 'Prompt string should preserve underscores in first tag');
        expect(promptString, contains('second_tag'),
            reason: 'Prompt string should preserve underscores in second tag');
        expect(promptString, contains('third_tag'),
            reason: 'Prompt string should preserve underscores in third tag');
        expect(promptString, isNot(contains('first tag')),
            reason: 'Prompt string should not convert underscores to spaces');
      });

      test('should preserve underscores when filtering selected tags', () {
        // Arrange
        final tags = [
          PromptTag.create(text: 'tag_one').copyWith(selected: true),
          PromptTag.create(text: 'tag_two'),
          PromptTag.create(text: 'tag_three').copyWith(selected: true),
        ];

        // Act
        final selectedTags = tags.selectedTags;

        // Assert
        expect(selectedTags.length, equals(2),
            reason: 'Should find 2 selected tags');
        expect(selectedTags[0].text, equals('tag_one'),
            reason: 'Selected tag should preserve underscores');
        expect(selectedTags[1].text, equals('tag_three'),
            reason: 'Selected tag should preserve underscores');
      });
    });

    group('Integration with Tag Features', () {
      test('should preserve underscores with weight modifications', () {
        // Arrange
        final tag = PromptTag.create(text: 'test_tag', weight: 1.0);

        // Act
        final increased = tag.increaseWeight();
        final decreased = tag.decreaseWeight();
        final reset = increased.resetWeight();

        // Assert
        expect(increased.text, equals('test_tag'),
            reason: 'Increased weight tag should preserve underscores');
        expect(decreased.text, equals('test_tag'),
            reason: 'Decreased weight tag should preserve underscores');
        expect(reset.text, equals('test_tag'),
            reason: 'Reset weight tag should preserve underscores');
      });

      test('should preserve underscores with enabled state changes', () {
        // Arrange
        final tag = PromptTag.create(text: 'test_tag');

        // Act
        final disabledTag = tag.copyWith(enabled: false);
        final reEnabledTag = disabledTag.copyWith(enabled: true);

        // Assert
        expect(disabledTag.text, equals('test_tag'),
            reason: 'Disabling tag should preserve underscores');
        expect(reEnabledTag.text, equals('test_tag'),
            reason: 'Re-enabling tag should preserve underscores');
        expect(disabledTag.toSyntaxString(), equals(''),
            reason: 'Disabled tag should produce empty syntax string');
        expect(reEnabledTag.toSyntaxString(), equals('test_tag'),
            reason: 'Re-enabled tag should produce syntax string with underscores');
      });

      test('should handle underscores with translation', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'blue_sky',
          translation: '蓝天',
        );

        // Act & Assert
        expect(tag.text, equals('blue_sky'),
            reason: 'Tag text should preserve underscores');
        expect(tag.translation, equals('蓝天'),
            reason: 'Translation should be independent of underscores');
        expect(tag.displayName, equals('blue sky'),
            reason: 'DisplayName should replace underscores with spaces');
      });

      test('should preserve underscores with category', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'character_name',
          category: 4, // character category
        );

        // Act & Assert
        expect(tag.text, equals('character_name'),
            reason: 'Tag text should preserve underscores regardless of category');
        expect(tag.category, equals(4),
            reason: 'Category should be independent of underscore handling');
      });

      test('should preserve underscores in batch operations', () {
        // Arrange
        final tags = [
          PromptTag.create(text: 'tag_1'),
          PromptTag.create(text: 'tag_2'),
          PromptTag.create(text: 'tag_3'),
        ];

        // Act
        final allSelected = tags.toggleSelectAll(true);
        final allDisabled = allSelected.disableSelected();
        final allEnabled = allDisabled.enableSelected();

        // Assert
        for (final tag in allSelected) {
          expect(tag.text.contains('_'), isTrue,
              reason: 'All selected tags should preserve underscores');
        }
        for (final tag in allDisabled) {
          expect(tag.text.contains('_'), isTrue,
              reason: 'All disabled tags should preserve underscores');
        }
        for (final tag in allEnabled) {
          expect(tag.text.contains('_'), isTrue,
              reason: 'All re-enabled tags should preserve underscores');
        }

        // Test removeSelected with properly selected tags
        final selectedForRemoval = allEnabled.toggleSelectAll(true);
        final removedSelected = selectedForRemoval.removeSelected();

        expect(removedSelected.isEmpty, isTrue,
            reason: 'All tags should be removed after removeSelected operation');
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle null-like inputs gracefully', () {
        // Arrange & Act
        final tag1 = PromptTag.create(text: '');
        final tag2 = PromptTag.create(text: '_');
        final tag3 = PromptTag.create(text: '__');

        // Assert
        expect(tag1.text, equals(''),
            reason: 'Empty string should be handled');
        expect(tag2.text, equals('_'),
            reason: 'Single underscore should be preserved');
        expect(tag3.text, equals('__'),
            reason: 'Double underscore should be preserved');
      });

      test('should handle extremely long underscores sequences', () {
        // Arrange
        final longUnderscores = '_' * 100;
        final tag = PromptTag.create(text: longUnderscores);

        // Act & Assert
        expect(tag.text, equals(longUnderscores),
            reason: 'Should preserve extremely long underscore sequences');
        expect(tag.text.length, equals(100),
            reason: 'Length should be preserved');
      });

      test('should preserve underscores during serialization', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'test_tag',
          weight: 1.5,
          category: 2,
          translation: 'Test Tag',
        );

        // Act
        final json = tag.toJson();
        final deserialized = PromptTag.fromJson(json);

        // Assert
        expect(deserialized.text, equals('test_tag'),
            reason: 'Deserialized tag should preserve underscores');
        expect(json['text'], equals('test_tag'),
            reason: 'JSON should preserve underscores in text field');
      });

      test('should handle underscore-only tags', () {
        // Arrange
        final underscoreTags = [
          PromptTag.create(text: '_'),
          PromptTag.create(text: '__'),
          PromptTag.create(text: '___'),
        ];

        // Act & Assert
        for (final tag in underscoreTags) {
          expect(tag.text.contains('_'), isTrue,
              reason: 'Underscore-only tags should preserve underscores');
          expect(tag.displayName.contains(' '), isTrue,
              reason: 'DisplayName should convert underscores to spaces');
        }
      });
    });
  });
}
