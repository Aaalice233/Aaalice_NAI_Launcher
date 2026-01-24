import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/data/models/prompt/tag_template.dart';

void main() {
  group('TagTemplate', () {
    late List<PromptTag> sampleTags;

    setUp(() {
      sampleTags = [
        PromptTag.create(text: 'masterpiece', weight: 1.2),
        PromptTag.create(text: 'best_quality', weight: 1.1),
        PromptTag.create(text: '1girl', category: 4),
        PromptTag.create(text: 'solo'),
      ];
    });

    group('Constructor and Factory', () {
      test('should create instance with all required fields', () {
        // Arrange
        final id = 'test-id';
        final name = 'Test Template';
        final createdAt = DateTime(2024, 1, 1);
        final updatedAt = DateTime(2024, 1, 2);

        // Act
        final template = TagTemplate(
          id: id,
          name: name,
          tags: sampleTags,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        // Assert
        expect(template.id, equals(id),
            reason: 'ID should match the provided value');
        expect(template.name, equals(name),
            reason: 'Name should match the provided value');
        expect(template.tags, equals(sampleTags),
            reason: 'Tags should match the provided value');
        expect(template.createdAt, equals(createdAt),
            reason: 'CreatedAt should match the provided value');
        expect(template.updatedAt, equals(updatedAt),
            reason: 'UpdatedAt should match the provided value');
        expect(template.description, isNull,
            reason: 'Description should be null when not provided');
      });

      test('should create instance with optional description', () {
        // Arrange
        final description = 'A test template';

        // Act
        final template = TagTemplate(
          id: 'test-id',
          name: 'Test',
          tags: sampleTags,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          description: description,
        );

        // Assert
        expect(template.description, equals(description),
            reason: 'Description should match the provided value');
      });

      test('should create instance using create factory', () {
        // Arrange
        final name = 'Test Template';
        final description = 'Test description';

        // Act
        final template = TagTemplate.create(
          name: name,
          tags: sampleTags,
          description: description,
        );

        // Assert
        expect(template.id, isNotEmpty,
            reason: 'ID should be generated automatically');
        expect(template.name, equals(name.trim()),
            reason: 'Name should be trimmed');
        expect(template.tags, equals(sampleTags),
            reason: 'Tags should match the provided value');
        expect(template.description, equals(description),
            reason: 'Description should be trimmed');
        expect(
            template.createdAt.difference(DateTime.now()).inSeconds,
            lessThanOrEqualTo(1),
            reason: 'CreatedAt should be close to current time');
        expect(
            template.updatedAt.difference(DateTime.now()).inSeconds,
            lessThanOrEqualTo(1),
            reason: 'UpdatedAt should be close to current time');
      });

      test('should trim name in create factory', () {
        // Arrange
        final nameWithSpaces = '  Test Template  ';

        // Act
        final template = TagTemplate.create(
          name: nameWithSpaces,
          tags: sampleTags,
        );

        // Assert
        expect(template.name, equals('Test Template'),
            reason: 'Name should be trimmed');
      });

      test('should trim description in create factory', () {
        // Arrange
        final descriptionWithSpaces = '  Test Description  ';

        // Act
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
          description: descriptionWithSpaces,
        );

        // Assert
        expect(template.description, equals('Test Description'),
            reason: 'Description should be trimmed');
      });

      test('should handle null description in create factory', () {
        // Act
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );

        // Assert
        expect(template.description, isNull,
            reason: 'Description should be null when not provided');
      });
    });

    group('Getters', () {
      test('displayName should return name when not empty', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'My Template',
          tags: sampleTags,
        );

        // Act
        final displayName = template.displayName;

        // Assert
        expect(displayName, equals('My Template'),
            reason: 'DisplayName should return the name');
      });

      test('displayName should return default when name is empty', () {
        // Arrange
        final template = TagTemplate(
          id: 'test-id',
          name: '',
          tags: sampleTags,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final displayName = template.displayName;

        // Assert
        expect(displayName, equals('未命名模板'),
            reason: 'DisplayName should return default for empty name');
      });

      test('hasDescription should return true when description is not empty', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
          description: 'Some description',
        );

        // Act & Assert
        expect(template.hasDescription, isTrue,
            reason: 'hasDescription should be true when description exists');
      });

      test('hasDescription should return false when description is null', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );

        // Act & Assert
        expect(template.hasDescription, isFalse,
            reason: 'hasDescription should be false when description is null');
      });

      test('hasDescription should return false when description is empty', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
          description: '',
        );

        // Act & Assert
        expect(template.hasDescription, isFalse,
            reason: 'hasDescription should be false when description is empty');
      });

      test('tagCount should return number of tags', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );

        // Act
        final count = template.tagCount;

        // Assert
        expect(count, equals(4),
            reason: 'tagCount should return the number of tags');
      });

      test('enabledTags should return only enabled tags', () {
        // Arrange
        final mixedTags = [
          PromptTag.create(text: 'enabled1'),
          PromptTag.create(text: 'disabled1').copyWith(enabled: false),
          PromptTag.create(text: 'enabled2'),
          PromptTag.create(text: 'disabled2').copyWith(enabled: false),
        ];
        final template = TagTemplate.create(
          name: 'Test',
          tags: mixedTags,
        );

        // Act
        final enabled = template.enabledTags;

        // Assert
        expect(enabled.length, equals(2),
            reason: 'Should only return enabled tags');
        expect(enabled.every((tag) => tag.enabled), isTrue,
            reason: 'All returned tags should be enabled');
      });
    });

    group('Methods', () {
      test('toPromptString should convert tags to prompt string', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );

        // Act
        final promptString = template.toPromptString();

        // Assert
        expect(promptString, contains('masterpiece'),
            reason: 'Should contain tag text');
        expect(promptString, contains(','),
            reason: 'Should separate tags with commas');
      });

      test('toPromptString should skip disabled tags', () {
        // Arrange
        final tagsWithDisabled = [
          PromptTag.create(text: 'enabled'),
          PromptTag.create(text: 'disabled').copyWith(enabled: false),
        ];
        final template = TagTemplate.create(
          name: 'Test',
          tags: tagsWithDisabled,
        );

        // Act
        final promptString = template.toPromptString();

        // Assert
        expect(promptString, contains('enabled'),
            reason: 'Should contain enabled tags');
        expect(promptString, isNot(contains('disabled')),
            reason: 'Should not contain disabled tags');
      });

      test('updateTags should update tags and updatedAt', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );
        final newTags = [PromptTag.create(text: 'new_tag')];

        // Act
        final updated = template.updateTags(newTags);

        // Assert
        expect(updated.tags, equals(newTags),
            reason: 'Tags should be updated');
        expect(updated.updatedAt.isAfter(template.updatedAt), isTrue,
            reason: 'UpdatedAt should be updated');
        expect(template.tags, equals(sampleTags),
            reason: 'Original template should remain unchanged');
      });

      test('updateName should update name and updatedAt', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Old Name',
          tags: sampleTags,
        );

        // Act
        final updated = template.updateName('New Name');

        // Assert
        expect(updated.name, equals('New Name'),
            reason: 'Name should be updated');
        expect(updated.updatedAt.isAfter(template.updatedAt), isTrue,
            reason: 'UpdatedAt should be updated');
        expect(template.name, equals('Old Name'),
            reason: 'Original template should remain unchanged');
      });

      test('updateName should trim the new name', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Old Name',
          tags: sampleTags,
        );

        // Act
        final updated = template.updateName('  New Name  ');

        // Assert
        expect(updated.name, equals('New Name'),
            reason: 'Name should be trimmed');
      });

      test('updateDescription should update description and updatedAt', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );

        // Act
        final updated = template.updateDescription('New Description');

        // Assert
        expect(updated.description, equals('New Description'),
            reason: 'Description should be updated');
        expect(updated.updatedAt.isAfter(template.updatedAt), isTrue,
            reason: 'UpdatedAt should be updated');
      });

      test('updateDescription should trim the new description', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );

        // Act
        final updated = template.updateDescription('  New Description  ');

        // Assert
        expect(updated.description, equals('New Description'),
            reason: 'Description should be trimmed');
      });

      test('addTag should add tag to the end and update updatedAt', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );
        final newTag = PromptTag.create(text: 'new_tag');

        // Act
        final updated = template.addTag(newTag);

        // Assert
        expect(updated.tags.length, equals(5),
            reason: 'Tag count should increase by 1');
        expect(updated.tags.last, equals(newTag),
            reason: 'New tag should be at the end');
        expect(updated.updatedAt.isAfter(template.updatedAt), isTrue,
            reason: 'UpdatedAt should be updated');
      });

      test('removeTag should remove tag by ID and update updatedAt', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );
        final tagToRemove = sampleTags[1];

        // Act
        final updated = template.removeTag(tagToRemove.id);

        // Assert
        expect(updated.tags.length, equals(3),
            reason: 'Tag count should decrease by 1');
        expect(updated.tags.any((tag) => tag.id == tagToRemove.id), isFalse,
            reason: 'Removed tag should not be in the list');
        expect(updated.updatedAt.isAfter(template.updatedAt), isTrue,
            reason: 'UpdatedAt should be updated');
      });

      test('clearTags should remove all tags and update updatedAt', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test',
          tags: sampleTags,
        );

        // Act
        final updated = template.clearTags();

        // Assert
        expect(updated.tags.isEmpty, isTrue,
            reason: 'All tags should be removed');
        expect(updated.updatedAt.isAfter(template.updatedAt), isTrue,
            reason: 'UpdatedAt should be updated');
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Arrange
        final template = TagTemplate.create(
          name: 'Test Template',
          tags: sampleTags,
          description: 'Test description',
        );

        // Act
        final json = template.toJson();

        // Assert
        expect(json['id'], isNotEmpty,
            reason: 'ID should be serialized');
        expect(json['name'], equals('Test Template'),
            reason: 'Name should be serialized');
        expect(json['description'], equals('Test description'),
            reason: 'Description should be serialized');
        expect(json['tags'], isNotNull,
            reason: 'Tags should be serialized');
        expect(json['createdAt'], isNotNull,
            reason: 'CreatedAt should be serialized');
        expect(json['updatedAt'], isNotNull,
            reason: 'UpdatedAt should be serialized');
      });

      test('should handle serialization with complex template', () {
        // Arrange
        final original = TagTemplate.create(
          name: 'Complex Template',
          tags: sampleTags,
          description: 'Complex description with 中文',
        );

        // Act
        final json = original.toJson();

        // Assert
        expect(json['id'], isNotEmpty,
            reason: 'ID should be serialized');
        expect(json['name'], equals('Complex Template'),
            reason: 'Name should be serialized');
        expect(json['description'], equals('Complex description with 中文'),
            reason: 'Description should be serialized');
        expect(json['tags'], isNotNull,
            reason: 'Tags should be serialized');
        expect(json['createdAt'], isNotNull,
            reason: 'CreatedAt should be serialized');
        expect(json['updatedAt'], isNotNull,
            reason: 'UpdatedAt should be serialized');
      });
    });

    group('TagTemplateListExtension', () {
      late List<TagTemplate> templates;

      setUp(() {
        templates = [
          TagTemplate.create(
            name: 'Zebra Template',
            tags: [PromptTag.create(text: 'tag1')],
          ),
          TagTemplate.create(
            name: 'Apple Template',
            tags: [
              PromptTag.create(text: 'tag1'),
              PromptTag.create(text: 'tag2'),
            ],
          ),
          TagTemplate.create(
            name: 'middle Template',
            tags: [PromptTag.create(text: 'tag1')],
          ),
        ];
      });

      test('sortByName should sort case-insensitively', () {
        // Act
        final sorted = templates.sortByName();

        // Assert
        expect(sorted[0].name, equals('Apple Template'),
            reason: 'Apple should come first');
        expect(sorted[1].name, equals('middle Template'),
            reason: 'middle should come second');
        expect(sorted[2].name, equals('Zebra Template'),
            reason: 'Zebra should come last');
      });

      test('sortByName should not modify original list', () {
        // Act
        final sorted = templates.sortByName();

        // Assert
        expect(templates[0].name, equals('Zebra Template'),
            reason: 'Original list should remain unchanged');
      });

      test('sortByUpdatedAt should put most recent first', () {
        // Arrange
        final oldest = templates[0];
        final newest = templates[1];
        // Simulate time passing by updating updatedAt
        final updated = [
          oldest,
          newest.copyWith(updatedAt: DateTime.now().add(const Duration(days: 1))),
          templates[2],
        ];

        // Act
        final sorted = updated.sortByUpdatedAt();

        // Assert
        expect(sorted[0].name, equals(newest.name),
            reason: 'Newest should be first');
        expect(sorted.last.name, equals(oldest.name),
            reason: 'Oldest should be last');
      });

      test('sortByCreatedAt should put most recent first', () {
        // Arrange
        final oldest = templates[0];
        final newest = templates[1];
        final withDifferentCreatedAt = [
          oldest,
          TagTemplate.create(
            name: 'Newest',
            tags: [PromptTag.create(text: 'tag')],
          ),
        ];

        // Act
        final sorted = withDifferentCreatedAt.sortByCreatedAt();

        // Assert
        expect(sorted[0].name, equals('Newest'),
            reason: 'Newest should be first');
        expect(sorted[1].id, equals(oldest.id),
            reason: 'Oldest should be last');
      });

      test('sortByTagCount should sort by tag count descending', () {
        // Act
        final sorted = templates.sortByTagCount();

        // Assert
        expect(sorted[0].tagCount, equals(2),
            reason: 'Template with most tags should be first');
        expect(sorted[1].tagCount, equals(1),
            reason: 'Template with 1 tag should be second');
        expect(sorted[2].tagCount, equals(1),
            reason: 'Template with 1 tag should be third');
      });

      test('findContainingTag should find templates with specific tag', () {
        // Arrange
        // Each template has unique tags, so we need to create templates with a shared tag
        final sharedTag = PromptTag.create(text: 'shared_tag');
        final templatesWithSharedTag = [
          TagTemplate.create(name: 'A', tags: [sharedTag]),
          TagTemplate.create(name: 'B', tags: [PromptTag.create(text: 'unique'), sharedTag]),
          TagTemplate.create(name: 'C', tags: [PromptTag.create(text: 'other')]),
        ];

        // Act
        final found = templatesWithSharedTag.findContainingTag(sharedTag.id);

        // Assert
        expect(found.length, equals(2),
            reason: 'Should find all templates containing the shared tag');
      });

      test('searchByName should search name and description', () {
        // Arrange
        final templatesWithDesc = [
          ...templates,
          TagTemplate.create(
            name: 'Template 4',
            tags: [PromptTag.create(text: 'tag')],
            description: 'Contains search term',
          ),
        ];

        // Act
        final found = templatesWithDesc.searchByName('search');

        // Assert
        expect(found.length, equals(1),
            reason: 'Should find template with search term in description');
        expect(found[0].description, contains('search'),
            reason: 'Found template should contain the search term');
      });

      test('searchByName should be case-insensitive', () {
        // Act
        final found = templates.searchByName('APPLE');

        // Assert
        expect(found.length, equals(1),
            reason: 'Should find template ignoring case');
        expect(found[0].name, equals('Apple Template'),
            reason: 'Should return correct template');
      });

      test('searchByName should return all when query is empty', () {
        // Act
        final found = templates.searchByName('');

        // Assert
        expect(found.length, equals(templates.length),
            reason: 'Should return all templates when query is empty');
      });
    });

    group('Edge Cases', () {
      test('should handle empty tag list', () {
        // Act
        final template = TagTemplate.create(
          name: 'Empty Template',
          tags: [],
        );

        // Assert
        expect(template.tagCount, equals(0),
            reason: 'Should handle empty tag list');
        expect(template.enabledTags.isEmpty, isTrue,
            reason: 'Enabled tags should be empty');
        expect(template.toPromptString(), equals(''),
            reason: 'Prompt string should be empty');
      });

      test('should handle template with all disabled tags', () {
        // Arrange
        final disabledTags = sampleTags.map((t) => t.copyWith(enabled: false)).toList();

        // Act
        final template = TagTemplate.create(
          name: 'All Disabled',
          tags: disabledTags,
        );

        // Assert
        expect(template.tagCount, equals(4),
            reason: 'Tag count should include disabled tags');
        expect(template.enabledTags.isEmpty, isTrue,
            reason: 'Enabled tags should be empty');
        expect(template.toPromptString(), equals(''),
            reason: 'Prompt string should be empty');
      });

      test('should handle very long template name', () {
        // Arrange
        final longName = 'A' * 1000;

        // Act
        final template = TagTemplate.create(
          name: longName,
          tags: sampleTags,
        );

        // Assert
        expect(template.name.length, equals(1000),
            reason: 'Should handle long names');
        expect(template.displayName, equals(longName),
            reason: 'DisplayName should preserve long name');
      });

      test('should handle template name with only spaces', () {
        // Arrange
        final nameWithOnlySpaces = '   ';

        // Act
        final template = TagTemplate.create(
          name: nameWithOnlySpaces,
          tags: sampleTags,
        );

        // Assert
        expect(template.name, equals(''),
            reason: 'Name should be trimmed to empty string');
        expect(template.displayName, equals('未命名模板'),
            reason: 'DisplayName should return default');
      });
    });
  });
}
