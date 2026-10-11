import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/cloud_sync/tag_library_thumbnail_compressor.dart';

import '../../helpers/grayscale_png_fixture.dart';
import '../../helpers/shared_compute_gate.dart';

void main() {
  const compressor = TagLibraryThumbnailCompressor();

  test('compresses behind the shared compute gate', () async {
    final source = img.Image(width: 1200, height: 800, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(220, 80, 40, 120));
    final bytes = Uint8List.fromList(img.encodePng(source));

    final thumbnail = await expectQueuedBehindSharedComputeGate(
      () => compressor.compress(Stream.value(bytes)),
    );

    final expected = TagLibraryThumbnailCompressor.compressBytes(bytes);
    expect(thumbnail.bytes, orderedEquals(expected.bytes));
    final decoded = img.decodeJpg(thumbnail.bytes)!;
    expect((decoded.width, decoded.height), (512, 341));
  });

  test('keeps single-channel grayscale gray in the jpeg thumbnail', () {
    final thumbnail = TagLibraryThumbnailCompressor.compressBytes(
      grayscalePng(width: 200, height: 100),
    );

    expectUniformGray(img.decodeJpg(thumbnail.bytes)!, 160);
  });

  test('flattens transparent gray-alpha onto the thumbnail background', () {
    final thumbnail = TagLibraryThumbnailCompressor.compressBytes(
      grayscalePng(width: 200, height: 100, alpha: 0),
    );

    expectUniformGray(img.decodeJpg(thumbnail.bytes)!, 32);
  });

  test('rejects undecodable sources from the isolate', () async {
    await expectLater(
      compressor.compress(Stream.value(Uint8List(64))),
      throwsA(isA<FormatException>()),
    );
  });
}
