import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/vibe_image_embedder.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  group('VibeImageEmbedder', () {
    test('embedVibeToImage should produce extractable vibe metadata', () async {
      final imageBytes = _createInMemoryPngBytes();
      const reference = VibeReference(
        displayName: 'Test Vibe',
        vibeEncoding: 'YmFzZTY0X2VuY29kaW5n',
        strength: 0.75,
        infoExtracted: 0.85,
        sourceType: VibeSourceType.naiv4vibe,
      );

      final embeddedBytes = await VibeImageEmbedder.embedVibeToImage(
        imageBytes,
        reference,
      );

      expect(embeddedBytes.length, greaterThan(imageBytes.length));

      final extracted = await VibeImageEmbedder.extractVibeFromImage(
        embeddedBytes,
      );
      expect(extracted.isBundle, isTrue);
      expect(extracted.vibes, hasLength(1));
      expect(
        extracted.vibes.single,
        reference.copyWith(
          encodingModel: ImageModels.animeDiffusionV4Full,
          sourceType: VibeSourceType.png,
        ),
      );
    });

    test(
      'embedVibeToImage and extractVibeFromImage should keep data unchanged in round trip',
      () async {
        final imageBytes = _createInMemoryPngBytes();
        const original = VibeReference(
          displayName: 'Round Trip Vibe',
          vibeEncoding: 'cm91bmRfdHJpcF9lbmNvZGluZw==',
          strength: 0.61,
          infoExtracted: 0.92,
          sourceType: VibeSourceType.png,
        );

        final embeddedBytes = await VibeImageEmbedder.embedVibeToImage(
          imageBytes,
          original,
        );
        final extracted = await VibeImageEmbedder.extractVibeFromImage(
          embeddedBytes,
        );

        expect(extracted.isBundle, isTrue);
        expect(extracted.vibes, [
          original.copyWith(encodingModel: ImageModels.animeDiffusionV4Full),
        ]);
      },
    );

    test('embedded image Vibe preserves its raw image and model', () async {
      final carrier = _createInMemoryPngBytes();
      final rawImage = Uint8List.fromList(const [1, 2, 3, 4]);
      final original = VibeReference(
        displayName: 'Image Vibe',
        vibeEncoding: 'image-vibe-encoding',
        rawImageData: rawImage,
        encodingModel: ImageModels.animeDiffusionV45Full,
        sourceType: VibeSourceType.naiv4vibe,
      );

      final embeddedBytes = await VibeImageEmbedder.embedVibeToImage(
        carrier,
        original,
      );
      final extracted = await VibeImageEmbedder.extractVibeFromImage(
        embeddedBytes,
      );

      expect(extracted.vibes.single.rawImageData, rawImage);
      expect(
        extracted.vibes.single.encodingModel,
        ImageModels.animeDiffusionV45Full,
      );
    });

    test('embedVibeToImage should throw on non-PNG bytes', () async {
      final nonPngBytes = Uint8List.fromList(utf8.encode('not a png file'));
      const reference = VibeReference(
        displayName: 'Invalid Input',
        vibeEncoding: 'dGVzdA==',
      );

      await expectLater(
        VibeImageEmbedder.embedVibeToImage(nonPngBytes, reference),
        throwsA(isA<InvalidImageFormatException>()),
      );
    });

    test('extractVibeFromImage should throw on non-PNG bytes', () async {
      final nonPngBytes = Uint8List.fromList(utf8.encode('not a png file'));

      await expectLater(
        VibeImageEmbedder.extractVibeFromImage(nonPngBytes),
        throwsA(isA<InvalidImageFormatException>()),
      );
    });

    test(
      'extractVibeFromImage should throw when PNG has no vibe data',
      () async {
        final imageBytes = _createInMemoryPngBytes();

        await expectLater(
          VibeImageEmbedder.extractVibeFromImage(imageBytes),
          throwsA(isA<NoVibeDataException>()),
        );
      },
    );
  });
}

Uint8List _createInMemoryPngBytes() {
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
  return Uint8List.fromList(base64Decode(base64Png));
}
