import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/novelai_vibe_codec.dart';
import 'package:nai_launcher/core/utils/vibe_export_utils.dart';
import 'package:nai_launcher/core/utils/vibe_file_parser.dart';
import 'package:nai_launcher/core/utils/vibe_image_embedder.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VibeExportUtils', () {
    test(
      'collectImageCandidates should deduplicate identical carrier images',
      () {
        final pngBytes = _createInMemoryPngBytes();
        final entry =
            VibeLibraryEntry.create(
              name: 'Test',
              vibeDisplayName: 'Test Vibe',
              vibeEncoding: 'dGVzdA==',
            ).copyWith(
              rawImageData: pngBytes,
              vibeThumbnail: pngBytes,
              thumbnail: pngBytes,
            );

        final candidates = VibeExportUtils.collectImageCandidates(entry);

        expect(candidates, hasLength(1));
        expect(candidates.first.label, equals('原始图片'));
      },
    );

    test(
      'buildEmbeddedPngExportPlans should use first candidate and skip entries without images',
      () {
        final firstCarrier = _createInMemoryPngBytes();
        final secondCarrier = Uint8List.fromList(
          List<int>.generate(16, (index) => index + 1),
        );
        final entries = [
          VibeLibraryEntry.create(
            name: 'With Image',
            vibeDisplayName: 'With Image',
            vibeEncoding: 'ZW5jb2RlZA==',
          ).copyWith(rawImageData: firstCarrier, vibeThumbnail: secondCarrier),
          VibeLibraryEntry.create(
            name: 'No Image',
            vibeDisplayName: 'No Image',
            vibeEncoding: 'bm8taW1hZ2U=',
          ),
        ];

        final plans = VibeExportUtils.buildEmbeddedPngExportPlans(entries);

        expect(plans, hasLength(1));
        expect(plans.single.entryId, equals(entries.first.id));
        expect(plans.single.fileName, equals('With Image_vibe.png'));
        expect(plans.single.carrierImageBytes, same(firstCarrier));
        expect(plans.single.vibes, hasLength(1));
        expect(plans.single.vibes.single.displayName, equals('With Image'));
      },
    );

    test(
      'buildEmbeddedPngBytes should embed all selected vibes into carrier image',
      () async {
        final pngBytes = _createInMemoryPngBytes();
        const first = VibeReference(
          displayName: 'First',
          vibeEncoding: 'Zmlyc3Q=',
        );
        const second = VibeReference(
          displayName: 'Second',
          vibeEncoding: 'c2Vjb25k',
        );

        final embeddedBytes = await VibeExportUtils.buildEmbeddedPngBytes(
          vibes: const [first, second],
          carrierImageBytes: pngBytes,
        );
        final extracted = await VibeImageEmbedder.extractVibeFromImage(
          embeddedBytes,
        );

        expect(extracted.isBundle, isTrue);
        expect(extracted.vibes, hasLength(2));
        expect(
          extracted.vibes.map((item) => item.displayName),
          containsAll(<String>['First', 'Second']),
        );
      },
    );

    test('exportToNaiv4Vibe writes into a provided directory once', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_export_utils_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      const vibe = VibeReference(
        displayName: 'Unsafe:Name',
        vibeEncoding: 'encoded-payload',
        sourceType: VibeSourceType.naiv4vibe,
      );

      final firstPath = await VibeExportUtils.exportToNaiv4Vibe(
        vibe,
        outputDirectory: tempDir.path,
      );
      final secondPath = await VibeExportUtils.exportToNaiv4Vibe(
        vibe,
        outputDirectory: tempDir.path,
      );

      expect(firstPath, isNotNull);
      expect(secondPath, isNotNull);
      expect(p.basename(firstPath!), 'Unsafe_Name.naiv4vibe');
      expect(p.basename(secondPath!), 'Unsafe_Name (1).naiv4vibe');
      expect(await File(firstPath).exists(), isTrue);
      expect(await File(secondPath).exists(), isTrue);
      final exported =
          jsonDecode(await File(firstPath).readAsString())
              as Map<String, dynamic>;
      expect(NovelAiVibeCodec.validateSingleMap(exported), isTrue);
      expect(
        exported['encodings']['v4full']['unknown']['encoding'],
        'encoded-payload',
      );
    });

    test('exportToNaiv4VibeBundle writes into a provided directory', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_export_bundle_utils_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      const vibe = VibeReference(
        displayName: 'Bundle Vibe',
        vibeEncoding: 'encoded-payload',
        sourceType: VibeSourceType.naiv4vibe,
      );

      final path = await VibeExportUtils.exportToNaiv4VibeBundle(
        [vibe],
        'Bundle:Name',
        outputDirectory: tempDir.path,
      );

      expect(path, isNotNull);
      expect(p.basename(path!), 'Bundle_Name.naiv4vibebundle');
      expect(await File(path).exists(), isTrue);
      final exported =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      expect(NovelAiVibeCodec.validateBundleMap(exported), isTrue);
    });

    test('exportToNaiv4VibeBundle preserves per-vibe info extracted', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'vibe_export_bundle_params_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      const vibes = [
        VibeReference(
          displayName: 'First',
          vibeEncoding: 'encoded-first',
          strength: 0.2,
          infoExtracted: 0.3,
          encodingModel: ImageModels.animeDiffusionV4Full,
          sourceType: VibeSourceType.naiv4vibe,
        ),
        VibeReference(
          displayName: 'Second',
          vibeEncoding: 'encoded-second',
          strength: 0.4,
          infoExtracted: 0.8,
          encodingModel: ImageModels.animeDiffusionV45Full,
          sourceType: VibeSourceType.naiv4vibe,
        ),
      ];

      final path = await VibeExportUtils.exportToNaiv4VibeBundle(
        vibes,
        'Bundle Params',
        outputDirectory: tempDir.path,
      );
      expect(path, isNotNull);

      final parsed = await VibeFileParser.fromBundle(
        p.basename(path!),
        await File(path).readAsBytes(),
      );

      expect(parsed.map((v) => v.strength), [0.2, 0.4]);
      expect(parsed.map((v) => v.infoExtracted), [0.3, 0.8]);
      expect(parsed.map((v) => v.encodingModel), [
        ImageModels.animeDiffusionV4Full,
        ImageModels.animeDiffusionV45Full,
      ]);
    });
  });
}

Uint8List _createInMemoryPngBytes() {
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
  return Uint8List.fromList(base64Decode(base64Png));
}
