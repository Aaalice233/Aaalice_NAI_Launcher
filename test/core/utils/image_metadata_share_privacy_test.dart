import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

const _secret = 'PRIVATE_METADATA_295_\u4e2d\u6587';

void main() {
  for (final useStealth in [false, true]) {
    test('saved metadata stays stripped across share caches '
        '(stealth=$useStealth)', () async {
      final parent = Directory('tool/.tmp/metadata-share-privacy-tests');
      await parent.create(recursive: true);
      final root = await parent.createTemp('case-');
      addTearDown(() => root.delete(recursive: true));
      final original = await ImageSaveUtils.buildPrebuiltMetadataBytes(
        imageBytes: _privatePng(),
        metadata: const {
          'Description': _secret,
          'Software': 'NovelAI',
          'Source': 'privacy-test',
          'Comment': {'prompt': _secret, 'seed': 295},
        },
        useStealth: useStealth,
      );
      expect(
        ImageMetadataContainerCodec.extractPngTextData(original)['Comment'],
        contains(_secret),
      );
      if (useStealth) {
        expect(
          ImageMetadataContainerCodec.extractStealthMetadataText(original),
          contains(_secret),
        );
      }
      final source = await File(
        '${root.path}/original.png',
      ).writeAsBytes(original);
      final cache = ShareImageTransferCache(
        imageBytes: original,
        fileName: 'original.png',
        sourceFilePath: source.path,
        writeTempFile: (image) =>
            File('${root.path}/transfer.png').writeAsBytes(image.bytes),
      );
      addTearDown(cache.dispose);
      expect((await cache.prepareFile(stripMetadata: false)).path, source.path);
      final strippedFile = await cache.prepareFile(stripMetadata: true);
      expect(strippedFile.path, isNot(source.path));
      _expectStripped(await strippedFile.readAsBytes());
      _expectStripped((await cache.prepareImage(stripMetadata: true)).bytes);

      final service = ShareImagePreparationService(
        writePreparedFile: (key, image) =>
            File('${root.path}/$key.png').writeAsBytes(image.bytes),
      );
      addTearDown(service.dispose);
      addTearDown(service.clearAll);
      for (final strip in [false, true]) {
        service.enqueue(
          imageId: 'saved-image',
          imageBytes: original,
          fileName: 'original.png',
          sourceFilePath: source.path,
          stripMetadata: strip,
        );
        final file = await service.waitUntilReady(
          'saved-image',
          stripMetadata: strip,
        );
        expect(file, isNotNull);
        if (strip) {
          expect(file!.path, isNot(source.path));
          _expectStripped(await file.readAsBytes());
        } else {
          expect(file!.path, source.path);
        }
      }
      expect(
        service.readyFileFor('saved-image', stripMetadata: false)?.path,
        source.path,
      );
      expect(await source.readAsBytes(), orderedEquals(original));
    });
  }
}

Uint8List _privatePng() {
  final image = img.Image(width: 128, height: 128, numChannels: 4)
    ..iccProfile = img.IccProfile(
      'private-profile',
      img.IccProfileCompression.none,
      Uint8List.fromList(utf8.encode(_secret)),
    );
  final png = Uint8List.fromList(img.encodePng(image));
  final exifText = utf8.encode('PRIVATE_EXIF_295');
  final exif = Uint8List(27 + exifText.length)
    ..setAll(0, [73, 73, 42, 0, 8, 0, 0, 0])
    ..setAll(26, exifText);
  ByteData.sublistView(exif)
    ..setUint16(8, 1, Endian.little)
    ..setUint16(10, 0x010e, Endian.little)
    ..setUint16(12, 2, Endian.little)
    ..setUint32(14, exifText.length + 1, Endian.little)
    ..setUint32(18, 26, Endian.little);
  return (BytesBuilder()
        ..add(Uint8List.sublistView(png, 0, png.length - 12))
        ..add(_chunk('eXIf', exif))
        ..add(_chunk('tIME', [7, 234, 9, 15, 12, 30, 0]))
        ..add(_chunk('aaAa', utf8.encode(_secret)))
        ..add(
          _chunk('zTXt', [
            ...latin1.encode('PrivateCompressed'),
            0,
            0,
            ...ZLibCodec().encode(latin1.encode('PRIVATE_COMPRESSED_295')),
          ]),
        )
        ..add(Uint8List.sublistView(png, png.length - 12)))
      .takeBytes();
}

Uint8List _chunk(String type, List<int> payload) {
  final bytes = Uint8List(payload.length + 12)
    ..setAll(4, latin1.encode(type))
    ..setAll(8, payload);
  ByteData.sublistView(bytes)
    ..setUint32(0, payload.length)
    ..setUint32(
      bytes.length - 4,
      getCrc32(Uint8List.sublistView(bytes, 4, bytes.length - 4)),
    );
  return bytes;
}

void _expectStripped(Uint8List bytes) {
  expect(ImageMetadataContainerCodec.extractPngTextData(bytes), isEmpty);
  expect(ImageMetadataContainerCodec.extractStealthMetadataText(bytes), isNull);
  final decoded = img.decodePng(bytes);
  expect(decoded, isNotNull);
  expect(decoded!.iccProfile, isNull);
  final view = ByteData.sublistView(bytes);
  const forbidden = {'tEXt', 'iTXt', 'zTXt', 'eXIf', 'tIME', 'iCCP', 'aaAa'};
  for (var offset = 8; offset < bytes.length;) {
    final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
    expect(forbidden, isNot(contains(type)));
    offset += view.getUint32(offset) + 12;
  }
}
