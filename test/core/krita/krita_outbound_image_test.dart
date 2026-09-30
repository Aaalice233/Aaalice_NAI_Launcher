import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/krita/krita_outbound_image.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';

void main() {
  group('KritaOutboundImage', () {
    test('keeps png bytes and normalizes extension', () {
      final png = _png();

      final prepared = KritaOutboundImage.prepare(
        png,
        name: 'sample.jpeg',
      );

      expect(prepared.bytes, png);
      expect(prepared.name, 'sample.png');
    });

    test('converts decodable non-png images to png', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(_image()));

      final prepared = KritaOutboundImage.prepare(
        jpeg,
        name: 'photo.jpg',
      );

      expect(prepared.name, 'photo.png');
      expect(_hasPngSignature(prepared.bytes), isTrue);
      expect(img.decodePng(prepared.bytes), isNotNull);
    });

    test('rejects undecodable bytes', () {
      expect(
        () => KritaOutboundImage.prepare(
          Uint8List.fromList([1, 2, 3]),
          name: 'broken.bin',
        ),
        throwsFormatException,
      );
    });
  });

  group('KritaOutboundImage.prepareInBackground', () {
    test('passes png through without waiting for the compute gate', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final release = Completer<void>();
      final occupied = gate.run(() => release.future);
      final png = _png();

      final prepared = await KritaOutboundImage.prepareInBackground(
        png,
        name: 'sample.jpeg',
        gate: gate,
      );

      expect(prepared.bytes, same(png));
      expect(prepared.name, 'sample.png');
      release.complete();
      await occupied;
    });

    test('converts non-png bytes exactly like prepare', () async {
      final jpeg = Uint8List.fromList(img.encodeJpg(_image()));
      final expected = KritaOutboundImage.prepare(jpeg, name: 'photo.jpg');

      final prepared = await KritaOutboundImage.prepareInBackground(
        jpeg,
        name: 'photo.jpg',
      );

      expect(prepared.bytes, orderedEquals(expected.bytes));
      expect(prepared.name, expected.name);
    });

    test('keeps the format error for undecodable bytes', () async {
      await expectLater(
        KritaOutboundImage.prepareInBackground(
          Uint8List.fromList([1, 2, 3]),
          name: 'broken.bin',
        ),
        throwsFormatException,
      );
    });
  });
}

img.Image _image() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(70, 45, 55));
  return image;
}

Uint8List _png() => Uint8List.fromList(img.encodePng(_image()));

bool _hasPngSignature(Uint8List bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) {
    return false;
  }
  for (var i = 0; i < signature.length; i += 1) {
    if (bytes[i] != signature[i]) {
      return false;
    }
  }
  return true;
}
