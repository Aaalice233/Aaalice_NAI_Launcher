import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/background_metadata_parser.dart';
import 'package:nai_launcher/data/services/metadata/hash_calculator.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

void main() {
  late Directory directory;
  late Uint8List source;
  setUpAll(() async {
    await Directory('tool/.tmp').create(recursive: true);
    directory = await Directory('tool/.tmp').createTemp('metadata_background_');
    source = await UnifiedMetadataParser.embedMetadata(
      Uint8List.fromList(
        img.encodePng(img.Image(width: 64, height: 64, numChannels: 4)),
      ),
      '{"prompt":"synthetic prompt","uc":"synthetic negative","seed":42,"width":64,"height":64}',
      useStealth: true,
    );
  });
  tearDownAll(() async {
    FileHashCalculator().clearCache();
    await directory.delete(recursive: true);
  });

  test('background byte parser preserves metadata and input bytes', () async {
    final original = Uint8List.fromList(source);
    final expected = UnifiedMetadataParser.parseFromImage(source);
    final actual = await parseMetadataBytesInBackground(source);
    expect(actual.success, isTrue);
    expect(actual.metadata?.toJson(), expected.metadata?.toJson());
    expect(actual.sourceFormat, expected.sourceFormat);
    expect(source, orderedEquals(original));
  });

  test('background file parser preserves gradual-read behavior', () async {
    final file = File('${directory.path}/source.png');
    await file.writeAsBytes(source);
    final expected = UnifiedMetadataParser.parseFromFile(file.path);
    final actual = await parseMetadataFileInBackground(file.path);
    expect(actual.success, isTrue);
    expect(actual.metadata?.toJson(), expected.metadata?.toJson());
  });

  test('background parser recovers a stealth-only prompt', () async {
    final bytes = BytesBuilder()..add(source.sublist(0, 8));
    var offset = 8;
    final view = ByteData.sublistView(source);
    while (offset + 12 <= source.length) {
      final length = view.getUint32(offset);
      final end = offset + length + 12;
      final type = String.fromCharCodes(source.sublist(offset + 4, offset + 8));
      if (!{'tEXt', 'iTXt', 'zTXt'}.contains(type)) {
        bytes.add(source.sublist(offset, end));
      }
      offset = end;
    }
    final result = await parseMetadataBytesInBackground(bytes.takeBytes());
    expect(result.success, isTrue);
    expect(result.metadata?.prompt, 'synthetic prompt');
  });

  test('background parser retains invalid-input diagnostics', () async {
    final invalid = Uint8List.fromList([1, 2, 3]);
    final expected = UnifiedMetadataParser.parseFromImage(invalid);
    final actual = await parseMetadataBytesInBackground(invalid);
    expect(actual.success, isFalse);
    expect(actual.errorMessage, expected.errorMessage);
  });

  test(
    'missing file returns a failed parse rather than an uncaught error',
    () async {
      final result = await parseMetadataFileInBackground(
        '${directory.path}/missing.png',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotEmpty);
    },
  );

  test(
    'background hashes match the synchronous digest and retain file deduplication',
    () async {
      final calculator = FileHashCalculator();
      final expected = sha256.convert(source).toString();
      expect(await calculator.calculateFromBytesInBackground(source), expected);
      final file = File('${directory.path}/hash.png');
      await file.writeAsBytes(source);
      final count = calculator.hashComputeCount;
      final results = await Future.wait(
        List.generate(5, (_) => calculator.calculate(file.path)),
      );
      expect(results, everyElement(expected));
      expect(calculator.hashComputeCount - count, 1);
    },
  );

  test(
    'foreground service routes all parses and byte hashes through background helpers',
    () {
      final service = File(
        'lib/data/services/image_metadata_service.dart',
      ).readAsStringSync();
      expect(service, isNot(contains('UnifiedMetadataParser.parseFrom')));
      expect(
        service,
        isNot(contains('_hashCalculator.calculateFromBytes(bytes)')),
      );
      expect(service, contains('await parseMetadataFileInBackground(path)'));
      expect(service, contains('await parseMetadataBytesInBackground(bytes)'));
    },
  );
}
