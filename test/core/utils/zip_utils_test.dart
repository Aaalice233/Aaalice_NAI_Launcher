import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/core/utils/zip_utils.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

void main() {
  late Directory tempDirectory;
  late File sourceFile;
  late Uint8List sourceBytes;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('zip_utils_test_');
    final baseImage = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4, numChannels: 4)),
    );
    sourceBytes = UnifiedMetadataParser.embedTextChunkOnly(
      baseImage,
      'Comment',
      '{"prompt":"private prompt"}',
    );
    sourceFile = File('${tempDirectory.path}/source.png');
    await sourceFile.writeAsBytes(sourceBytes);
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('createZipFromImages preserves original bytes by default', () async {
    final output = File('${tempDirectory.path}/original.zip');

    final success = await ZipUtils.createZipFromImages([
      sourceFile.path,
    ], output.path);

    expect(success, isTrue);
    expect(
      _firstArchiveFileBytes(output),
      completion(orderedEquals(sourceBytes)),
    );
  });

  test('metadata stripping only sanitizes the archived copy', () async {
    final output = File('${tempDirectory.path}/sanitized.zip');
    final expected = await ImageShareSanitizer.sanitizeForShare(
      sourceBytes,
      fileName: 'source.png',
    );

    final success = await ZipUtils.createZipFromImages(
      [sourceFile.path],
      output.path,
      stripMetadata: true,
    );

    expect(success, isTrue);
    expect(
      _firstArchiveFileBytes(output),
      completion(orderedEquals(expected.bytes)),
    );
    expect(await sourceFile.readAsBytes(), orderedEquals(sourceBytes));
  });

  test('assigns deterministic unique names to duplicate basenames', () async {
    final firstDirectory = Directory('${tempDirectory.path}/first')
      ..createSync();
    final secondDirectory = Directory('${tempDirectory.path}/second')
      ..createSync();
    final first = File('${firstDirectory.path}/same.png')
      ..writeAsBytesSync(sourceBytes);
    final second = File('${secondDirectory.path}/SAME.PNG')
      ..writeAsBytesSync(sourceBytes);
    final output = File('${tempDirectory.path}/duplicates.zip');

    final result = await ZipUtils.createZipFromImagesDetailed([
      first.path,
      second.path,
    ], output.path);

    expect(result.succeeded, isTrue);
    expect(result.exportedCount, 2);
    expect(await _archiveNames(output), ['same.png', 'SAME (2).PNG']);
  });

  test(
    'reports missing files as partial success with monotonic progress',
    () async {
      final output = File('${tempDirectory.path}/partial.zip');
      final progress = <ZipCreationProgress>[];

      final result = await ZipUtils.createZipFromImagesDetailed(
        [sourceFile.path, '${tempDirectory.path}/missing.png'],
        output.path,
        onProgress: progress.add,
      );

      expect(result.succeeded, isTrue);
      expect(result.isPartial, isTrue);
      expect(result.exportedCount, 1);
      expect(result.failures.single.path, endsWith('missing.png'));
      expect(progress.map((item) => item.current), [1, 2]);
      expect(progress.every((item) => item.total == 2), isTrue);
    },
  );

  test('failed strict export preserves an existing destination', () async {
    final output = File('${tempDirectory.path}/existing.zip');
    final originalOutput = Uint8List.fromList([1, 2, 3, 4]);
    await output.writeAsBytes(originalOutput);
    final invalidImage = File('${tempDirectory.path}/invalid.png');
    await invalidImage.writeAsBytes([1, 2, 3, 4]);

    final result = await ZipUtils.createZipFromImagesDetailed(
      [invalidImage.path],
      output.path,
      stripMetadata: true,
    );

    expect(result.succeeded, isFalse);
    expect(result.exportedCount, 0);
    expect(await output.readAsBytes(), orderedEquals(originalOutput));
    expect(
      tempDirectory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.part'),
      ),
      isEmpty,
    );
  });
}

Future<List<String>> _archiveNames(File zipFile) async {
  final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
  return archive.files.map((file) => file.name).toList(growable: false);
}

Future<Uint8List> _firstArchiveFileBytes(File zipFile) async {
  final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
  final file = archive.files.single;
  return Uint8List.fromList(file.content as List<int>);
}
