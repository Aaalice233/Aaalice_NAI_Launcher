import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/data/models/prompt/tag_favorite.dart';

void main() {
  group('TagFavorite', () {
    group('Constructor and Factory', () {
      test('should create instance with all required fields', () {
        // Arrange
        final tag = PromptTag.create(text: 'test_tag');
        final id = 'test-id';
        final createdAt = DateTime(2024, 1, 1);

        // Act
        final favorite = TagFavorite(
          id: id,
          tag: tag,
          createdAt: createdAt,
        );

        // Assert
        expect(favorite.id, equals(id),
            reason: 'ID should match the provided value');
        expect(favorite.tag, equals(tag),
            reason: 'Tag should match the provided value');
        expect(favorite.createdAt, equals(createdAt),
            reason: 'CreatedAt should match the provided value');
        expect(favorite.notes, isNull,
            reason: 'Notes should be null when not provided');
      });

      test('should create instance with optional notes', () {
        // Arrange
        final tag = PromptTag.create(text: 'test_tag');
        final notes = 'My favorite tag';

        // Act
        final favorite = TagFavorite(
          id: 'test-id',
          tag: tag,
          createdAt: DateTime.now(),
          notes: notes,
        );

        // Assert
        expect(favorite.notes, equals(notes),
            reason: 'Notes should match the provided value');
      });

      test('should create instance using create factory', () {
        // Arrange
        final tag = PromptTag.create(text: 'test_tag');
        final notes = 'Test notes';

        // Act
        final favorite = TagFavorite.create(
          tag: tag,
          notes: notes,
        );

        // Assert
        expect(favorite.id, isNotEmpty,
            reason: 'ID should be generated automatically');
        expect(favorite.tag, equals(tag),
            reason: 'Tag should match the provided value');
        expect(favorite.notes, equals(notes),
            reason: 'Notes should match the provided value');
        expect(
            favorite.createdAt.difference(DateTime.now()).inSeconds,
            lessThanOrEqualTo(1),
            reason: 'CreatedAt should be close to current time');
      });

      test('should create instance without notes using create factory', () {
        // Arrange
        final tag = PromptTag.create(text: 'test_tag');

        // Act
        final favorite = TagFavorite.create(tag: tag);

        // Assert
        expect(favorite.notes, isNull,
            reason: 'Notes should be null when not provided');
      });
    });

    group('Getters', () {
      test('displayName should return tag displayName', () {
        // Arrange
        final tag = PromptTag.create(text: 'test_tag_with_underscores');
        final favorite = TagFavorite(
          id: 'test-id',
          tag: tag,
          createdAt: DateTime.now(),
        );

        // Act
        final displayName = favorite.displayName;

        // Assert
        expect(displayName, equals('test tag with underscores'),
            reason: 'DisplayName should replace underscores with spaces');
      });

      test('hasNotes should return true when notes is not empty', () {
        // Arrange
        final favorite = TagFavorite(
          id: 'test-id',
          tag: PromptTag.create(text: 'test'),
          createdAt: DateTime.now(),
          notes: 'Some notes',
        );

        // Act & Assert
        expect(favorite.hasNotes, isTrue,
            reason: 'hasNotes should be true when notes is not empty');
      });

      test('hasNotes should return false when notes is null', () {
        // Arrange
        final favorite = TagFavorite(
          id: 'test-id',
          tag: PromptTag.create(text: 'test'),
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(favorite.hasNotes, isFalse,
            reason: 'hasNotes should be false when notes is null');
      });

      test('hasNotes should return false when notes is empty string', () {
        // Arrange
        final favorite = TagFavorite(
          id: 'test-id',
          tag: PromptTag.create(text: 'test'),
          createdAt: DateTime.now(),
          notes: '',
        );

        // Act & Assert
        expect(favorite.hasNotes, isFalse,
            reason: 'hasNotes should be false when notes is empty string');
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'test_tag',
          weight: 1.2,
          category: 1,
        );
        final favorite = TagFavorite(
          id: 'test-id',
          tag: tag,
          createdAt: DateTime(2024, 1, 1, 12, 0),
          notes: 'Test notes',
        );

        // Act
        final json = favorite.toJson();

        // Assert
        expect(json['id'], equals('test-id'),
            reason: 'ID should be serialized correctly');
        expect(json['notes'], equals('Test notes'),
            reason: 'Notes should be serialized correctly');
        expect(json['createdAt'], isNotNull,
            reason: 'CreatedAt should be serialized');
        expect(json['tag'], isNotNull,
            reason: 'Tag should be serialized');
      });

      test('should handle serialization with complex tag', () {
        // Arrange
        final tag = PromptTag.create(
          text: 'complex_tag',
          weight: 1.5,
          category: 4,
          translation: '复杂标签',
        );
        final favorite = TagFavorite.create(
          tag: tag,
          notes: 'Complex notes with 中文',
        );

        // Act
        final json = favorite.toJson();

        // Assert
        expect(json['id'], isNotEmpty,
            reason: 'ID should be serialized');
        expect(json['notes'], equals('Complex notes with 中文'),
            reason: 'Notes should be serialized correctly');
        expect(json['tag'], isNotNull,
            reason: 'Tag should be serialized');
        expect(json['createdAt'], isNotNull,
            reason: 'CreatedAt should be serialized');
      });
    });

    group('Immutability', () {
      test('copyWith should create new instance with updated values', () {
        // Arrange
        final original = TagFavorite.create(
          tag: PromptTag.create(text: 'test'),
        );
        final newTag = PromptTag.create(text: 'new_tag');

        // Act
        final updated = original.copyWith(tag: newTag);

        // Assert
        expect(updated.tag.text, equals('new_tag'),
            reason: 'Tag should be updated');
        expect(original.tag.text, equals('test'),
            reason: 'Original should remain unchanged');
        expect(updated.id, equals(original.id),
            reason: 'ID should remain the same');
      });

      test('copyWith should update notes', () {
        // Arrange
        final original = TagFavorite.create(
          tag: PromptTag.create(text: 'test'),
        );

        // Act
        final updated = original.copyWith(notes: 'Updated notes');

        // Assert
        expect(updated.notes, equals('Updated notes'),
            reason: 'Notes should be updated');
        expect(original.notes, isNull,
            reason: 'Original notes should remain null');
      });
    });

    group('Edge Cases', () {
      test('should handle tag with special characters', () {
        // Arrange
        final tag = PromptTag.create(text: 'tag_with-special~characters');

        // Act
        final favorite = TagFavorite.create(tag: tag);

        // Assert
        expect(favorite.tag.text, equals('tag_with-special~characters'),
            reason: 'Should handle special characters in tag text');
        expect(favorite.displayName, contains(' '),
            reason: 'DisplayName should still replace underscores');
      });

      test('should handle very long notes', () {
        // Arrange
        final longNotes = 'A' * 1000;

        // Act
        final favorite = TagFavorite.create(
          tag: PromptTag.create(text: 'test'),
          notes: longNotes,
        );

        // Assert
        expect(favorite.notes?.length, equals(1000),
            reason: 'Should handle long notes');
        expect(favorite.hasNotes, isTrue,
            reason: 'Long notes should still be considered valid');
      });

      test('should handle tag with weight modifications', () {
        // Arrange
        final tag = PromptTag.create(text: 'test', weight: 1.5);

        // Act
        final favorite = TagFavorite.create(tag: tag);

        // Assert
        expect(favorite.tag.weight, equals(1.5),
            reason: 'Should preserve tag weight');
        expect(favorite.tag.bracketLayers, equals(10),
            reason: 'Should calculate correct bracket layers');
      });

      test('should handle disabled tags', () {
        // Arrange
        final tag = PromptTag.create(text: 'test').copyWith(enabled: false);

        // Act
        final favorite = TagFavorite.create(tag: tag);

        // Assert
        expect(favorite.tag.enabled, isFalse,
            reason: 'Should preserve tag enabled state');
        expect(favorite.tag.toSyntaxString(), equals(''),
            reason: 'Disabled tag should produce empty syntax string');
      });
    });
  });
}
