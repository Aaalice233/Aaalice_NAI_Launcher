import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/storage/tag_template_storage.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/data/models/prompt/tag_template.dart';
import 'package:nai_launcher/presentation/providers/tag_template_provider.dart';

// Fake storage implementation for testing
class FakeTagTemplateStorage implements TagTemplateStorage {
  final Map<String, TagTemplate> _storage = {};

  @override
  Box get _templatesBox => throw UnimplementedError();

  @override
  Future<void> saveTemplate(TagTemplate template) async {
    _storage[template.id] = template;
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    _storage.remove(templateId);
  }

  @override
  TagTemplate? getTemplate(String templateId) => _storage[templateId];

  @override
  List<TagTemplate> getTemplates() => _storage.values.toList();

  @override
  TagTemplate? getTemplateByName(String name) {
    for (final template in _storage.values) {
      if (template.name.toLowerCase() == name.toLowerCase()) {
        return template;
      }
    }
    return null;
  }

  @override
  bool hasTemplateName(String name) => getTemplateByName(name) != null;

  @override
  Future<void> clearTemplates() async => _storage.clear();

  @override
  int get templatesCount => _storage.length;

  @override
  Future<void> close() async {}

  @override
  Future<void> init() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TagTemplateNotifier', () {
    late FakeTagTemplateStorage fakeStorage;
    late ProviderContainer container;

    setUp(() {
      fakeStorage = FakeTagTemplateStorage();
      container = ProviderContainer(
        overrides: [
          tagTemplateStorageProvider.overrideWithValue(fakeStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('should initialize with empty state', () {
        final state = container.read(tagTemplateNotifierProvider);

        expect(
          state.templates,
          isEmpty,
          reason: 'Initial templates should be empty',
        );
        expect(
          state.isLoading,
          isFalse,
          reason: 'Should not be loading initially',
        );
        expect(
          state.error,
          isNull,
          reason: 'Should have no error initially',
        );
      });
    });

    group('saveTemplate', () {
      test('should create new template', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1'), PromptTag.create(text: 'tag2')];

        final result = await notifier.saveTemplate(
          name: 'Test Template',
          tags: tags,
          description: 'Test description',
        );

        expect(
          result,
          isNotNull,
          reason: 'Should return created template',
        );
        expect(
          result?.name,
          equals('Test Template'),
          reason: 'Template name should match',
        );
        expect(
          result?.tags.length,
          equals(2),
          reason: 'Should have 2 tags',
        );

        final state = container.read(tagTemplateNotifierProvider);
        expect(
          state.templates.length,
          equals(1),
          reason: 'State should have one template',
        );
      });

      test('should return null when name exists and overwrite=false', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        // Create first template
        await notifier.saveTemplate(name: 'Duplicate', tags: tags);

        // Try to create duplicate
        final result = await notifier.saveTemplate(
          name: 'Duplicate',
          tags: tags,
          overwrite: false,
        );

        expect(
          result,
          isNull,
          reason: 'Should return null for duplicate name',
        );
      });

      test('should overwrite when name exists and overwrite=true', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags1 = [PromptTag.create(text: 'tag1')];
        final tags2 = [PromptTag.create(text: 'tag2')];

        // Create first template
        await notifier.saveTemplate(name: 'My Template', tags: tags1);

        // Overwrite with new tags
        final result = await notifier.saveTemplate(
          name: 'My Template',
          tags: tags2,
          overwrite: true,
        );

        expect(
          result,
          isNotNull,
          reason: 'Should return updated template',
        );

        final state = container.read(tagTemplateNotifierProvider);
        expect(
          state.templates.length,
          equals(1),
          reason: 'Should still have only one template',
        );
        expect(
          state.templates.first.tags.first.text,
          equals('tag2'),
          reason: 'Tags should be updated',
        );
      });
    });

    group('deleteTemplate', () {
      test('should delete template', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        final template = await notifier.saveTemplate(
          name: 'To Delete',
          tags: tags,
        );

        expect(
          container.read(tagTemplateNotifierProvider).templates.length,
          equals(1),
          reason: 'Should have one template',
        );

        await notifier.deleteTemplate(template!.id);

        final state = container.read(tagTemplateNotifierProvider);
        expect(
          state.templates,
          isEmpty,
          reason: 'Template should be deleted',
        );
      });
    });

    group('getTemplate', () {
      test('should return template by ID', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        final template = await notifier.saveTemplate(
          name: 'Test',
          tags: tags,
        );

        final result = notifier.getTemplate(template!.id);

        expect(
          result,
          isNotNull,
          reason: 'Should return template',
        );
        expect(
          result?.name,
          equals('Test'),
          reason: 'Should return correct template',
        );
      });

      test('should return null for non-existent ID', () {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);

        final result = notifier.getTemplate('non-existent');

        expect(
          result,
          isNull,
          reason: 'Should return null',
        );
      });
    });

    group('getTemplateByName', () {
      test('should return template by name', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        await notifier.saveTemplate(name: 'My Template', tags: tags);

        final result = notifier.getTemplateByName('My Template');

        expect(
          result,
          isNotNull,
          reason: 'Should return template',
        );
        expect(
          result?.name,
          equals('My Template'),
          reason: 'Should return correct template',
        );
      });

      test('should be case-insensitive', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        await notifier.saveTemplate(name: 'My Template', tags: tags);

        final result = notifier.getTemplateByName('my template');

        expect(
          result,
          isNotNull,
          reason: 'Should find template case-insensitively',
        );
      });
    });

    group('hasTemplateName', () {
      test('should return true for existing name', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        await notifier.saveTemplate(name: 'Existing', tags: tags);

        expect(
          notifier.hasTemplateName('Existing'),
          isTrue,
          reason: 'Should return true for existing name',
        );
      });

      test('should return false for non-existing name', () {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);

        expect(
          notifier.hasTemplateName('Non Existing'),
          isFalse,
          reason: 'Should return false for non-existing name',
        );
      });
    });

    group('getTemplateTags', () {
      test('should return template tags', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [
          PromptTag.create(text: 'tag1'),
          PromptTag.create(text: 'tag2'),
          PromptTag.create(text: 'tag3'),
        ];

        final template = await notifier.saveTemplate(
          name: 'Test',
          tags: tags,
        );

        final result = notifier.getTemplateTags(template!.id);

        expect(
          result.length,
          equals(3),
          reason: 'Should return all tags',
        );
      });

      test('should return empty list for non-existent template', () {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);

        final result = notifier.getTemplateTags('non-existent');

        expect(
          result,
          isEmpty,
          reason: 'Should return empty list',
        );
      });
    });

    group('clearTemplates', () {
      test('should clear all templates', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        await notifier.saveTemplate(name: 'Template 1', tags: tags);
        await notifier.saveTemplate(name: 'Template 2', tags: tags);
        await notifier.saveTemplate(name: 'Template 3', tags: tags);

        expect(
          container.read(tagTemplateNotifierProvider).templates.length,
          equals(3),
          reason: 'Should have 3 templates',
        );

        await notifier.clearTemplates();

        final state = container.read(tagTemplateNotifierProvider);
        expect(
          state.templates,
          isEmpty,
          reason: 'All templates should be cleared',
        );
      });
    });

    group('refresh', () {
      test('should reload templates from storage', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);

        // Add template directly to storage
        final template = TagTemplate.create(
          name: 'Direct Add',
          tags: [PromptTag.create(text: 'tag1')],
        );
        await fakeStorage.saveTemplate(template);

        // Before refresh, state is empty
        expect(
          container.read(tagTemplateNotifierProvider).templates,
          isEmpty,
          reason: 'State should be empty before refresh',
        );

        // Refresh
        notifier.refresh();

        // After refresh, state should have the template
        final state = container.read(tagTemplateNotifierProvider);
        expect(
          state.templates.length,
          equals(1),
          reason: 'State should be updated after refresh',
        );
        expect(
          state.templates.first.name,
          equals('Direct Add'),
          reason: 'Should load template from storage',
        );
      });
    });

    group('Getters', () {
      test('templatesCount should return correct count', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        await notifier.saveTemplate(name: 'T1', tags: tags);
        await notifier.saveTemplate(name: 'T2', tags: tags);
        await notifier.saveTemplate(name: 'T3', tags: tags);

        expect(
          notifier.templatesCount,
          equals(3),
          reason: 'Count should match number of templates',
        );
      });
    });

    group('clearError', () {
      test('should clear error state', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);

        // Manually set an error state
        container.read(tagTemplateNotifierProvider.notifier).state =
            TagTemplateState(
          templates: [],
          error: 'Test error',
        );

        expect(
          container.read(tagTemplateNotifierProvider).error,
          isNotNull,
          reason: 'Error should be set',
        );

        notifier.clearError();

        expect(
          container.read(tagTemplateNotifierProvider).error,
          isNull,
          reason: 'Error should be cleared',
        );
      });
    });

    group('Convenience Providers', () {
      test('currentTemplates should return templates list', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        await notifier.saveTemplate(name: 'Template 1', tags: tags);

        final templates = container.read(currentTemplatesProvider);
        expect(
          templates.length,
          equals(1),
          reason: 'Should return current templates',
        );
        expect(
          templates.first.name,
          equals('Template 1'),
          reason: 'Should return correct template',
        );
      });

      test('isTemplateLoading should reflect loading state', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        // Add a template
        await notifier.saveTemplate(name: 'Test', tags: tags);

        // After operation completes, should not be loading
        expect(
          container.read(isTemplateLoadingProvider),
          isFalse,
          reason: 'Should not be loading after operation completes',
        );
      });

      test('templatesCount provider should return count', () async {
        final notifier = container.read(tagTemplateNotifierProvider.notifier);
        final tags = [PromptTag.create(text: 'tag1')];

        await notifier.saveTemplate(name: 'T1', tags: tags);
        await notifier.saveTemplate(name: 'T2', tags: tags);

        final count = container.read(templatesCountProvider);
        expect(
          count,
          equals(2),
          reason: 'Should return correct count',
        );
      });
    });
  });
}
