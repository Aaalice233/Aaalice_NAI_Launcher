import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/comfyui_prompt_parser.dart';
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ComfyuiPromptParser pipe syntax', () {
    test('should parse single-line whitespace pipe character prompts', () {
      const prompt =
          "1girl, 2boys, indoor, luxurious living room, sunlight, heavy contrast, tense atmosphere, ntr, femdom, humiliation, neglect play, foot worship | 1girl, large breasts, petite, rabbit girl, rabbit ears, 1.2::white hair::, very long hair, gradient hair, purple hair, ahoge, one side up, hair between eyes, 1.2::white ear fluff::, purple inner ears, 1.2::aqua eyes::, 1.1::heart-shaped pupils::, 1.2::purple pupils::, 1.3::purple eyelashes::, purple hair bow, black choker, blonde neck bell, white frilled dress, detached sleeves, white pantyhose, high heels, sitting, crossing legs, smug, arrogant, looking down, contempt, target#licking foot | 1boy, tall, muscular, handsome, stylish suit, standing, hand in pocket, holding girl's waist, smiling, confident | 1boy, short, pathetic, kneeling, on all fours, slave, human furniture, crying, despair, looking up, source#licking foot";

      expect(ComfyuiPromptParser.isComfyuiMultiCharacter(prompt), isTrue);

      final result = ComfyuiPromptParser.tryParse(prompt);

      expect(result, isNotNull);
      expect(result!.globalPrompt, startsWith('1girl, 2boys, indoor'));
      expect(result.characters, hasLength(3));
      expect(result.characters[0].prompt, contains('target#licking foot'));
      expect(result.characters[1].prompt, contains("holding girl's waist"));
      expect(result.characters[2].prompt, contains('source#licking foot'));
      expect(result.characters[0].inferredGender, CharacterGender.female);
      expect(result.characters[1].inferredGender, CharacterGender.male);
      expect(result.characters[2].inferredGender, CharacterGender.male);
    });

    test('should not treat NovelAI dynamic tags as pipe character syntax', () {
      const prompt = '1girl, {red|blue} hair, looking at viewer';

      expect(ComfyuiPromptParser.isComfyuiMultiCharacter(prompt), isFalse);
      expect(ComfyuiPromptParser.tryParse(prompt), isNull);
    });
  });

  group('ImageSaveUtils metadata semantics', () {
    test(
      'should build metadata from request prompt and explicit preset flags',
      () {
        final params = ImageParams(
          prompt: '1girl, sunset',
          negativePrompt: 'bad hands',
          model: ImageModels.animeDiffusionV45Full,
          qualityToggle: true,
          ucPreset: UcPresets.toApiValue(UcPresetType.heavy),
        );

        final commentJson = ImageSaveUtils.buildCommentJson(
          params: params,
          actualSeed: 123,
          charCaptions: const [
            {
              'char_caption': 'blue dress',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
          ],
          charNegCaptions: const [
            {
              'char_caption': 'extra fingers',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
          ],
        );

        expect(commentJson['prompt'], equals('1girl, sunset'));
        expect(commentJson['uc'], equals('bad hands'));
        expect(commentJson['quality_toggle'], isTrue);
        expect(commentJson['uc_preset'], equals(0));
        expect(commentJson['model'], equals(ImageModels.animeDiffusionV45Full));
        expect(
          commentJson['v4_prompt']['caption']['base_caption'],
          equals('1girl, sunset'),
        );
        expect(
          commentJson['v4_prompt']['caption']['char_captions'],
          equals([
            {
              'char_caption': 'blue dress',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
          ]),
        );
        expect(
          commentJson['v4_negative_prompt']['caption']['base_caption'],
          equals('bad hands'),
        );
        expect(
          commentJson['v4_negative_prompt']['caption']['char_captions'],
          equals([
            {
              'char_caption': 'extra fingers',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
          ]),
        );

        final metadata = ImageSaveUtils.buildMetadata(
          commentJson: commentJson,
          params: params,
        );
        expect(metadata['Description'], equals('1girl, sunset'));
      },
    );

    test('should round-trip the V5 Full Light quality preset', () {
      const params = ImageParams(
        prompt:
            '1girl, transparent background, very aesthetic, amazing quality, no text',
        negativePrompt: 'bad hands',
        model: ImageModels.animeDiffusionV5Full,
        qualityToggle: true,
        qualityTier: QualityTags.lightTier,
        transparentBackground: true,
        ucPreset: UcPresets.noneApiValue,
      );

      final commentJson = ImageSaveUtils.buildCommentJson(
        params: params,
        actualSeed: 123,
      );
      final pngMetadata = ImageSaveUtils.buildMetadata(
        commentJson: commentJson,
        params: params,
      );
      final parsed = NaiImageMetadata.fromNaiComment(pngMetadata);
      final restored = ImageSaveUtils.rebuildParamsFromMetadata(parsed);

      expect(commentJson['tag_hint_qt'], 3);
      expect(pngMetadata['Source'], 'NovelAI Diffusion V5 657484A5');
      expect(parsed.model, ImageModels.animeDiffusionV5Full);
      expect(parsed.qualityToggle, isTrue);
      expect(parsed.qualityTier, QualityTags.lightTier);
      expect(parsed.transparentBackground, isTrue);
      expect(parsed.mainPrompt, '1girl');
      expect(restored, isNotNull);
      expect(restored!.model, ImageModels.animeDiffusionV5Full);
      expect(restored.qualityTier, QualityTags.lightTier);
      expect(restored.transparentBackground, isTrue);
    });

    test('should omit official tag hints for custom prompt presets', () {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        omitQualityTagHint: true,
        omitUcPresetTagHint: true,
      );

      final commentJson = ImageSaveUtils.buildCommentJson(
        params: params,
        actualSeed: 123,
      );

      expect(commentJson, isNot(contains('tag_hint_qt')));
      expect(commentJson, isNot(contains('tag_hint_uc_preset')));
    });

    test('should preserve the selected V5 alpha mode in metadata', () {
      const params = ImageParams(
        model: ImageModels.animeDiffusionV5Curated,
        straightAlpha: false,
      );

      final commentJson = ImageSaveUtils.buildCommentJson(
        params: params,
        actualSeed: 123,
      );

      expect(commentJson['straight_alpha'], isFalse);
    });

    test('should record the derived extra_noise_seed for img2img saves', () {
      final img2img = ImageParams(
        action: ImageGenerationAction.img2img,
        model: ImageModels.animeDiffusionV5Curated,
        sourceImage: Uint8List.fromList([1, 2, 3]),
      );
      const txt2img = ImageParams(model: ImageModels.animeDiffusionV5Curated);

      final img2imgComment = ImageSaveUtils.buildCommentJson(
        params: img2img,
        actualSeed: 123,
      );
      final txt2imgComment = ImageSaveUtils.buildCommentJson(
        params: txt2img,
        actualSeed: 123,
      );

      expect(img2imgComment['extra_noise_seed'], 122);
      expect(txt2imgComment, isNot(contains('extra_noise_seed')));
    });

    test(
      'should preserve embedded raw png metadata when saving generated bytes',
      () async {
        final png = img.Image(width: 2, height: 2);
        img.fill(png, color: img.ColorRgb8(255, 0, 0));
        var bytes = Uint8List.fromList(img.encodePng(png));

        const rawPrompt = 'artist:a,artist:b';
        const rawNegative = 'nsfw, lowres, bad hands';
        const rawSource = 'NovelAI Diffusion V4.5 4BDE2A90';
        final rawComment = <String, dynamic>{
          'prompt': rawPrompt,
          'uc': rawNegative,
          'seed': 123,
          'width': 2,
          'height': 2,
        };
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Comment',
          '{"prompt":"$rawPrompt","uc":"$rawNegative","seed":123,"width":2,"height":2}',
        );
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Description',
          rawPrompt,
        );
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Software',
          'NovelAI',
        );
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Source',
          rawSource,
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'image_save_utils_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final savedFile = await ImageSaveUtils.saveImageWithMetadata(
          imageBytes: bytes,
          filePath: '${tempDir.path}/saved.png',
          params: const ImageParams(
            prompt: 'different prompt',
            negativePrompt: 'different negative',
            model: ImageModels.animeDiffusionV45Full,
          ),
          actualSeed: 456,
        );

        final savedBytes = await savedFile.readAsBytes();
        expect(savedBytes, orderedEquals(bytes));
        final result = UnifiedMetadataParser.parseFromPng(savedBytes);

        expect(result.success, isTrue);
        expect(result.metadata, isNotNull);
        expect(result.metadata!.prompt, equals(rawPrompt));
        expect(result.metadata!.negativePrompt, equals(rawNegative));
        expect(result.metadata!.source, equals(rawSource));
        expect(result.metadata!.seed, equals(rawComment['seed']));
      },
    );

    test(
      'should not add app character captions to embedded png metadata',
      () async {
        final png = img.Image(width: 2, height: 2);
        img.fill(png, color: img.ColorRgb8(0, 255, 0));
        var bytes = Uint8List.fromList(img.encodePng(png));

        const rawPrompt = '1girl, living room';
        const rawNegative = 'bad hands';
        const rawSource = 'NovelAI Diffusion V4.5 4BDE2A90';
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Comment',
          '{"prompt":"$rawPrompt","uc":"$rawNegative","seed":123,"width":2,"height":2}',
        );
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Description',
          rawPrompt,
        );
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Software',
          'NovelAI',
        );
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'Source',
          rawSource,
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'image_save_utils_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final savedFile = await ImageSaveUtils.saveImageWithMetadata(
          imageBytes: bytes,
          filePath: '${tempDir.path}/saved_with_characters.png',
          params: const ImageParams(
            prompt: 'different prompt',
            negativePrompt: 'different negative',
            model: ImageModels.animeDiffusionV45Full,
          ),
          actualSeed: 456,
          charCaptions: const [
            {
              'char_caption': '1girl, rabbit girl, smug',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
            {
              'char_caption': '1boy, kneeling, despair',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
          ],
          charNegCaptions: const [
            {
              'char_caption': 'lowres',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
            {
              'char_caption': 'bad anatomy',
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            },
          ],
        );

        final result = UnifiedMetadataParser.parseFromPng(
          await savedFile.readAsBytes(),
        );

        expect(result.success, isTrue);
        expect(result.metadata, isNotNull);
        expect(result.metadata!.prompt, equals(rawPrompt));
        expect(result.metadata!.negativePrompt, equals(rawNegative));
        expect(result.metadata!.source, equals(rawSource));
        expect(result.metadata!.seed, equals(123));
        expect(result.metadata!.characterPrompts, isEmpty);
        expect(result.metadata!.characterNegativePrompts, isEmpty);
      },
    );

    test(
      'should replace ComfyUI workflow prompt with Unicode image metadata',
      () async {
        final png = img.Image(width: 2, height: 2);
        img.fill(png, color: img.ColorRgb8(12, 34, 56));
        var bytes = Uint8List.fromList(img.encodePng(png));
        final comfyPrompt = jsonEncode({
          '1': {
            'class_type': 'LoadImage',
            'inputs': {'image': 'launcher_input.png'},
          },
          '9': {
            'class_type': 'KSampler',
            'inputs': {
              'seed': 987654321,
              'steps': 1,
              'cfg': 1.0,
              'sampler_name': 'euler',
              'scheduler': 'simple',
            },
          },
        });
        bytes = UnifiedMetadataParser.embedTextChunkOnly(
          bytes,
          'prompt',
          comfyPrompt,
        );

        final rawResult = UnifiedMetadataParser.parseFromPng(bytes);
        expect(rawResult.success, isTrue);
        expect(rawResult.sourceFormat, 'ComfyUI');
        expect(rawResult.metadata!.prompt, isEmpty);
        expect(rawResult.metadata!.seed, 987654321);
        expect(rawResult.metadata!.sampler, 'euler');

        const positivePrompt = '1girl, <丰满>, 夜景';
        const negativePrompt = '低质量, bad hands';
        final rebuilt = await ImageSaveUtils.rebuildImageBytesWithMetadata(
          imageBytes: bytes,
          params: const ImageParams(
            prompt: positivePrompt,
            negativePrompt: negativePrompt,
            model: ImageModels.animeDiffusionV45Full,
            width: 2,
            height: 2,
          ),
          actualSeed: rawResult.metadata!.seed,
        );

        final textData = UnifiedMetadataParser.extractPngTextData(rebuilt);
        expect(textData['prompt'], comfyPrompt);
        expect(textData['Description'], startsWith(positivePrompt));
        expect(textData['Description'], contains('<丰满>'));
        expect(jsonDecode(textData['Comment']!)['prompt'], positivePrompt);
        expect(ImageSaveUtils.hasEmbeddedNovelAiMetadata(rebuilt), isTrue);

        final parsed = UnifiedMetadataParser.parseFromPng(rebuilt);
        expect(parsed.success, isTrue);
        expect(parsed.sourceFormat, 'NovelAI');
        expect(parsed.metadata!.prompt, positivePrompt);
        expect(parsed.metadata!.negativePrompt, negativePrompt);
        expect(parsed.metadata!.seed, 987654321);
        expect(parsed.metadata!.width, 2);
        expect(parsed.metadata!.height, 2);

        final decoded = img.decodePng(rebuilt);
        expect(decoded, isNotNull);
        expect(decoded!.getPixel(0, 0).r, 12);
        expect(decoded.getPixel(0, 0).g, 34);
        expect(decoded.getPixel(0, 0).b, 56);
      },
    );

    test(
      'should include structured positive and negative fixed tag metadata',
      () {
        const params = ImageParams(
          prompt: '1girl',
          negativePrompt: 'bad hands',
          model: ImageModels.animeDiffusionV45Full,
        );

        final commentJson = ImageSaveUtils.buildCommentJson(
          params: params,
          actualSeed: 123,
          fixedPrefixTags: const ['masterpiece'],
          fixedSuffixTags: const ['cinematic lighting'],
          fixedNegativePrefixTags: const ['lowres'],
          fixedNegativeSuffixTags: const ['text'],
        );

        expect(commentJson['fixed_prefix'], equals(['masterpiece']));
        expect(commentJson['fixed_suffix'], equals(['cinematic lighting']));
        expect(commentJson['fixed_negative_prefix'], equals(['lowres']));
        expect(commentJson['fixed_negative_suffix'], equals(['text']));
      },
    );

    test('writes an explicit empty fixed-tag snapshot', () {
      final commentJson = ImageSaveUtils.buildCommentJson(
        params: const ImageParams(prompt: 'subject'),
        actualSeed: 12,
        fixedTagUsageSnapshot: const FixedTagUsageSnapshot(),
      );

      expect(commentJson['aaalice_fixed_tags'], {
        'version': 1,
        'entries': <dynamic>[],
      });
      expect(commentJson['fixed_prefix'], isEmpty);
      expect(commentJson['fixed_suffix'], isEmpty);
      expect(commentJson['fixed_negative_prefix'], isEmpty);
      expect(commentJson['fixed_negative_suffix'], isEmpty);
    });

    test(
      'merges fixed-tag provenance without replacing official fields',
      () async {
        final png = img.Image(width: 2, height: 2);
        final base = await ImageSaveUtils.rebuildImageBytesWithMetadata(
          imageBytes: Uint8List.fromList(img.encodePng(png)),
          params: const ImageParams(
            prompt: 'original prompt',
            negativePrompt: 'original negative',
            width: 2,
            height: 2,
          ),
          actualSeed: 777,
        );
        const snapshot = FixedTagUsageSnapshot(
          entries: [
            FixedTagUsageEntry(
              fixedTagId: 'fixed-a',
              name: 'A',
              content: 'masterpiece',
              weight: 1,
              renderedContent: 'masterpiece',
              position: FixedTagPosition.prefix,
              promptType: FixedTagPromptType.positive,
              order: 0,
            ),
          ],
        );

        final merged = await ImageSaveUtils.mergeFixedTagUsageMetadata(
          imageBytes: base,
          snapshot: snapshot,
        );
        final metadata = UnifiedMetadataParser.parseFromPng(merged).metadata!;

        expect(metadata.prompt, 'original prompt');
        expect(metadata.negativePrompt, 'original negative');
        expect(metadata.seed, 777);
        expect(metadata.fixedPrefixTags, ['masterpiece']);
        expect(
          metadata.fixedTagUsageSnapshot?.entries.single.fixedTagId,
          'fixed-a',
        );
      },
    );
  });

  test('named dated saves sanitize conflicts and finish atomically', () async {
    final root = await Directory.systemTemp.createTemp('named-image-save');
    addTearDown(() => root.delete(recursive: true));
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final now = DateTime(2026, 8, 31, 12, 30);

    final first = await ImageSaveUtils.saveBytesToDatedPath(
      rootPath: root.path,
      bytes: bytes,
      preferredFileName: 'portrait:*_watermarked.png',
      now: now,
    );
    final second = await ImageSaveUtils.saveBytesToDatedPath(
      rootPath: root.path,
      bytes: bytes,
      preferredFileName: 'portrait:*_watermarked.png',
      now: now,
    );

    expect(p.basename(first), 'portrait___watermarked.png');
    expect(p.basename(second), 'portrait___watermarked-2.png');
    expect(await File(first).readAsBytes(), bytes);
    expect(await File(second).readAsBytes(), bytes);
  });
}
