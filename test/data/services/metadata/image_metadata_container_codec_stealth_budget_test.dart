import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

void main() {
  group('stealth decode budget', () {
    test('accepts a header at the pixel limit without any pixel data', () {
      expect(
        ImageMetadataContainerCodec.stealthDecoderFor(
          _headerOnlyPng(4096, 4096),
        ),
        isNotNull,
      );
    });

    test('rejects an over-limit header before decoding pixels', () {
      expect(
        ImageMetadataContainerCodec.stealthDecoderFor(
          _headerOnlyPng(4097, 4096),
        ),
        isNull,
      );
      expect(
        ImageMetadataContainerCodec.extractStealthMetadataText(
          _headerOnlyPng(16384, 16384),
        ),
        isNull,
      );
    });

    test('rejects bytes that are not an image', () {
      expect(
        ImageMetadataContainerCodec.stealthDecoderFor(Uint8List(32)),
        isNull,
      );
    });
  });
}

Uint8List _headerOnlyPng(int width, int height) {
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ..._chunk('IHDR', header.buffer.asUint8List()),
    ..._chunk('IEND', Uint8List(0)),
  ]);
}

List<int> _chunk(String type, Uint8List data) {
  final typeAndData = Uint8List.fromList([...type.codeUnits, ...data]);
  return [
    ...(ByteData(4)..setUint32(0, data.length)).buffer.asUint8List(),
    ...typeAndData,
    ...(ByteData(4)..setUint32(0, getCrc32(typeAndData))).buffer.asUint8List(),
  ];
}
