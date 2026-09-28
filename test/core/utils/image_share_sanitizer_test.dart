import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/core/utils/png_share_source.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

void main() {
  group('ImageShareSanitizer', () {
    test(
      'prepareForCopyOrDrag should preserve original png bytes when stripping is disabled',
      () async {
        final original = _buildPngWithTextChunks({
          'Software': 'NovelAI',
          'Comment': '{"prompt":"test prompt"}',
        });

        final result = await ImageShareSanitizer.prepareForCopyOrDrag(
          original,
          fileName: 'sample.png',
          stripMetadata: false,
        );

        expect(result.fileName, equals('sample.png'));
        expect(result.mimeType, equals('image/png'));
        expect(result.bytes, orderedEquals(original));
      },
    );

    test(
      'prepareForCopyOrDrag should normalize unsupported formats to png for clipboard',
      () async {
        final result = await ImageShareSanitizer.prepareForCopyOrDrag(
          _buildJpegBytes(),
          fileName: 'sample.heic',
          stripMetadata: false,
        );

        expect(result.fileName, equals('sample.png'));
        expect(result.mimeType, equals('image/png'));
        expect(result.bytes.take(8).toList(), equals(_pngSignature));
      },
    );

    test(
      'sanitizeForShare should remove all png metadata and stealth watermark',
      () async {
        final cleanBase = _buildPngBytes(width: 64, height: 64);
        final original = _embedOddAlphaPattern(
          UnifiedMetadataParser.embedTextChunkOnly(
            cleanBase,
            'Comment',
            '{"prompt":"test prompt"}',
          ),
        );

        final cleanResult = await ImageShareSanitizer.sanitizeForShare(
          cleanBase,
          fileName: 'sample.png',
        );

        final result = await ImageShareSanitizer.sanitizeForShare(
          original,
          fileName: 'sample.png',
        );

        final textChunks = _extractTextChunks(result.bytes);
        expect(result.fileName, equals('sample.png'));
        expect(result.mimeType, equals('image/png'));
        expect(textChunks, isEmpty);
        expect(result.bytes, orderedEquals(cleanResult.bytes));
      },
    );

    for (final channels in [1, 2, 3, 4]) {
      test(
        'sanitizer preserves color channels for $channels-channel PNG',
        () async {
          final image = img.Image(width: 8, height: 6, numChannels: channels);
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              image.setPixelRgba(x, y, x * 21, y * 31, 87, 201 + x);
            }
          }
          final source = Uint8List.fromList(img.encodePng(image));
          final before = img.decodePng(source)!;
          final output = await ImageShareSanitizer.sanitizeForShare(
            source,
            fileName: 'channels.png',
          );
          final after = img.decodePng(output.bytes)!;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              final old = before.getPixel(x, y);
              final pixel = after.getPixel(x, y);
              expect([pixel.r, pixel.g, pixel.b], [old.r, old.g, old.b]);
              expect(pixel.a, channels.isEven ? old.a.toInt() & 0xFE : old.a);
            }
          }
        },
      );
    }

    test(
      'clean pixels retain original IDAT while text and trailer are removed',
      () async {
        final image = img.Image(width: 8, height: 6, numChannels: 4);
        image.clear(img.ColorRgba8(30, 60, 90, 254));
        final clean = Uint8List.fromList(img.encodePng(image));
        final text = UnifiedMetadataParser.embedTextChunkOnly(
          clean,
          'Comment',
          'private prompt',
        );
        final source = Uint8List.fromList([
          ...text,
          ...utf8.encode('private trailer'),
        ]);
        final result = await ImageShareSanitizer.sanitizeForShare(
          source,
          fileName: 'clean.png',
        );
        expect(result.bytes, clean);
      },
    );

    test(
      'native sanitization preserves 16-bit colors and alpha high bits',
      () async {
        final image = img.Image(
          width: 4,
          height: 3,
          numChannels: 4,
          format: img.Format.uint16,
        );
        for (var y = 0; y < 3; y++) {
          for (var x = 0; x < 4; x++) {
            image.setPixelRgba(x, y, 32000 + x, 64000 + y, 12345, 65001 + x);
          }
        }
        final result = await ImageShareSanitizer.sanitizeForShare(
          Uint8List.fromList(img.encodePng(image)),
          fileName: '16bit.png',
        );
        final decoded = img.decodePng(result.bytes)!;
        expect(decoded.bitsPerChannel, 16);
        for (var y = 0; y < 3; y++) {
          for (var x = 0; x < 4; x++) {
            final pixel = decoded.getPixel(x, y);
            expect(
              [pixel.r, pixel.g, pixel.b, pixel.a],
              [32000 + x, 64000 + y, 12345, (65001 + x) & 0xfffe],
            );
          }
        }
      },
    );

    test(
      'APNG retains every frame and duration while clearing alpha bits',
      () async {
        final first = img.Image(width: 4, height: 3, numChannels: 4)
          ..frameDuration = 100
          ..loopCount = 3;
        first.clear(img.ColorRgba8(20, 40, 60, 255));
        final second = img.Image(width: 4, height: 3, numChannels: 4)
          ..frameDuration = 200;
        second.clear(img.ColorRgba8(80, 100, 120, 253));
        first.addFrame(second);
        final result = await ImageShareSanitizer.sanitizeForShare(
          Uint8List.fromList(img.encodePng(first)),
          fileName: 'animation.png',
        );
        final decoded = img.decodePng(result.bytes)!;
        expect(decoded.frames, hasLength(2));
        expect(PngShareSource.parse(result.bytes).animationLoopCount, 3);
        expect(decoded.frames.map((f) => f.frameDuration), [100, 200]);
        expect(decoded.frames.map((f) => f.getPixel(0, 0).a), [254, 252]);
        expect(decoded.frames.map((f) => f.getPixel(0, 0).r), [20, 80]);
      },
    );

    test('sanitizeForShare removes embedded ICC profile metadata', () async {
      const token = 'NAI_ICC_PROFILE_SENTINEL';
      final image = img.Image(width: 2, height: 2, numChannels: 4)
        ..iccProfile = img.IccProfile(
          'launcher-test',
          img.IccProfileCompression.none,
          Uint8List.fromList(utf8.encode(token)),
        );
      final original = Uint8List.fromList(img.encodePng(image));
      final decodedOriginal = img.decodePng(original);
      expect(
        decodedOriginal?.iccProfile?.decompressed(),
        containsAll(utf8.encode(token)),
      );

      final result = await ImageShareSanitizer.sanitizeForShare(
        original,
        fileName: 'profile.png',
      );

      expect(img.decodePng(result.bytes)?.iccProfile, isNull);
    });

    test(
      'sanitizeForShare should normalize non-png formats to png output',
      () async {
        final result = await ImageShareSanitizer.sanitizeForShare(
          _buildJpegBytes(),
          fileName: 'sample.jpg',
        );

        expect(result.fileName, equals('sample.png'));
        expect(result.mimeType, equals('image/png'));
        expect(result.bytes.take(8).toList(), equals(_pngSignature));
      },
    );

    test('sanitizeForShare rejects a png without a png signature', () async {
      await expectLater(
        ImageShareSanitizer.sanitizeForShare(
          Uint8List.fromList(const [1, 2, 3, 4]),
          fileName: 'broken.png',
        ),
        throwsA(isA<ImageSanitizeException>()),
      );
    });

    test('sanitizeForShare rejects a malformed signed png', () async {
      await expectLater(
        ImageShareSanitizer.sanitizeForShare(
          Uint8List.fromList([..._pngSignature, 1, 2, 3, 4]),
          fileName: 'broken.png',
        ),
        throwsA(isA<ImageSanitizeException>()),
      );
    });

    test('sanitizeForShare rejects undecodable non-png bytes', () async {
      await expectLater(
        ImageShareSanitizer.sanitizeForShare(
          Uint8List.fromList(const [9, 8, 7, 6]),
          fileName: 'broken.jpg',
        ),
        throwsA(isA<ImageSanitizeException>()),
      );
    });

    test(
      'unprotected unsupported normalization preserves legacy fallback',
      () async {
        final bytes = Uint8List.fromList(const [9, 8, 7, 6]);
        final result = await ImageShareSanitizer.prepareForCopyOrDrag(
          bytes,
          fileName: 'sample.heic',
          stripMetadata: false,
        );

        expect(result.fileName, 'sample.png');
        expect(result.bytes, orderedEquals(bytes));
      },
    );
  });

  group('ShareImageTransferCache', () {
    test('default preparation should sanitize stripped copies', () async {
      final original = _buildPngWithTextChunks({
        'Comment': '{"prompt":"test prompt"}',
      });
      final cache = ShareImageTransferCache(
        imageBytes: original,
        fileName: 'memory.png',
      );
      addTearDown(cache.dispose);

      final result = await cache.prepareImage(stripMetadata: true);

      expect(result.mimeType, equals('image/png'));
      expect(_extractTextChunks(result.bytes), isEmpty);
    });

    test(
      'prepareFile should reuse source file directly when metadata stripping is disabled',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'share_image_transfer_cache_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final sourceFile = File('${tempDir.path}/source.png');
        await sourceFile.writeAsBytes(_buildPngBytes(width: 4, height: 4));

        var prepareCount = 0;
        var writeCount = 0;
        final cache = ShareImageTransferCache(
          imageBytes: Uint8List.fromList(const [1, 2, 3]),
          fileName: 'memory.png',
          sourceFilePath: sourceFile.path,
          prepareImage:
              (bytes, {required fileName, required stripMetadata}) async {
                prepareCount++;
                return SanitizedShareImage(
                  bytes: bytes,
                  fileName: fileName,
                  mimeType: 'image/png',
                );
              },
          writeTempFile: (image) async {
            writeCount++;
            return File('${tempDir.path}/prepared.png')
              ..writeAsBytesSync(image.bytes);
          },
        );
        addTearDown(cache.dispose);

        final result = await cache.prepareFile(stripMetadata: false);

        expect(result.path, equals(sourceFile.path));
        expect(prepareCount, equals(0));
        expect(writeCount, equals(0));
      },
    );

    test(
      'prepareFile should cache generated temp file for repeated requests',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'share_image_transfer_cache_repeat_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        var prepareCount = 0;
        var writeCount = 0;
        final cache = ShareImageTransferCache(
          imageBytes: _buildPngBytes(width: 4, height: 4),
          fileName: 'memory.png',
          prepareImage:
              (bytes, {required fileName, required stripMetadata}) async {
                prepareCount++;
                return SanitizedShareImage(
                  bytes: bytes,
                  fileName: fileName,
                  mimeType: 'image/png',
                );
              },
          writeTempFile: (image) async {
            writeCount++;
            final file = File('${tempDir.path}/prepared_$writeCount.png');
            await file.writeAsBytes(image.bytes);
            return file;
          },
        );
        addTearDown(cache.dispose);

        final first = await cache.prepareFile(stripMetadata: false);
        final second = await cache.prepareFile(stripMetadata: false);

        expect(first.path, equals(second.path));
        expect(prepareCount, equals(1));
        expect(writeCount, equals(1));
      },
    );

    test('warmUp consumes errors but keeps the failed future cached', () async {
      final cache = ShareImageTransferCache(
        imageBytes: Uint8List.fromList(const [1, 2, 3]),
        fileName: 'broken.png',
        prepareImage:
            (bytes, {required fileName, required stripMetadata}) async {
              throw const ImageSanitizeException('expected failure');
            },
      );
      addTearDown(cache.dispose);

      cache.warmUp(stripMetadata: true);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        cache.prepareFile(stripMetadata: true),
        throwsA(isA<ImageSanitizeException>()),
      );
    });
  });

  group('ShareImagePreparationService', () {
    test('moves strict sanitization failures to failed state', () async {
      final service = ShareImagePreparationService();
      addTearDown(service.clearAll);

      service.enqueue(
        imageId: 'broken',
        imageBytes: Uint8List.fromList(const [1, 2, 3]),
        fileName: 'broken.png',
        stripMetadata: true,
      );

      expect(
        await service.waitUntilReady('broken', stripMetadata: true),
        isNull,
      );
      expect(
        service.snapshotFor('broken', stripMetadata: true).status,
        ShareImagePreparationStatus.failed,
      );
    });

    test(
      'should not expose an unstripped fallback while strip variant prepares',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'share_image_preparation_no_fallback_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final sourceFile = File('${tempDir.path}/source.png');
        await sourceFile.writeAsBytes(const [1, 2, 3, 4]);
        final allowPrepare = Completer<void>();
        var prepareStripValue = false;

        final service = ShareImagePreparationService(
          prepareImage:
              (bytes, {required fileName, required stripMetadata}) async {
                prepareStripValue = stripMetadata;
                await allowPrepare.future;
                return SanitizedShareImage(
                  bytes: Uint8List.fromList(
                    stripMetadata ? const [9, 9, 9] : const [1, 2, 3, 4],
                  ),
                  fileName: fileName,
                  mimeType: 'image/png',
                );
              },
          writePreparedFile: (cacheKey, image) async {
            final file = File('${tempDir.path}/$cacheKey.png');
            await file.writeAsBytes(image.bytes);
            return file;
          },
        );
        addTearDown(service.clearAll);

        service.enqueue(
          imageId: 'image-a',
          imageBytes: Uint8List.fromList(const [1, 2, 3, 4]),
          fileName: 'image-a.png',
          sourceFilePath: sourceFile.path,
          stripMetadata: true,
        );
        await Future<void>.delayed(Duration.zero);

        expect(prepareStripValue, isTrue);
        expect(service.readyFileFor('image-a', stripMetadata: true), isNull);
        expect(
          service.snapshotFor('image-a', stripMetadata: true).status,
          ShareImagePreparationStatus.preparing,
        );

        allowPrepare.complete();
        final readyFile = await service.waitUntilReady(
          'image-a',
          stripMetadata: true,
        );

        expect(readyFile, isNotNull);
        expect(await readyFile!.readAsBytes(), equals(const [9, 9, 9]));
        expect(readyFile.path, isNot(equals(sourceFile.path)));
      },
    );

    test('should keep strip and original variants isolated', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'share_image_preparation_variants_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes(const [1, 2, 3, 4]);

      final service = ShareImagePreparationService(
        prepareImage:
            (bytes, {required fileName, required stripMetadata}) async {
              return SanitizedShareImage(
                bytes: Uint8List.fromList(
                  stripMetadata ? const [7, 7, 7] : const [5, 5, 5],
                ),
                fileName: fileName,
                mimeType: 'image/png',
              );
            },
        writePreparedFile: (cacheKey, image) async {
          final file = File('${tempDir.path}/$cacheKey.png');
          await file.writeAsBytes(image.bytes);
          return file;
        },
      );
      addTearDown(service.clearAll);

      service.enqueue(
        imageId: 'image-a',
        imageBytes: Uint8List.fromList(const [9, 9, 9]),
        fileName: 'image-a.png',
        sourceFilePath: sourceFile.path,
        stripMetadata: false,
      );
      final originalReady = await service.waitUntilReady(
        'image-a',
        stripMetadata: false,
      );

      expect(originalReady!.path, equals(sourceFile.path));
      expect(service.readyFileFor('image-a', stripMetadata: true), isNull);

      service.enqueue(
        imageId: 'image-a',
        imageBytes: Uint8List.fromList(const [9, 9, 9]),
        fileName: 'image-a.png',
        sourceFilePath: sourceFile.path,
        stripMetadata: true,
      );
      final strippedReady = await service.waitUntilReady(
        'image-a',
        stripMetadata: true,
      );

      expect(strippedReady!.path, isNot(equals(sourceFile.path)));
      expect(await strippedReady.readAsBytes(), equals(const [7, 7, 7]));
      expect(
        service.readyFileFor('image-a', stripMetadata: false)!.path,
        equals(sourceFile.path),
      );
    });

    test('should retain prepared files until image leaves history', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'share_image_preparation_retention_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = ShareImagePreparationService(
        prepareImage:
            (bytes, {required fileName, required stripMetadata}) async {
              return SanitizedShareImage(
                bytes: bytes,
                fileName: fileName,
                mimeType: 'image/png',
              );
            },
        writePreparedFile: (cacheKey, image) async {
          final file = File('${tempDir.path}/$cacheKey.png');
          await file.writeAsBytes(image.bytes);
          return file;
        },
      );
      addTearDown(service.clearAll);

      for (final id in const ['image-a', 'image-b']) {
        service.enqueue(
          imageId: id,
          imageBytes: Uint8List.fromList(
            id == 'image-a' ? const [1, 1, 1] : const [2, 2, 2],
          ),
          fileName: '$id.png',
          stripMetadata: true,
        );
      }

      final imageA = await service.waitUntilReady(
        'image-a',
        stripMetadata: true,
      );
      final imageB = await service.waitUntilReady(
        'image-b',
        stripMetadata: true,
      );

      expect(await imageA!.exists(), isTrue);
      expect(await imageB!.exists(), isTrue);

      await service.retainHistoryImageIds({'image-a'});

      expect(await imageA.exists(), isTrue);
      expect(await imageB.exists(), isFalse);
      expect(
        service.snapshotFor('image-b', stripMetadata: true).status,
        ShareImagePreparationStatus.notQueued,
      );
    });
  });
}

Uint8List _buildPngWithTextChunks(Map<String, String> textChunks) {
  var bytes = Uint8List.fromList(base64Decode(_oneByOnePngBase64));
  for (final entry in textChunks.entries) {
    bytes = UnifiedMetadataParser.embedTextChunkOnly(
      bytes,
      entry.key,
      entry.value,
    );
  }
  return bytes;
}

Uint8List _buildJpegBytes() {
  final image = img.Image(width: 1, height: 1)
    ..setPixelRgba(0, 0, 255, 0, 0, 255);
  return Uint8List.fromList(img.encodeJpg(image));
}

Uint8List _buildPngBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      image.setPixelRgba(x, y, 20, 40, 60, 254);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _embedOddAlphaPattern(Uint8List bytes) {
  final image = img.decodePng(bytes)!;
  for (var x = 0; x < image.width; x++) {
    for (var y = 0; y < image.height; y++) {
      final pixel = image.getPixel(x, y);
      image.setPixelRgba(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        ((x + y) % 3 == 0) ? 255 : 254,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Map<String, String> _extractTextChunks(Uint8List bytes) {
  final result = <String, String>{};
  var offset = 8;

  while (offset + 12 <= bytes.length) {
    final length = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
    final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
    final dataStart = offset + 8;
    final dataEnd = dataStart + length;
    if (dataEnd + 4 > bytes.length) {
      break;
    }

    if (type == 'tEXt') {
      final data = bytes.sublist(dataStart, dataEnd);
      final nullIndex = data.indexOf(0);
      if (nullIndex > 0) {
        final keyword = latin1.decode(data.sublist(0, nullIndex));
        final value = latin1.decode(data.sublist(nullIndex + 1));
        result[keyword] = value;
      }
    }

    offset = dataEnd + 4;
  }

  return result;
}

const _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

const _oneByOnePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=';
