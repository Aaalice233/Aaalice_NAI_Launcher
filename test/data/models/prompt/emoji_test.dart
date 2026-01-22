import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/default_category_emojis.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';

void main() {
  group('RandomCategory emoji', () {
    test('should create with emoji', () {
      const category = RandomCategory(
        id: 'test-id',
        name: 'Test Category',
        key: 'testCategory',
        emoji: '🎯',
      );

      expect(category.emoji, equals('🎯'));
      expect(category.isBuiltin, isFalse);
    });

    test('should create builtin category', () {
      const category = RandomCategory(
        id: 'test-id',
        name: 'Built-in Category',
        key: 'hairColor',
        emoji: '🎨',
        isBuiltin: true,
      );

      expect(category.emoji, equals('🎨'));
      expect(category.isBuiltin, isTrue);
    });

    test('should have empty emoji by default', () {
      const category = RandomCategory(
        id: 'test-id',
        name: 'No Emoji Category',
        key: 'noEmoji',
      );

      expect(category.emoji, isEmpty);
    });

    test('should serialize and deserialize emoji correctly', () {
      const original = RandomCategory(
        id: 'test-id',
        name: 'Emoji Category',
        key: 'emojiTest',
        emoji: '🔥',
        isBuiltin: false,
      );

      // Serialize
      final json = original.toJson();
      expect(json['emoji'], equals('🔥'));
      expect(json['isBuiltin'], isFalse);

      // Deserialize
      final restored = RandomCategory.fromJson(json);
      expect(restored.emoji, equals(original.emoji));
      expect(restored.isBuiltin, equals(original.isBuiltin));
    });

    test('should handle complex emoji correctly', () {
      // Test compound emojis (with modifiers)
      const category = RandomCategory(
        id: 'test-id',
        name: 'Complex Emoji',
        key: 'complex',
        emoji: '👁️',
      );

      final json = category.toJson();
      final restored = RandomCategory.fromJson(json);

      expect(restored.emoji, equals('👁️'));
    });
  });

  group('RandomTagGroup emoji', () {
    test('should create custom group with emoji', () {
      final group = RandomTagGroup.custom(
        name: 'Custom Group',
        emoji: '✨',
        tags: [WeightedTag.simple('tag1', 10)],
      );

      expect(group.emoji, equals('✨'));
      expect(group.sourceType, equals(TagGroupSourceType.custom));
    });

    test('should create custom group with default emoji', () {
      final group = RandomTagGroup.custom(
        name: 'No Emoji Group',
        tags: [WeightedTag.simple('tag1', 10)],
      );

      expect(group.emoji, isEmpty);
    });

    test('should serialize and deserialize emoji correctly', () {
      final original = RandomTagGroup.custom(
        name: 'Emoji Group',
        emoji: '🌟',
        tags: [WeightedTag.simple('star_tag', 10)],
      );

      final json = original.toJson();
      expect(json['emoji'], equals('🌟'));

      // Convert all nested objects to proper JSON format for fromJson
      // (Freezed's toJson doesn't automatically call toJson on nested objects)
      final jsonForFromJson = <String, dynamic>{
        ...json,
        'tags': (json['tags'] as List).map((tag) {
          if (tag is WeightedTag) {
            return tag.toJson();
          }
          return tag;
        }).toList(),
        'poolOutputConfig': json['poolOutputConfig'] != null
            ? (json['poolOutputConfig'] as dynamic).toJson()
            : null,
        'conditionalBranchConfig': json['conditionalBranchConfig'] != null
            ? (json['conditionalBranchConfig'] as dynamic).toJson()
            : null,
        'dependencyConfig': json['dependencyConfig'] != null
            ? (json['dependencyConfig'] as dynamic).toJson()
            : null,
        'timeCondition': json['timeCondition'] != null
            ? (json['timeCondition'] as dynamic).toJson()
            : null,
        'visibilityRules': (json['visibilityRules'] as List?)
                ?.map((e) => e is Map ? e : (e as dynamic).toJson())
                .toList() ??
            [],
        'postProcessRules': (json['postProcessRules'] as List?)
                ?.map((e) => e is Map ? e : (e as dynamic).toJson())
                .toList() ??
            [],
        'children': (json['children'] as List?)
                ?.map((e) => e is Map ? e : (e as dynamic).toJson())
                .toList() ??
            [],
      };

      final restored = RandomTagGroup.fromJson(jsonForFromJson);
      expect(restored.emoji, equals(original.emoji));
    });
  });

  group('DefaultCategoryEmojis', () {
    test('should return correct emoji for builtin category keys', () {
      expect(DefaultCategoryEmojis.categoryEmojis['hairColor'], equals('🎨'));
      expect(DefaultCategoryEmojis.categoryEmojis['eyeColor'], equals('👁️'));
      expect(DefaultCategoryEmojis.categoryEmojis['expression'], equals('😊'));
      expect(DefaultCategoryEmojis.categoryEmojis['clothing'], equals('👗'));
    });

    test('should return fallback emoji for unknown key', () {
      const unknownCategory = RandomCategory(
        id: 'unknown-id',
        name: 'Unknown Category',
        key: 'unknownKey',
      );

      final emoji = DefaultCategoryEmojis.getCategoryEmoji(unknownCategory);
      expect(emoji, equals(DefaultCategoryEmojis.fallbackEmoji));
    });

    test('should prefer custom emoji over default', () {
      const customEmojiCategory = RandomCategory(
        id: 'custom-id',
        name: 'Hair Color',
        key: 'hairColor',
        emoji: '🌈', // Custom emoji overrides default '🎨'
      );

      final emoji = DefaultCategoryEmojis.getCategoryEmoji(customEmojiCategory);
      expect(emoji, equals('🌈'));
    });

    test('should use default when custom emoji is empty', () {
      const defaultEmojiCategory = RandomCategory(
        id: 'default-id',
        name: 'Hair Color',
        key: 'hairColor',
        emoji: '', // Empty, should use default
      );

      final emoji = DefaultCategoryEmojis.getCategoryEmoji(defaultEmojiCategory);
      expect(emoji, equals('🎨'));
    });

    test('should return correct emoji for source types', () {
      expect(
        DefaultCategoryEmojis.sourceTypeEmojis[TagGroupSourceType.custom],
        equals('✨'),
      );
      expect(
        DefaultCategoryEmojis.sourceTypeEmojis[TagGroupSourceType.tagGroup],
        equals('☁️'),
      );
      expect(
        DefaultCategoryEmojis.sourceTypeEmojis[TagGroupSourceType.pool],
        equals('🖼️'),
      );
    });

    test('getGroupEmoji should prefer custom emoji', () {
      final customGroup = RandomTagGroup.custom(
        name: 'Custom',
        emoji: '🎉',
        tags: [WeightedTag.simple('tag', 10)],
      );

      expect(DefaultCategoryEmojis.getGroupEmoji(customGroup), equals('🎉'));
    });

    test('getGroupEmoji should use source type default when no custom emoji', () {
      final group = RandomTagGroup.custom(
        name: 'No Emoji',
        tags: [WeightedTag.simple('tag', 10)],
      );

      expect(DefaultCategoryEmojis.getGroupEmoji(group), equals('✨'));
    });

    test('getSourceTypeEmoji should return correct defaults', () {
      expect(
        DefaultCategoryEmojis.getSourceTypeEmoji(TagGroupSourceType.custom),
        equals('✨'),
      );
      expect(
        DefaultCategoryEmojis.getSourceTypeEmoji(TagGroupSourceType.tagGroup),
        equals('☁️'),
      );
      expect(
        DefaultCategoryEmojis.getSourceTypeEmoji(TagGroupSourceType.pool),
        equals('🖼️'),
      );
    });
  });

  group('Backward compatibility', () {
    test('should handle old data without emoji field', () {
      // Simulate old JSON data without emoji field
      final oldJson = {
        'id': 'old-id',
        'name': 'Old Category',
        'key': 'oldCategory',
        // No 'emoji' field
        // No 'isBuiltin' field
        'enabled': true,
        'probability': 1.0,
        'groupSelectionMode': 'single',
        'groupSelectCount': 1,
        'shuffle': true,
        'unifiedBracketMin': 0,
        'unifiedBracketMax': 0,
        'useUnifiedBracket': false,
        'groups': [],
      };

      final category = RandomCategory.fromJson(oldJson);

      // Should use default values
      expect(category.emoji, isEmpty);
      expect(category.isBuiltin, isFalse);
    });

    test('should handle old RandomTagGroup without emoji', () {
      final oldJson = {
        'id': 'old-group-id',
        'name': 'Old Group',
        // No 'emoji' field
        'sourceType': 'custom',
        'enabled': true,
        'probability': 1.0,
        'selectionMode': 'single',
        'selectCount': 1,
        'shuffle': true,
        'bracketMin': 0,
        'bracketMax': 0,
        'tags': [
          {'tag': 'test_tag', 'weight': 10},
        ],
      };

      final group = RandomTagGroup.fromJson(oldJson);

      // Should use default values
      expect(group.emoji, isEmpty);
    });
  });
}
