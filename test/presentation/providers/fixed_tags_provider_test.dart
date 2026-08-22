import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_link.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';

void main() {
  group('FixedTagsState prompt type filtering', () {
    test('keeps existing positive prefix and suffix assembly unchanged', () {
      final state = FixedTagsState(
        entries: [
          FixedTagEntry.create(
            name: 'prefix',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
          ),
          FixedTagEntry.create(
            name: 'suffix',
            content: 'cinematic lighting',
            position: FixedTagPosition.suffix,
          ),
        ],
      );

      expect(
        state.applyToPrompt('1girl'),
        'masterpiece, 1girl, cinematic lighting',
      );
    });

    test('does not apply negative entries to the positive prompt', () {
      final negativeJson = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        position: FixedTagPosition.prefix,
      ).toJson()..['promptType'] = 'negative';
      final positiveEntry = FixedTagEntry.create(
        name: 'positive',
        content: 'masterpiece',
        position: FixedTagPosition.prefix,
      );

      final state = FixedTagsState(
        entries: [FixedTagEntry.fromJson(negativeJson), positiveEntry],
      );

      expect(state.applyToPrompt('1girl'), 'masterpiece, 1girl');
      expect(state.enabledPrefixes, [positiveEntry]);
      expect(state.enabledCount, 1);
    });

    test('applies negative entries using prefix body suffix assembly', () {
      final state = FixedTagsState(
        entries: [
          FixedTagEntry.create(
            name: 'positive',
            content: 'masterpiece',
            position: FixedTagPosition.prefix,
          ),
          FixedTagEntry.create(
            name: 'negative-prefix',
            content: 'bad hands',
            position: FixedTagPosition.prefix,
            promptType: FixedTagPromptType.negative,
            sortOrder: 0,
          ),
          FixedTagEntry.create(
            name: 'negative-suffix',
            content: 'text',
            position: FixedTagPosition.suffix,
            promptType: FixedTagPromptType.negative,
            sortOrder: 1,
          ),
        ],
      );

      expect(state.applyToNegativePrompt('lowres'), 'bad hands, lowres, text');
      expect(state.applyToPrompt('1girl'), 'masterpiece, 1girl');
      expect(state.negativeEnabledCount, 2);
    });

    test('tracks link endpoints and mismatch state', () {
      final positive = FixedTagEntry.create(
        name: 'positive',
        content: 'masterpiece',
      );
      final negative = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        promptType: FixedTagPromptType.negative,
        enabled: false,
      );
      final link = FixedTagLink.create(
        positiveEntryId: positive.id,
        negativeEntryId: negative.id,
      );

      final state = FixedTagsState(
        entries: [positive, negative],
        links: [link],
      );

      expect(state.linkedNegativesOf(positive.id), [negative]);
      expect(state.linkedPositivesOf(negative.id), [positive]);
      expect(state.isMismatched(link), isTrue);
      expect(FixedTagLink.fromJson(link.toJson()).negativeEntryId, negative.id);
    });
  });

  group('category grouping', () {
    test('positiveByCategory groups positive entries only', () {
      final negative = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        promptType: FixedTagPromptType.negative,
        categoryId: 'neg-cat',
      );
      final state = FixedTagsState(
        entries: [
          FixedTagEntry.create(
            name: 'artist1',
            content: 'artist:fuzichoco',
            categoryId: 'artist',
            sortOrder: 1,
          ),
          FixedTagEntry.create(
            name: 'artist2',
            content: 'artist:swav',
            categoryId: 'artist',
            sortOrder: 0,
          ),
          FixedTagEntry.create(
            name: 'quality',
            content: 'masterpiece',
            categoryId: 'quality',
          ),
          FixedTagEntry.create(name: 'uncategorized', content: 'tag'),
          negative,
        ],
      );

      final grouped = state.positiveByCategory;

      expect(grouped['artist']?.map((e) => e.name), ['artist2', 'artist1']);
      expect(grouped['quality'], hasLength(1));
      expect(grouped[null], hasLength(1));
      expect(grouped.containsKey('neg-cat'), isFalse);
    });

    test(
      'inferFixedTagCategories copies categoryId from linked library entries',
      () {
        final fixed = FixedTagEntry.create(
          name: 'linked',
          content: 'tag',
          sourceEntryId: 'lib-1',
        );
        final untouched = FixedTagEntry.create(
          name: 'already',
          content: 'tag',
          sourceEntryId: 'lib-2',
          categoryId: 'existing',
        );
        final inferred = inferFixedTagCategories(
          [fixed, untouched],
          [
            TagLibraryEntry(
              id: 'lib-1',
              name: 'linked',
              content: 'tag',
              categoryId: 'from-lib',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
            TagLibraryEntry(
              id: 'lib-2',
              name: 'already',
              content: 'tag',
              categoryId: 'should-not-overwrite',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
        );

        expect(inferred[0].categoryId, 'from-lib');
        expect(inferred[1].categoryId, 'existing');
      },
    );
  });

  group('library preview resolution', () {
    test('prefers sourceEntryId over matching content and name', () {
      final linked = TagLibraryEntry.create(name: 'linked', content: 'same');
      final duplicate = TagLibraryEntry.create(
        name: 'duplicate',
        content: 'same',
      );
      final fixed = FixedTagEntry.create(
        name: duplicate.name,
        content: duplicate.content,
        sourceEntryId: linked.id,
      );

      expect(resolveFixedTagLibraryEntry(fixed, [duplicate, linked]), linked);
    });

    test('restores legacy library association by exact content', () {
      final libraryEntry = TagLibraryEntry.create(
        name: 'library name',
        content: '1girl, blue eyes',
      );
      final legacyFixed = FixedTagEntry.create(
        name: 'old fixed name',
        content: ' 1girl, blue eyes ',
      );

      expect(
        resolveFixedTagLibraryEntry(legacyFixed, [libraryEntry]),
        libraryEntry,
      );
    });
  });

  group('library picker filtering', () {
    test('excludes library entries already linked from any fixed-tag list', () {
      final available = TagLibraryEntry.create(name: 'available', content: 'a');
      final linkedPositive = TagLibraryEntry.create(
        name: 'positive',
        content: 'b',
      );
      final linkedNegative = TagLibraryEntry.create(
        name: 'negative',
        content: 'c',
      );
      final manualFixedTag = FixedTagEntry.create(name: 'manual', content: 'd');

      final filtered = filterUnlinkedLibraryEntries(
        libraryEntries: [linkedPositive, available, linkedNegative],
        fixedEntries: [
          FixedTagEntry.create(
            name: linkedPositive.name,
            content: linkedPositive.content,
            sourceEntryId: linkedPositive.id,
          ),
          FixedTagEntry.create(
            name: linkedNegative.name,
            content: linkedNegative.content,
            promptType: FixedTagPromptType.negative,
            sourceEntryId: linkedNegative.id,
          ),
          manualFixedTag,
        ],
      );

      expect(filtered, [available]);
    });

    test('preserves the original list when no fixed tag is library-linked', () {
      final entries = [
        TagLibraryEntry.create(name: 'first', content: 'a'),
        TagLibraryEntry.create(name: 'second', content: 'b'),
      ];

      final filtered = filterUnlinkedLibraryEntries(
        libraryEntries: entries,
        fixedEntries: [FixedTagEntry.create(name: 'manual', content: 'a')],
      );

      expect(identical(filtered, entries), isTrue);
    });
  });

  group('filtered reorder', () {
    test('reorders only visible ids while preserving hidden entries', () {
      final a1 = FixedTagEntry.create(
        name: 'a1',
        content: 'a1',
        categoryId: 'a',
        sortOrder: 0,
      );
      final b = FixedTagEntry.create(
        name: 'b',
        content: 'b',
        categoryId: 'b',
        sortOrder: 1,
      );
      final a2 = FixedTagEntry.create(
        name: 'a2',
        content: 'a2',
        categoryId: 'a',
        sortOrder: 2,
      );

      final reordered = reorderFixedTagsWithinVisibleIds(
        entries: [a1, b, a2],
        promptType: FixedTagPromptType.positive,
        visibleIds: [a1.id, a2.id],
        oldIndex: 0,
        newIndex: 1,
      );

      expect(reordered.map((e) => e.id), [a2.id, b.id, a1.id]);
      expect(reordered.map((e) => e.sortOrder), [0, 1, 2]);
    });

    test('does not reorder when indexes are invalid', () {
      final entry = FixedTagEntry.create(name: 'a', content: 'a');

      final reordered = reorderFixedTagsWithinVisibleIds(
        entries: [entry],
        promptType: FixedTagPromptType.positive,
        visibleIds: [entry.id],
        oldIndex: 5,
        newIndex: 0,
      );

      expect(reordered, [entry]);
    });
  });
}
