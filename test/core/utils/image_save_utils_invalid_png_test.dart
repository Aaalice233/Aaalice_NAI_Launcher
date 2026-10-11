import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Uint8List original;

  setUp(() async {
    final parent = Directory('tool/.tmp/invalid-png-save-tests');
    await parent.create(recursive: true);
    root = await parent.createTemp('case-');
    original = Uint8List.fromList(
      img.encodePng(img.Image(width: 128, height: 128, numChannels: 4)),
    );
  });

  tearDown(() => root.delete(recursive: true));

  for (final useStealth in [false, true]) {
    for (final usePrebuilt in [false, true]) {
      for (final damage in ['bad CRC', 'trailing byte', 'missing IEND']) {
        test('$damage does not overwrite a saved image '
            '(stealth=$useStealth, prebuilt=$usePrebuilt)', () async {
          final file = File(p.join(root.path, 'existing.png'));
          await file.writeAsBytes(original);
          final damaged = switch (damage) {
            'bad CRC' => Uint8List.fromList(
              original,
            )..[original.length - 1] ^= 1,
            'trailing byte' => Uint8List.fromList([...original, 0]),
            _ => Uint8List.sublistView(original, 0, original.length - 12),
          };
          final save = usePrebuilt
              ? ImageSaveUtils.saveWithPrebuiltMetadata(
                  imageBytes: damaged,
                  filePath: file.path,
                  metadata: const {'prompt': 'test', 'seed': 123},
                  useStealth: useStealth,
                )
              : ImageSaveUtils.saveImageWithMetadata(
                  imageBytes: damaged,
                  filePath: file.path,
                  params: const ImageParams(seed: 123),
                  actualSeed: 123,
                  preserveExistingNovelAiMetadata: false,
                  useStealth: useStealth,
                );
          await expectLater(save, throwsFormatException);
          expect(await file.readAsBytes(), orderedEquals(original));
        });
      }
    }
  }

  test(
    'raw metadata preservation still bypasses container rewriting',
    () async {
      final embedded = UnifiedMetadataParser.embedTextChunks(original, {
        'Comment': '{"prompt":"preserved","seed":456}',
      });
      final damaged = Uint8List.fromList(embedded)..[embedded.length - 1] ^= 1;
      final file = await ImageSaveUtils.saveImageWithMetadata(
        imageBytes: damaged,
        filePath: p.join(root.path, 'preserved.png'),
        params: const ImageParams(seed: 123),
        actualSeed: 123,
        preserveExistingNovelAiMetadata: true,
        useStealth: true,
      );
      expect(await file.readAsBytes(), orderedEquals(damaged));
    },
  );
}
