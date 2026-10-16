import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/exif_orientation_metadata.dart';

import '../../../helpers/exif_orientation_fixture.dart';

void main() {
  group('ExifOrientationMetadata.withUprightOrientation', () {
    test('rewrites only the orientation value of a camera jpeg', () {
      final tiff = jpegExifPayload(orientedCameraJpeg(orientation: 6));
      expect(readImageIfd(tiff).orientation, 6);

      final upright = ExifOrientationMetadata.withUprightOrientation(tiff);

      final ifd = readImageIfd(upright);
      expect(ifd.orientation, 1);
      expect(ifd.make, 'Aaalice Camera');
      expect(ifd.model, 'Orientation Probe');
      expect(ifd.software, 'fixture');
      expect(differsOnlyInOrientation(tiff, upright), isTrue);
      expect(readImageIfd(tiff).orientation, 6, reason: 'input is not mutated');
    });

    for (final endian in [Endian.little, Endian.big]) {
      for (final type in [3, 4]) {
        test('patches a $endian type $type orientation in place', () {
          final tiff = _tiff(endian: endian, orientationType: type);

          final upright = ExifOrientationMetadata.withUprightOrientation(tiff);

          final changed = [
            for (var i = 0; i < tiff.length; i++)
              if (tiff[i] != upright[i]) i,
          ];
          expect(changed, isNotEmpty);
          expect(changed.every((index) => index >= 30 && index < 34), isTrue);
          expect(
            type == 3
                ? ByteData.sublistView(upright).getUint16(30, endian)
                : ByteData.sublistView(upright).getUint32(30, endian),
            1,
          );
        });
      }
    }

    test('leaves exif without an orientation tag untouched', () {
      final tiff = _tiff(endian: Endian.little, orientationType: null);

      expect(
        identical(ExifOrientationMetadata.withUprightOrientation(tiff), tiff),
        isTrue,
      );
    });
  });
}

/// IFD0 两个条目：0x010F Make（内联 ASCII）与可选的 0x0112 方向（值 6）。
Uint8List _tiff({required Endian endian, required int? orientationType}) {
  final bytes = Uint8List(40);
  final view = ByteData.sublistView(bytes);
  bytes.setAll(0, endian == Endian.little ? [0x49, 0x49] : [0x4D, 0x4D]);
  view.setUint16(2, 42, endian);
  view.setUint32(4, 8, endian);
  view.setUint16(8, 2, endian);
  view.setUint16(10, 0x010F, endian);
  view.setUint16(12, 2, endian);
  view.setUint32(14, 4, endian);
  bytes.setAll(18, [0x41, 0x42, 0x43, 0]);
  view.setUint16(22, orientationType == null ? 0x0110 : 0x0112, endian);
  view.setUint16(24, orientationType ?? 3, endian);
  view.setUint32(26, 1, endian);
  if (orientationType == 4) {
    view.setUint32(30, 6, endian);
  } else {
    view.setUint16(30, 6, endian);
  }
  view.setUint32(34, 0, endian);
  return bytes;
}
