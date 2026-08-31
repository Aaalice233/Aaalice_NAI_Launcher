import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_prompt_projection.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_output_filter_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_prompt_tag_settings_provider.dart';
import 'package:nai_launcher/presentation/services/gallery_prompt_projection_service.dart';

void main() {
  const service = GalleryPromptProjectionService();
  const outputFilter = OnlineGalleryOutputFilterSettings(tags: {'watermark'});
  const defaultPromptSettings = OnlineGalleryPromptTagSettings(
    categories: OnlineGalleryPromptTagSettings.defaultCategories,
  );

  group('GalleryPromptProjectionService source shapes', () {
    test('projects Danbooru categorized tags in configured order', () {
      const item = GalleryItem(
        id: 1,
        sourceId: GallerySourceId.danbooru,
        tags: ['solo', 'alice', 'series', 'watermark'],
        tagStringGeneral: 'solo watermark',
        tagStringCharacter: 'alice',
        tagStringCopyright: 'series',
      );

      final result = service.project(
        item: item,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, 'alice, series, solo');
      expect(result.negativePrompt, isEmpty);
      expect(result.copyText, 'alice, series, solo');
      expect(result.hasUsableOutput, isTrue);
    });

    test('projects Safebooru categorized tags when detail has no prompt', () {
      const item = GalleryItem(
        id: 2,
        sourceId: GallerySourceId.safebooru,
        tags: ['green_eyes', 'watermark'],
        tagStringGeneral: 'green_eyes watermark',
      );
      const detail = GalleryDetail(item: item, media: []);

      final result = service.project(
        item: item,
        detail: detail,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, 'green_eyes');
    });

    test('keeps unclassified Danbooru tags copyable as one field', () {
      const item = GalleryItem(
        id: 21,
        sourceId: GallerySourceId.danbooru,
        tags: ['solo', 'blue_hair'],
      );

      final result = service.project(
        item: item,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.copy.availableCategories, isEmpty);
      expect(result.copy.mainPositive, 'solo, blue_hair');
      expect(result.copyText, 'solo, blue_hair');
    });

    test('projects Gelbooru flat tags without categorized fields', () {
      const item = GalleryItem(
        id: 3,
        sourceId: GallerySourceId.gelbooru,
        tags: ['blue_hair', 'watermark', 'watermark_background'],
      );

      final result = service.project(
        item: item,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, 'blue_hair, watermark_background');
    });

    test('projects the current AI TAG media ahead of detail defaults', () {
      const firstMedia = GalleryMedia(
        id: 'first',
        prompt: 'first_prompt, watermark',
        negativePrompt: 'first negative',
      );
      const currentMedia = GalleryMedia(
        id: 'current',
        prompt: 'current_prompt, watermark',
        negativePrompt: '  current negative, watermark  ',
      );
      const item = GalleryItem(
        id: 4,
        sourceId: GallerySourceId.aiTag,
        tags: ['fallback'],
      );
      const detail = GalleryDetail(
        item: item,
        media: [firstMedia, currentMedia],
        prompt: 'detail_prompt',
        negativePrompt: 'detail negative',
      );

      final result = service.project(
        item: item,
        detail: detail,
        currentMedia: currentMedia,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, 'current_prompt');
      expect(result.negativePrompt, '  current negative, watermark  ');
      expect(result.copyText, 'current_prompt\n\ncurrent negative, watermark');
    });

    test('preserves AI TAG character negatives and positions', () {
      const item = GalleryItem(id: 12, sourceId: GallerySourceId.aiTag);
      const media = GalleryMedia(
        id: 'ai',
        prompt: 'main',
        negativePrompt: 'main bad',
        promptMetadata: NaiImageMetadata(
          characterPrompts: ['alice'],
          characterNegativePrompts: ['glasses'],
          characterInfos: [
            CharacterPromptInfo(
              prompt: 'alice',
              negativePrompt: 'glasses',
              centerX: 0.25,
              centerY: 0.75,
            ),
          ],
        ),
      );

      final result = service.project(
        item: item,
        currentMedia: media,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.characterPrompts.single.prompt, 'alice');
      expect(result.characterPrompts.single.negativePrompt, 'glasses');
      expect(result.characterPrompts.single.positionX, 0.25);
      expect(result.characterPrompts.single.positionY, 0.75);
    });

    test('projects QuickTagCloud item metadata without mutating it', () {
      final rawMetadata = <String, dynamic>{
        'prompt': 'masterpiece, watermark',
        'negativePrompt': 'lowres, watermark',
        'characterPrompts': [
          {
            'label': 'Alice',
            'prompt': 'alice, watermark',
            'negative': 'bad hands, watermark',
          },
        ],
      };
      final item = GalleryItem(
        id: 5,
        workId: 'book/entry',
        sourceId: GallerySourceId.quickTagCloud,
        rawSourceMetadata: rawMetadata,
      );

      final result = service.project(
        item: item,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, 'masterpiece');
      expect(result.negativePrompt, 'lowres, watermark');
      expect(result.characterPrompts, hasLength(1));
      expect(result.characterPrompts.single.prompt, 'alice');
      expect(
        result.characterPrompts.single.negativePrompt,
        'bad hands, watermark',
      );
      expect(
        result.copyText,
        'masterpiece | alice\n\nlowres, watermark | bad hands, watermark',
      );
      expect(rawMetadata['prompt'], 'masterpiece, watermark');
      expect((rawMetadata['characterPrompts'] as List).single, {
        'label': 'Alice',
        'prompt': 'alice, watermark',
        'negative': 'bad hands, watermark',
      });
    });
  });

  group('copy selection', () {
    test('selects Danbooru categories without changing generation policy', () {
      const item = GalleryItem(
        id: 10,
        sourceId: GallerySourceId.danbooru,
        tags: ['solo', 'alice', 'series', 'creator', 'watermark'],
        tagStringGeneral: 'solo watermark',
        tagStringCharacter: 'alice',
        tagStringCopyright: 'series',
        tagStringArtist: 'creator',
      );
      final result = service.project(
        item: item,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      final copied = result.copy.buildText(
        const GalleryPromptCopySelection(
          tagCategories: {
            GalleryPromptCopyCategory.artist,
            GalleryPromptCopyCategory.general,
          },
        ),
      );

      expect(copied, 'artist:creator, solo');
      expect(result.positivePrompt, 'alice, series, solo');
    });

    test('Gelbooru exposes one complete flat-tag selection', () {
      const item = GalleryItem(
        id: 11,
        sourceId: GallerySourceId.gelbooru,
        tags: ['blue_hair', 'watermark'],
      );
      final result = service.project(
        item: item,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.copy.availableCategories, isEmpty);
      expect(result.copy.hasMainPositive, isTrue);
      expect(
        result.copy.buildText(
          const GalleryPromptCopySelection(mainPositive: true),
        ),
        'blue_hair',
      );
    });

    test('structured copy keeps pure NovelAI character blocks', () {
      const item = GalleryItem(id: 13, sourceId: GallerySourceId.quickTagCloud);
      const detail = GalleryDetail(
        item: item,
        media: [],
        prompt: 'global',
        negativePrompt: 'global bad',
        characterPrompts: [
          GalleryCharacterPrompt(
            label: 'Alice',
            prompt: 'alice',
            negativePrompt: 'glasses',
          ),
        ],
      );
      final result = service.project(
        item: item,
        detail: detail,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(
        result.copy.buildText(
          const GalleryPromptCopySelection(
            mainPositive: true,
            mainNegative: true,
            characterPositiveIndices: {0},
            characterNegativeIndices: {0},
          ),
        ),
        'global | alice\n\nglobal bad | glasses',
      );
      expect(result.copyText, isNot(contains('positive:')));
      expect(result.copyText, isNot(contains('negative:')));
      expect(result.copyText, isNot(contains('metadata:')));
    });
  });

  group('prompt token filtering', () {
    test('never removes watermark as a substring', () {
      const item = GalleryItem(
        id: 6,
        sourceId: GallerySourceId.aiTag,
        tags: ['fallback'],
      );
      const media = GalleryMedia(
        id: 'media',
        prompt: 'watermark, watermark_background, no_watermark_style',
      );

      final result = service.project(
        item: item,
        currentMedia: media,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, 'watermark_background, no_watermark_style');
    });

    test('understands complete NovelAI wrappers and numeric weights', () {
      const item = GalleryItem(
        id: 7,
        sourceId: GallerySourceId.aiTag,
        tags: ['fallback'],
      );
      const media = GalleryMedia(
        id: 'media',
        prompt:
            '{watermark}, ((watermark)), [watermark], '
            '1.25::watermark::, 1.1::{watermark}::, '
            '{watermark, watermark_background}, safe',
      );

      final result = service.project(
        item: item,
        currentMedia: media,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, '{watermark, watermark_background}, safe');
    });

    test('filters character positive prompts but preserves negatives', () {
      const item = GalleryItem(id: 8, sourceId: GallerySourceId.quickTagCloud);
      const detail = GalleryDetail(
        item: item,
        media: [],
        characterPrompts: [
          GalleryCharacterPrompt(
            label: '',
            prompt: 'girl, (watermark), watermark_background',
            negativePrompt: 'watermark, malformed hands',
          ),
        ],
      );

      final result = service.project(
        item: item,
        detail: detail,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(
        result.characterPrompts.single.prompt,
        'girl, watermark_background',
      );
      expect(
        result.characterPrompts.single.negativePrompt,
        'watermark, malformed hands',
      );
      expect(result.hasUsableOutput, isTrue);
    });

    test('specialized positive actions keep their semantic subset', () {
      final result = service.projectPositivePrompt(
        '1.2::artist:target::, watermark',
        outputFilter: outputFilter,
      );

      expect(result, '1.2::artist:target::');
    });

    test('reports no usable output when all positive tokens are filtered', () {
      const item = GalleryItem(
        id: 9,
        sourceId: GallerySourceId.aiTag,
        tags: ['watermark'],
      );

      final result = service.project(
        item: item,
        promptTagSettings: defaultPromptSettings,
        outputFilter: outputFilter,
      );

      expect(result.positivePrompt, isEmpty);
      expect(result.copyText, isEmpty);
      expect(result.hasUsableOutput, isFalse);
    });
  });
}
