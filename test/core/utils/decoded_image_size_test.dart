import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/decoded_image_size.dart';
import 'package:nai_launcher/core/utils/exif_orientation.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';

import '../../helpers/exif_orientation_fixture.dart';

void main() {
  group('DecodedImageSize.readHeader', () {
    test('matches decodeImage for png, jpeg and webp headers', () {
      final cases = <String, (Uint8List, (int, int))>{
        'png': (Uint8List.fromList(img.encodePng(_image(6, 4))), (6, 4)),
        'jpeg': (Uint8List.fromList(img.encodeJpg(_image(6, 4))), (6, 4)),
        'webp lossless': (plainWebp, (20, 14)),
        'webp lossy': (_webpLossy, (6, 4)),
        'webp lossy alpha': (_webpLossyAlpha, (6, 4)),
        'webp animated': (_webpAnimated, (6, 4)),
      };

      for (final MapEntry(key: name, value: (bytes, size)) in cases.entries) {
        expect(_decodedSize(bytes), size, reason: name);
        expect(DecodedImageSize.readHeader(bytes), size, reason: name);
      }
    });

    test('jpeg frame size skips segment payloads by length', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(_image(6, 4)));
      final withDecoy = Uint8List.fromList([
        ...jpeg.sublist(0, 2),
        0xFF, 0xE2, 0x00, 2 + _decoyFrame.length, ..._decoyFrame, //
        ...jpeg.sublist(2),
      ]);

      expect(_decodedSize(withDecoy), (6, 4));
      expect(DecodedImageSize.readHeader(withDecoy), (6, 4));
    });

    test('jpeg header walk stops at the scan header', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(_image(6, 4)));
      final scan = _segments(jpeg).last;
      final headerOnly = jpeg.sublist(0, scan.offset + 2 + scan.length);
      // 扫描头之后放伪造的帧头：继续往熵编码数据里找标记的读法会读到 9×9
      final decoysAfterScan = Uint8List.fromList([
        ...headerOnly,
        ..._decoyFrame,
        0xFF,
        0xD9,
      ]);

      expect(DecodedImageSize.readHeader(headerOnly), (6, 4));
      expect(DecodedImageSize.readHeader(decoysAfterScan), (6, 4));
    });

    test('leaves jpeg headers decodeImage cannot size to a full decode', () {
      final jpeg = Uint8List.fromList(img.encodeJpg(_image(6, 4)));
      final segments = _segments(jpeg);
      final frame = segments.firstWhere((segment) => segment.marker == 0xC0);
      final frameBytes = jpeg.sublist(frame.offset, frame.end);
      final scan = segments.last;
      final cases = <String, Uint8List>{
        'truncated inside the frame header': jpeg.sublist(0, frame.offset + 6),
        'segment length below two': Uint8List.fromList(jpeg)
          ..[segments.first.offset + 2] = 0
          ..[segments.first.offset + 3] = 1,
        'no frame before the scan': Uint8List.fromList([
          ...jpeg.sublist(0, frame.offset),
          ...jpeg.sublist(frame.end),
        ]),
        'duplicate frame header': Uint8List.fromList([
          ...jpeg.sublist(0, scan.offset),
          ...frameBytes,
          ...jpeg.sublist(scan.offset),
        ]),
        'lossless frame': Uint8List.fromList(jpeg)..[frame.offset + 1] = 0xC3,
      };

      for (final MapEntry(key: name, value: bytes) in cases.entries) {
        expect(_decodedSizeOrNull(bytes), isNull, reason: name);
        expect(DecodedImageSize.readHeader(bytes), isNull, reason: name);
      }
    });

    test('reads webp headers even when the pixel decoder rejects them', () {
      expect(() => img.decodeImage(_webpPalette), throwsRangeError);
      expect(DecodedImageSize.readHeader(_webpPalette), (6, 4));
    });

    test('applies jpeg exif orientation like decodeImage', () {
      for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final jpeg = orientedCameraJpeg(orientation: orientation);
        final expected = uprightSizeOf(6, 4, orientation);

        expect(_decodedSize(jpeg), expected, reason: '$orientation');
        expect(
          DecodedImageSize.readHeader(jpeg),
          expected,
          reason: '$orientation',
        );
      }
    });

    test('applies webp exif orientation like flutter', () {
      for (final orientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
        final webp = orientedCameraWebp(orientation: orientation);
        final upright = ExifOrientation.decodeUpright(webp)!;

        expect(
          DecodedImageSize.readHeader(webp),
          uprightSizeOf(20, 14, orientation),
          reason: '$orientation',
        );
        expect(DecodedImageSize.readHeader(webp), (
          upright.width,
          upright.height,
        ), reason: '$orientation');
      }
    });

    test('leaves other formats and broken bytes to a full decode', () {
      expect(
        DecodedImageSize.readHeader(
          Uint8List.fromList(img.encodeGif(_image(6, 4))),
        ),
        isNull,
      );
      expect(
        DecodedImageSize.readHeader(
          Uint8List.fromList(img.encodeBmp(_image(6, 4))),
        ),
        isNull,
      );
      expect(DecodedImageSize.readHeader(Uint8List(0)), isNull);
      expect(
        DecodedImageSize.readHeader(Uint8List.fromList([1, 2, 3])),
        isNull,
      );
    });
  });

  group('DecodedImageSize.readDeclaredSize', () {
    test('takes the declared canvas of formats without a header reader', () {
      expect(
        DecodedImageSize.readDeclaredSize(
          Uint8List.fromList(img.encodeGif(_image(6, 4))),
        ),
        (6, 4),
      );
      expect(
        DecodedImageSize.readDeclaredSize(
          Uint8List.fromList(img.encodeBmp(_image(5, 3))),
        ),
        (5, 3),
      );
    });

    test('never answers a header format with its unrotated frame', () async {
      final jpeg = orientedCameraJpeg(orientation: 6);
      final second = _segments(jpeg)[1];
      // 段之间多一个字节：image 包仍认得它，但只能读出未转正的帧尺寸
      final padded = Uint8List.fromList([
        ...jpeg.sublist(0, second.offset),
        0x00,
        ...jpeg.sublist(second.offset),
      ]);
      final declared = img.findDecoderForData(padded)!.startDecode(padded)!;
      expect((declared.width, declared.height), (6, 4));

      expect(DecodedImageSize.readDeclaredSize(padded), isNull);
      expect(await DecodedImageSize.read(padded), (4, 6));
      expect(_decodedSize(padded), (4, 6));
    });
  });

  group('DecodedImageSize.read', () {
    test(
      'answers header formats without waiting for the compute gate',
      () async {
        final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
        final release = Completer<void>();
        final occupied = gate.run(() => release.future);

        final size = await DecodedImageSize.read(
          Uint8List.fromList(img.encodePng(_image(6, 4))),
          gate: gate,
        );

        expect(size, (6, 4));
        release.complete();
        await occupied;
      },
    );

    test('decodes other formats in the background like decodeImage', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final gif = Uint8List.fromList(img.encodeGif(_image(6, 4)));
      final bmp = Uint8List.fromList(img.encodeBmp(_image(5, 3)));

      final release = Completer<void>();
      final occupied = gate.run(() => release.future);
      var gifResolved = false;
      final gifSize = DecodedImageSize.read(
        gif,
        gate: gate,
      ).whenComplete(() => gifResolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(gifResolved, isFalse);
      release.complete();
      await occupied;

      expect(await gifSize, _decodedSize(gif));
      expect(await DecodedImageSize.read(bmp, gate: gate), _decodedSize(bmp));
    });

    test('keeps decodeImage null and error outcomes', () async {
      final unknown = Uint8List.fromList(utf8.encode('not an image at all'));
      expect(_decodedSize(unknown), isNull);
      expect(await DecodedImageSize.read(unknown), isNull);

      final empty = Uint8List(0);
      expect(() => img.decodeImage(empty), throwsA(isA<RangeError>()));
      await expectLater(
        DecodedImageSize.read(empty),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('DecodedImageSize.tryRead', () {
    test('reports decode failures as null', () async {
      expect(await DecodedImageSize.tryRead(Uint8List(0)), isNull);
      expect(
        await DecodedImageSize.tryRead(
          Uint8List.fromList(utf8.encode('not an image at all')),
        ),
        isNull,
      );
    });

    test('returns the same size as read', () async {
      final bmp = Uint8List.fromList(img.encodeBmp(_image(5, 3)));

      expect(
        await DecodedImageSize.tryRead(orientedCameraJpeg(orientation: 6)),
        (4, 6),
      );
      expect(
        await DecodedImageSize.tryRead(orientedCameraWebp(orientation: 8)),
        (14, 20),
      );
      expect(await DecodedImageSize.tryRead(bmp), (5, 3));
    });
  });
}

/// APP 段载荷里形似 9×9 基线帧头的字节。
const _decoyFrame = [0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x09, 0x00, 0x09];

img.Image _image(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 40, 90));
  return image;
}

(int, int)? _decodedSize(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  return decoded == null ? null : (decoded.width, decoded.height);
}

(int, int)? _decodedSizeOrNull(Uint8List bytes) {
  try {
    return _decodedSize(bytes);
  } catch (_) {
    return null;
  }
}

/// 编码器写出的 JPEG 从 SOI 之后到 SOS 的各段；[end] 是含段长字段的段尾。
List<({int marker, int offset, int length, int end})> _segments(
  Uint8List jpeg,
) {
  final segments = <({int marker, int offset, int length, int end})>[];
  var offset = 2;
  while (true) {
    final marker = jpeg[offset + 1];
    final length = (jpeg[offset + 2] << 8) | jpeg[offset + 3];
    final end = offset + 2 + length;
    segments.add((marker: marker, offset: offset, length: length, end: end));
    if (marker == 0xDA) return segments;
    offset = end;
  }
}

final _webpPalette = base64Decode(
  'UklGRh4AAABXRUJQVlA4TBEAAAAvBcAAAAdQlCJXq/+BiOh/AAA=',
);

final _webpLossy = base64Decode(
  'UklGRjQAAABXRUJQVlA4ICgAAABwAQCdASoGAAQAAUAmJaACdAFAAAD+77zxU/+4OP/7g4//'
  'uDj90wAA',
);

final _webpLossyAlpha = base64Decode(
  'UklGRlgAAABXRUJQVlA4WAoAAAAQAAAABQAAAwAAQUxQSAoAAAABB1DAiAhERP8DVlA4ICgA'
  'AABwAQCdASoGAAQAAUAmJaACdAFAAAD+77zxU/+4OP/7g4//uDj90wAA',
);

final _webpAnimated = base64Decode(
  'UklGRrQAAABXRUJQVlA4WAoAAAACAAAABQAAAwAAQU5JTQYAAAAAAAAAAABBTk1GOgAAAAAA'
  'AAAAAAUAAAMAAGQAAAJWUDggIgAAADABAJ0BKgYABAABQCYllAADcAD+/DeL22WiUD7k/RGA'
  'AABBTk1GRgAAAAAAAAAAAAUAAAMAAGQAAABWUDggLgAAADQBAJ0BKgYABAAAACYloAADcAD+'
  '899n/8W/aP723j//++gH/99AP/76Af18AAA=',
);
