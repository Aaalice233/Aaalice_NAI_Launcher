import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

void main() {
  final original = Uint8List.fromList(
    img.encodePng(img.Image(width: 128, height: 128, numChannels: 4)),
  );

  Uint8List damage(String kind) => switch (kind) {
    'bad CRC' => Uint8List.fromList(original)..[original.length - 1] ^= 1,
    'trailing byte' => Uint8List.fromList([...original, 0]),
    _ => Uint8List.sublistView(original, 0, original.length - 12),
  };

  for (final kind in ['bad CRC', 'trailing byte', 'missing IEND']) {
    for (final useStealth in [false, true]) {
      test('$kind fails the parameter rebuild (stealth=$useStealth)', () async {
        await expectLater(
          ImageSaveUtils.rebuildImageBytesWithMetadata(
            imageBytes: damage(kind),
            params: const ImageParams(seed: 123),
            actualSeed: 123,
            useStealth: useStealth,
          ),
          throwsFormatException,
        );
      });
    }

    test('$kind fails the result preparation', () async {
      await expectLater(
        ImageSaveUtils.prepareResultBytes(
          imageBytes: damage(kind),
          preserveOriginalBytes: false,
          metadata: const NaiImageMetadata(prompt: 'test', seed: 123),
        ),
        throwsFormatException,
      );
    });
  }

  test(
    'raw metadata preservation still bypasses container rewriting',
    () async {
      final embedded = UnifiedMetadataParser.embedTextChunks(original, {
        'Comment': '{"prompt":"preserved","seed":456}',
      });
      final damaged = Uint8List.fromList(embedded)..[embedded.length - 1] ^= 1;

      final result = await ImageSaveUtils.rebuildImageBytesWithMetadata(
        imageBytes: damaged,
        params: const ImageParams(seed: 123),
        actualSeed: 123,
        preserveExistingNovelAiMetadata: true,
        useStealth: true,
      );

      expect(result, orderedEquals(damaged));
    },
  );
}
