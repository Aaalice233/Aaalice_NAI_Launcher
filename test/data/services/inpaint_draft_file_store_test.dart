import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/nai_resolution_adapter.dart';
import 'package:nai_launcher/data/models/inpaint/inpaint_draft.dart';
import 'package:nai_launcher/data/services/inpaint_draft_file_store.dart';
import 'package:nai_launcher/data/services/inpaint_draft_repository.dart';
import 'package:nai_launcher/data/services/metadata/hash_calculator.dart';

import '../../helpers/shared_compute_gate.dart';

void main() {
  group('inspectImage', () {
    test('decodes through the injected decoder', () async {
      final decoder = _RecordingDecoder();
      final store = InpaintDraftFileStore(decodeImageSize: decoder.call);
      final bytes = _png(width: 12, height: 8);

      final asset = await store.inspectImage(bytes, label: 'source');

      expect(decoder.calls.single, same(bytes));
      _expectMatchesDirectDecode(asset, bytes);
    });

    test('default decoder matches a direct decode', () async {
      final bytes = _png(width: 12, height: 8);

      final asset = await InpaintDraftFileStore().inspectImage(
        bytes,
        label: 'source',
      );

      _expectMatchesDirectDecode(asset, bytes);
    });

    test('rejects bytes that are not an image', () async {
      final bytes = Uint8List.fromList(utf8.encode('not an image ' * 20));
      expect(img.decodeImage(bytes), isNull);

      await expectLater(
        InpaintDraftFileStore().inspectImage(bytes, label: 'mask'),
        throwsA(_integrityError('mask is not a supported image')),
      );
    });

    test('keeps the decoder error type across the isolate boundary', () async {
      final corrupt = _pngWithCorruptPixelData();
      expect(
        () => img.decodeImage(corrupt),
        throwsA(isA<img.ImageException>()),
      );

      await expectLater(
        InpaintDraftFileStore().inspectImage(corrupt, label: 'source'),
        throwsA(isA<img.ImageException>()),
      );
    });
  });

  group('verifyBytes', () {
    test('accepts a matching PNG from its header alone', () async {
      final decoder = _RecordingDecoder();
      final store = InpaintDraftFileStore(decodeImageSize: decoder.call);
      final bytes = _png(width: 12, height: 8);

      await store.verifyBytes(bytes, _assetOf(bytes, 12, 8), 'source');

      expect(decoder.calls, isEmpty);
    });

    test('reports a checksum mismatch before decoding', () async {
      final decoder = _RecordingDecoder();
      final store = InpaintDraftFileStore(decodeImageSize: decoder.call);
      final expected = _assetOf(_png(value: 99), 8, 8);

      await expectLater(
        store.verifyBytes(_png(), expected, 'mask'),
        throwsA(_integrityError('mask checksum or size mismatch')),
      );
      expect(decoder.calls, isEmpty);
    });

    test('confirms a header mismatch with a full decode', () async {
      final decoder = _RecordingDecoder();
      final store = InpaintDraftFileStore(decodeImageSize: decoder.call);
      final bytes = _png(width: 12, height: 8);

      await expectLater(
        store.verifyBytes(bytes, _assetOf(bytes, 8, 12), 'source'),
        throwsA(_integrityError('source dimensions mismatch')),
      );
      expect(decoder.calls.single, same(bytes));
    });

    test('verifies an EXIF-rotated JPEG from its oriented header', () async {
      final bytes = _rotatedJpeg(width: 12, height: 8);
      final decoded = img.decodeImage(bytes)!;
      expect(NaiResolutionAdapter.readImageSize(bytes), (8, 12));
      expect((decoded.width, decoded.height), (8, 12));
      final decoder = _RecordingDecoder();
      final store = InpaintDraftFileStore(decodeImageSize: decoder.call);

      final asset = await store.inspectImage(bytes, label: 'source');
      await store.verifyBytes(bytes, asset, 'source');

      expect((asset.width, asset.height), (8, 12));
      expect(decoder.calls, hasLength(1));
    });

    test('default decoder verifies an EXIF-rotated JPEG', () async {
      final bytes = _rotatedJpeg(width: 12, height: 8);
      final store = InpaintDraftFileStore();

      final asset = await store.inspectImage(bytes, label: 'source');

      await expectLater(store.verifyBytes(bytes, asset, 'source'), completes);
    });
  });

  group('large assets', () {
    final bytes = _storedPng(value: 40);

    test('are large enough to hash in the background', () {
      expect(
        bytes.length,
        greaterThanOrEqualTo(FileHashCalculator.backgroundHashMinBytes),
      );
    });

    test('inspectImage hashes behind the shared compute gate', () async {
      final store = InpaintDraftFileStore(
        decodeImageSize: _RecordingDecoder().call,
      );

      final asset = await expectQueuedBehindSharedComputeGate(
        () => store.inspectImage(bytes, label: 'source'),
      );

      _expectMatchesDirectDecode(asset, bytes);
    });

    test(
      'verifyBytes checks the checksum behind the shared compute gate',
      () async {
        final decoder = _RecordingDecoder();
        final store = InpaintDraftFileStore(decodeImageSize: decoder.call);
        final expected = _assetOf(bytes, _storedPngSide, _storedPngSide);

        await expectQueuedBehindSharedComputeGate(
          () => store.verifyBytes(bytes, expected, 'source'),
        );

        expect(decoder.calls, isEmpty);
      },
    );

    test('a same-size asset with other pixels fails the checksum', () async {
      final decoder = _RecordingDecoder();
      final store = InpaintDraftFileStore(decodeImageSize: decoder.call);
      final other = _storedPng(value: 41);
      expect(other.length, bytes.length);

      await expectLater(
        store.hasChecksum(
          other,
          _assetOf(bytes, _storedPngSide, _storedPngSide),
        ),
        completion(isFalse),
      );
      await expectLater(
        store.verifyBytes(
          other,
          _assetOf(bytes, _storedPngSide, _storedPngSide),
          'mask',
        ),
        throwsA(_integrityError('mask checksum or size mismatch')),
      );
      expect(decoder.calls, isEmpty);
    });
  });
}

class _RecordingDecoder {
  final calls = <Uint8List>[];

  Future<(int, int)?> call(Uint8List bytes) async {
    calls.add(bytes);
    final decoded = img.decodeImage(bytes);
    return decoded == null ? null : (decoded.width, decoded.height);
  }
}

void _expectMatchesDirectDecode(InpaintDraftAsset asset, Uint8List bytes) {
  final decoded = img.decodeImage(bytes)!;
  expect(asset.width, decoded.width);
  expect(asset.height, decoded.height);
  expect(asset.sizeBytes, bytes.length);
  expect(asset.sha256, sha256.convert(bytes).toString());
}

Matcher _integrityError(String message) => isA<InpaintDraftIntegrityException>()
    .having((error) => error.message, 'message', message);

InpaintDraftAsset _assetOf(Uint8List bytes, int width, int height) {
  return InpaintDraftAsset(
    sha256: sha256.convert(bytes).toString(),
    sizeBytes: bytes.length,
    width: width,
    height: height,
  );
}

Uint8List _png({int width = 8, int height = 8, int value = 128}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}

const _storedPngSide = 160;

/// Uncompressed PNG: every fill value encodes to the same byte length.
Uint8List _storedPng({required int value}) {
  final image = img.Image(width: _storedPngSide, height: _storedPngSide);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image, level: 0));
}

Uint8List _rotatedJpeg({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(90, 120, 150));
  image.exif.imageIfd.orientation = 6;
  return Uint8List.fromList(img.encodeJpg(image));
}

Uint8List _pngWithCorruptPixelData() {
  final bytes = _png();
  const idat = [0x49, 0x44, 0x41, 0x54];
  for (var i = 0; i + idat.length < bytes.length; i++) {
    if (bytes[i] == idat[0] &&
        bytes[i + 1] == idat[1] &&
        bytes[i + 2] == idat[2] &&
        bytes[i + 3] == idat[3]) {
      bytes[i + idat.length] ^= 0xFF;
      return bytes;
    }
  }
  throw StateError('Encoded PNG has no IDAT chunk');
}
