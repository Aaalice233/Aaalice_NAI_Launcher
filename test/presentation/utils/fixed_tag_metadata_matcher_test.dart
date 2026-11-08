import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
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

  test('quality tags at the tail do not hide an inferred fixed suffix', () {
    final suffix = FixedTagEntry.create(
      name: 'style',
      content: 'artist:foo',
      position: FixedTagPosition.suffix,
    );

    final result = matchMetadataFixedTags(
      metadata: const NaiImageMetadata(
        prompt: '1girl, artist:foo, very aesthetic, masterpiece',
        qualityTags: ['very aesthetic', 'masterpiece'],
      ),
      positiveEntries: [suffix],
      negativeEntries: const [],
    );

    expect(result.fixedSuffixTags, equals(['artist:foo']));
    expect(result.mainPrompt, '1girl');
  });

  test(
    'transparent background marker does not hide an inferred fixed suffix',
    () {
      final suffix = FixedTagEntry.create(
        name: 'style',
        content: 'artist:foo',
        position: FixedTagPosition.suffix,
      );

      final result = matchMetadataFixedTags(
        metadata: const NaiImageMetadata(
          prompt: '1girl, artist:foo, transparent background',
          transparentBackground: true,
        ),
        positiveEntries: [suffix],
        negativeEntries: const [],
      );

      expect(result.fixedSuffixTags, equals(['artist:foo']));
    },
  );

  test('an empty quality tag list still lets the marker be skipped', () {
    final suffix = FixedTagEntry.create(
      name: 'style',
      content: 'artist:foo',
      position: FixedTagPosition.suffix,
    );

    final result = matchMetadataFixedTags(
      metadata: const NaiImageMetadata(
        prompt: '1girl, artist:foo, transparent background',
        qualityTags: [],
        transparentBackground: true,
      ),
      positiveEntries: [suffix],
      negativeEntries: const [],
    );

    expect(result.fixedSuffixTags, equals(['artist:foo']));
  });

  test('a tail that is not a quality tag still blocks the suffix', () {
    final suffix = FixedTagEntry.create(
      name: 'style',
      content: 'artist:foo',
      position: FixedTagPosition.suffix,
    );

    final result = matchMetadataFixedTags(
      metadata: const NaiImageMetadata(
        prompt: '1girl, artist:foo, outdoors',
        qualityTags: ['very aesthetic'],
      ),
      positiveEntries: [suffix],
      negativeEntries: const [],
    );

    expect(result.fixedSuffixTags, isEmpty);
  });

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

  test('infers the negative prefix right after the UC preset', () {
    const model = ImageModels.animeDiffusionV45Full;
    final heavy = UcPresets.getPresetContent(model, UcPresetType.heavy);
    final prefix = FixedTagEntry.create(
      name: 'prefix',
      content: 'bad hands',
      promptType: FixedTagPromptType.negative,
    );

    final result = matchMetadataFixedTags(
      metadata: NaiImageMetadata(
        negativePrompt: '$heavy, bad hands, watermark',
        model: model,
        ucPreset: UcPresets.heavyApiValue,
      ),
      positiveEntries: const [],
      negativeEntries: [prefix],
    );

    expect(result.fixedNegativePrefixTags, ['bad hands']);
    expect(result.mainNegativePrompt, 'watermark');
  });

  test('highlights fixed tags after the leading UC preset tags', () {
    expect(
      fixedPromptTagIndexes(
        promptTags: const ['lowres', 'bad hands', 'watermark', 'bad hands'],
        prefixEntries: const ['bad hands'],
        suffixEntries: const ['bad hands'],
        leadingTagCount: 1,
      ),
      {1, 3},
    );
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

  test('infers the leading UC preset when metadata does not record it '
      'so a negative fixed prefix still aligns', () {
    final preset = UcPresets.getPresetContent(
      ImageModels.animeDiffusionV45Full,
      UcPresetType.heavy,
    );
    final negativeFixed = FixedTagEntry.create(
      name: 'neg',
      content: '1.3::outside_border, frame, border::, earrings',
      promptType: FixedTagPromptType.negative,
    );
    final positiveFixed = FixedTagEntry.create(
      name: 'style',
      content: '1.4::artist:foo::, 2::detailed_background, high_contrast::',
    );

    final result = matchMetadataFixedTags(
      metadata: NaiImageMetadata(
        prompt:
            '1.4::artist:foo::, 2::detailed_background, high_contrast::, '
            'hot spring',
        negativePrompt:
            '$preset, 1.3::outside_border, frame, border::, '
            'earrings, extra scene negative',
      ),
      positiveEntries: [positiveFixed],
      negativeEntries: [negativeFixed],
    );

    expect(result.ucPreset, isNull);
    expect(result.fixedPrefixTags, hasLength(1));
    expect(result.fixedNegativePrefixTags, hasLength(1));
    expect(result.mainPrompt, 'hot spring');
    expect(result.mainNegativePrompt, 'extra scene negative');
  });

  test('a negative without a known leading preset is left untouched', () {
    final result = const NaiImageMetadata(
      negativePrompt: 'lowres, my own negative',
    ).negativePresetSplit;

    expect(result.preset, isEmpty);
    expect(result.body, 'lowres, my own negative');
  });

  test('treats CRLF, underscores and spaces as the same separator', () {
    // Windows 下保存的固定词带 CRLF 且用下划线；别的渠道的图是 LF，
    // 并把加权组里的下划线改成空格。
    final positive = FixedTagEntry.create(
      name: 'p',
      content:
          'artist:foo, year:2025\r\n\r\nmasterpiece, 2::detailed_background',
    );
    final negative = FixedTagEntry.create(
      name: 'n',
      content: '1.2::protruding_muzzle, snout::\r\n1.05::beak-like_nose::',
      promptType: FixedTagPromptType.negative,
    );

    final result = matchMetadataFixedTags(
      metadata: const NaiImageMetadata(
        prompt:
            'artist:foo,year:2025\n\nmasterpiece, 2::detailed background, '
            'solo, hot spring',
        negativePrompt:
            '1.2::protruding muzzle, snout::\n1.05::beak-like nose::, extra',
      ),
      positiveEntries: [positive],
      negativeEntries: [negative],
    );

    expect(result.fixedPrefixTags, hasLength(1));
    expect(result.fixedNegativePrefixTags, hasLength(1));
  });
}
