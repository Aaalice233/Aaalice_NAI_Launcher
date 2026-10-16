import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

import '../../../helpers/exif_orientation_fixture.dart';

void main() {
  final target = Uint8List.fromList(
    img.encodePng(img.Image(width: 4, height: 6)),
  );

  Uint8List copiedExif(Uint8List source) => pngExifPayload(
    ImageMetadataContainerCodec.copySupportedMetadata(
      source: source,
      targetPng: target,
    ),
  )!;

  test('jpeg and webp exif are copied upright once the pixels are baked', () {
    for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final sources = {
        'jpeg': (
          orientedCameraJpeg(orientation: orientation),
          jpegExifPayload(orientedCameraJpeg(orientation: orientation)),
        ),
        'webp': (
          orientedCameraWebp(orientation: orientation),
          webpExifPayload(orientedCameraWebp(orientation: orientation)),
        ),
      };

      for (final MapEntry(key: name, value: (source, original))
          in sources.entries) {
        final reason = '$name $orientation';
        final copied = copiedExif(source);
        final ifd = readImageIfd(copied);

        expect(ifd.orientation, 1, reason: reason);
        expect(ifd.make, 'Aaalice Camera', reason: reason);
        expect(differsOnlyInOrientation(original, copied), isTrue);
      }
    }
  });

  test('png eXIf keeps its orientation because no decoder applies it', () {
    final exif = jpegExifPayload(orientedCameraJpeg(orientation: 6));

    expect(copiedExif(withPngExif(target, exif)), exif);
  });
}
