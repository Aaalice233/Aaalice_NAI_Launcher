import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/presentation/utils/fixed_tag_metadata_matcher.dart';

void main() {
  test(
    'matches legacy positive and negative prompts against the current library',
    () {
      final positivePrefix = FixedTagEntry.create(
        name: 'private',
        content: 'private prefix, artist name',
      );
      final positiveSuffix = FixedTagEntry.create(
        name: 'style',
        content: 'cinematic lighting',
        position: FixedTagPosition.suffix,
      );
      final negativePrefix = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
      );

      final result = matchMetadataFixedTags(
        metadata: const NaiImageMetadata(
          prompt:
              '{private prefix}, 1.2::artist name::, 1girl, cinematic lighting',
          negativePrompt: 'bad hands, lowres',
        ),
        positiveEntries: [positivePrefix, positiveSuffix],
        negativeEntries: [negativePrefix],
      );

      expect(
        result.fixedPrefixTags,
        equals(['{private prefix}, 1.2::artist name::']),
      );
      expect(result.fixedSuffixTags, equals(['cinematic lighting']));
      expect(result.fixedNegativePrefixTags, equals(['bad hands']));
      expect(result.fixedNegativeSuffixTags, isEmpty);
    },
  );

  test('matches a weighted comma group as one complete fixed fragment', () {
    const fragment = '{{{masterpiece, best_quality, year_2024}}}';
    final result = matchMetadataFixedTags(
      metadata: const NaiImageMetadata(prompt: '$fragment, 1girl, $fragment'),
      positiveEntries: [
        FixedTagEntry.create(name: 'prefix', content: fragment),
        FixedTagEntry.create(
          name: 'suffix',
          content: fragment,
          position: FixedTagPosition.suffix,
        ),
      ],
      negativeEntries: const [],
    );

    expect(result.fixedPrefixTags, [fragment]);
    expect(result.fixedSuffixTags, [fragment]);
  });

  test('explicit recorded fields prevent additional inference', () {
    final libraryEntry = FixedTagEntry.create(
      name: 'new',
      content: 'new library value',
    );

    final result = matchMetadataFixedTags(
      metadata: const NaiImageMetadata(
        prompt: 'recorded value, new library value, 1girl',
        fixedPrefixTags: ['recorded value'],
      ),
      positiveEntries: [libraryEntry],
      negativeEntries: const [],
    );

    expect(result.fixedPrefixTags, equals(['recorded value']));
  });

  test('does not infer fixed tags from the middle of a negative prompt', () {
    final prefix = FixedTagEntry.create(
      name: 'prefix',
      content: 'lowres',
      promptType: FixedTagPromptType.negative,
    );
    final suffix = FixedTagEntry.create(
      name: 'suffix',
      content: 'bad quality',
      position: FixedTagPosition.suffix,
      promptType: FixedTagPromptType.negative,
    );

    final result = matchMetadataFixedTags(
      metadata: const NaiImageMetadata(
        negativePrompt: 'nsfw, lowres, bad quality, watermark',
      ),
      positiveEntries: const [],
      negativeEntries: [prefix, suffix],
    );

    expect(result.fixedNegativePrefixTags, isEmpty);
    expect(result.fixedNegativeSuffixTags, isEmpty);
  });

  test('marks only boundary occurrences of duplicate fixed tags', () {
    expect(
      fixedPromptTagIndexes(
        promptTags: const ['lowres', 'nsfw', 'lowres'],
        prefixEntries: const ['lowres'],
        suffixEntries: const [],
      ),
      {0},
    );
    expect(
      fixedPromptTagIndexes(
        promptTags: const ['lowres', 'nsfw', 'lowres'],
        prefixEntries: const [],
        suffixEntries: const ['lowres'],
      ),
      {2},
    );
  });
}
