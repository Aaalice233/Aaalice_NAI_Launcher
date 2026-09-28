import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

void main() {
  test('copies a valid JPEG EXIF payload into a re-encoded PNG', () {
    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 4, height: 4)),
    );
    final source = _insertExif(jpeg, _minimalTiff());
    final target = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );

    final result = ImageMetadataContainerCodec.copySupportedMetadata(
      source: source,
      targetPng: target,
    );

    expect(latin1.decode(result, allowInvalid: true), contains('eXIf'));
  });

  test('rejects malformed EXIF instead of silently claiming preservation', () {
    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 4, height: 4)),
    );
    final source = _insertExif(jpeg, Uint8List.fromList(List.filled(10, 1)));
    final target = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );

    expect(
      () => ImageMetadataContainerCodec.copySupportedMetadata(
        source: source,
        targetPng: target,
      ),
      throwsFormatException,
    );
  });
}

Uint8List _insertExif(Uint8List jpeg, Uint8List tiff) {
  final payload = <int>[...ascii.encode('Exif\u0000\u0000'), ...tiff];
  final length = payload.length + 2;
  return Uint8List.fromList([
    ...jpeg.take(2),
    0xFF,
    0xE1,
    length >> 8,
    length & 0xFF,
    ...payload,
    ...jpeg.skip(2),
  ]);
}

Uint8List _minimalTiff() =>
    Uint8List.fromList([0x49, 0x49, 0x2A, 0, 8, 0, 0, 0, 0, 0]);
