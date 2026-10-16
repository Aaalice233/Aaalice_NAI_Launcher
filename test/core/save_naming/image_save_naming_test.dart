import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/derivatives/derivative_registry.dart';
import 'package:nai_launcher/core/save_naming/image_save_naming.dart';
import 'package:nai_launcher/core/save_naming/save_name_context.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  final createdAt = DateTime(2026, 3, 4, 5, 6, 7);

  SaveNameContext context({NaiImageMetadata? metadata}) => SaveNameContext(
    createdAt: createdAt,
    metadata: metadata,
    imageId: 'image-1',
    index: 2,
  );

  group('presets', () {
    test('default rule reproduces the dated folder and time-seed name', () {
      final target = ImageSaveNaming.standard.resolve(
        context(metadata: const NaiImageMetadata(seed: 99)),
      );
      expect(target.relativeFileName, '2026-03-04/05-06-07-99.png');
      expect(
        SaveFolderPreset.match(ImageSaveNaming.defaultFolderTemplate),
        SaveFolderPreset.byDate,
      );
      expect(
        SaveFileNamePreset.match(ImageSaveNaming.defaultFileNameTemplate),
        SaveFileNamePreset.timeSeed,
      );
    });

    test('every preset renders a usable path', () {
      final sample = context(
        metadata: const NaiImageMetadata(prompt: '1girl, solo', seed: 5),
      );
      expect(
        {
          for (final preset in SaveFolderPreset.values)
            preset: ImageSaveNaming(
              folderTemplate: preset.template,
            ).folderSegments(sample),
        },
        {
          SaveFolderPreset.byDate: ['2026-03-04'],
          SaveFolderPreset.byMonth: ['2026-03'],
          SaveFolderPreset.byYearMonth: ['2026', '03'],
          SaveFolderPreset.none: <String>[],
        },
      );
      expect(
        {
          for (final preset in SaveFileNamePreset.values)
            preset: ImageSaveNaming(
              fileNameTemplate: preset.template,
            ).fileStem(sample),
        },
        {
          SaveFileNamePreset.timeSeed: '05-06-07-5',
          SaveFileNamePreset.dateTimeSeed: '2026-03-04_05-06-07-5',
          SaveFileNamePreset.promptSeed: '1girl, solo s-5',
        },
      );
    });

    test('custom templates match no preset', () {
      expect(SaveFolderPreset.match('{model}'), isNull);
      expect(SaveFileNamePreset.match('{prompt} s-{seed}'), isNull);
    });
  });

  group('fallbacks', () {
    test('an unreadable template falls back to the default rule', () {
      const naming = ImageSaveNaming(
        folderTemplate: '{future}',
        fileNameTemplate: '{newer|token}',
      );
      expect(
        naming.resolve(context()).relativeFileName,
        '2026-03-04/05-06-07.png',
      );
    });

    test('an empty file name falls back to the default name', () {
      const naming = ImageSaveNaming(fileNameTemplate: '{prompt}');
      expect(naming.fileStem(context()), '05-06-07');
    });

    test(
      'preferred file names keep their stem and only follow the folder rule',
      () {
        const naming = ImageSaveNaming(
          folderTemplate: '{year}',
          fileNameTemplate: '{prompt}',
        );
        final target = naming.resolve(
          context(),
          preferredFileName: 'sub/dir/source_watermarked.png',
        );
        expect(target.folders, ['2026']);
        expect(target.stem, 'source_watermarked');
      },
    );
  });

  group('fields', () {
    test('model name, type, index and id come from the image', () {
      final value =
          const ImageSaveNaming(
            fileNameTemplate: '{modelname}|{type}|{index}|{id}',
          ).fileStem(
            context(
              metadata: const NaiImageMetadata(
                model: ImageModels.animeDiffusionV45Full,
                isImg2Img: true,
              ),
            ),
          );
      expect(value, 'NAI Diffusion V4.5 (Full)_image2image_3_image-1');
    });

    test('generation type follows the official priority', () {
      String type(NaiImageMetadata metadata) => const ImageSaveNaming(
        fileNameTemplate: 't{type|pre:-}',
      ).fileStem(context(metadata: metadata));

      expect(type(const NaiImageMetadata()), 't');
      expect(
        type(
          const NaiImageMetadata(
            model: 'nai-diffusion-4-5-full-inpainting',
            isImg2Img: true,
          ),
        ),
        't-inpaint',
      );
      expect(
        type(
          const NaiImageMetadata(
            vibeReferences: [
              VibeReference(displayName: 'v', vibeEncoding: 'e'),
            ],
          ),
        ),
        't-vibe-transfer',
      );
    });

    test('negative seeds count as missing', () {
      expect(
        ImageSaveNaming.standard.fileStem(
          context(metadata: const NaiImageMetadata(seed: -1)),
        ),
        '05-06-07',
      );
    });
  });

  test('omitsDate flags time-based names without any date', () {
    expect(ImageSaveNaming.standard.omitsDate, isFalse);
    expect(
      ImageSaveNaming(folderTemplate: SaveFolderPreset.none.template).omitsDate,
      isTrue,
    );
    expect(
      ImageSaveNaming(
        folderTemplate: SaveFolderPreset.none.template,
        fileNameTemplate: SaveFileNamePreset.dateTimeSeed.template,
      ).omitsDate,
      isFalse,
    );
    expect(
      ImageSaveNaming(
        folderTemplate: SaveFolderPreset.none.template,
        fileNameTemplate: SaveFileNamePreset.promptSeed.template,
      ).omitsDate,
      isFalse,
    );
  });

  test('derivative names shorten the source but keep the suffix', () {
    final name = DerivativeKind.watermark.outputFileName('${'字' * 120}.png');
    expect(name, endsWith('_watermarked.png'));
    expect(DerivativeKind.watermark.matchesFileName(name), isTrue);
    expect(
      DerivativeKind.mosaic.outputFileName('...png'),
      'image_redacted.png',
    );
  });
}
