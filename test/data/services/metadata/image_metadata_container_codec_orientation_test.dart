import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/exif_orientation_metadata.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

import '../../../helpers/exif_orientation_fixture.dart';

void main() {
  final target = Uint8List.fromList(
    img.encodePng(img.Image(width: 4, height: 6)),
  );

  Uint8List copiedExif(Uint8List source, SourcePixelDecoder? decodedBy) =>
      pngExifPayload(
        ImageMetadataContainerCodec.copySupportedMetadata(
          source: source,
          targetPng: target,
          decodedBy: decodedBy,
        ),
      )!;

  test('jpeg exif is copied upright once any decoder baked it', () {
    final jpeg = orientedCameraJpeg(orientation: 6);
    final original = jpegExifPayload(jpeg);

    for (final decoder in SourcePixelDecoder.values) {
      final copied = copiedExif(jpeg, decoder);
      final ifd = readImageIfd(copied);

      expect(ifd.orientation, 1, reason: decoder.name);
      expect(ifd.make, 'Aaalice Camera', reason: decoder.name);
      expect(ifd.model, 'Orientation Probe', reason: decoder.name);
      expect(
        differsOnlyInOrientation(original, copied),
        isTrue,
        reason: decoder.name,
      );
    }
  });

  test('exif stays byte for byte when the pixels were not decoded from it', () {
    final jpeg = orientedCameraJpeg(orientation: 6);

    expect(copiedExif(jpeg, null), jpegExifPayload(jpeg));
  });

  test('webp orientation is reset only where flutter baked it', () {
    final webp = orientedCameraWebp(orientation: 6);

    final fromFlutter = readImageIfd(
      copiedExif(webp, SourcePixelDecoder.flutterEngine),
    );
    final fromImagePackage = readImageIfd(
      copiedExif(webp, SourcePixelDecoder.imagePackage),
    );

    expect(fromFlutter.orientation, 1);
    expect(fromFlutter.make, 'Aaalice Camera');
    expect(fromImagePackage.orientation, 6);
  });

  test('png eXIf keeps its orientation because no decoder applies it', () {
    final png = ImageMetadataContainerCodec.copySupportedMetadata(
      source: orientedCameraJpeg(orientation: 6),
      targetPng: target,
    );
    final original = pngExifPayload(png)!;

    for (final decoder in SourcePixelDecoder.values) {
      expect(copiedExif(png, decoder), original, reason: decoder.name);
    }
  });
}
