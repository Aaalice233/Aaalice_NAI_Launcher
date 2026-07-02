import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_drop_import_preprocessor.dart';

void main() {
  test('skips oversized images before reading bytes', () async {
    final readPaths = <String>[];

    final result = await VibeDropImportPreprocessor.collectImageItems(
      const ['small.png', 'too_large.png'],
      limits: const VibeDropImageReadLimits(
        maxFileBytes: 10,
        maxTotalBytes: 100,
        batchSize: 2,
      ),
      lengthReader: (path) async => path == 'too_large.png' ? 11 : 10,
      bytesReader: (path) async {
        readPaths.add(path);
        return Uint8List.fromList([1, 2, 3]);
      },
    );

    expect(result.items.map((item) => item.source), ['small.png']);
    expect(result.skippedOversizedCount, 1);
    expect(readPaths, ['small.png']);
  });

  test('stops at the total byte limit before reading later images', () async {
    final readPaths = <String>[];

    final result = await VibeDropImportPreprocessor.collectImageItems(
      const ['a.png', 'b.png', 'c.png'],
      limits: const VibeDropImageReadLimits(
        maxFileBytes: 20,
        maxTotalBytes: 25,
        batchSize: 2,
      ),
      lengthReader: (_) async => 10,
      bytesReader: (path) async {
        readPaths.add(path);
        return Uint8List.fromList([1]);
      },
    );

    expect(result.items.map((item) => item.source), ['a.png', 'b.png']);
    expect(result.skippedTotalLimitCount, 1);
    expect(readPaths, ['a.png', 'b.png']);
  });

  test('limits concurrent image reads to the configured batch size', () async {
    var activeReads = 0;
    var maxActiveReads = 0;

    final result = await VibeDropImportPreprocessor.collectImageItems(
      const ['a.png', 'b.png', 'c.png', 'd.png', 'e.png'],
      limits: const VibeDropImageReadLimits(
        maxFileBytes: 20,
        maxTotalBytes: 100,
        batchSize: 2,
      ),
      lengthReader: (_) async => 10,
      bytesReader: (path) async {
        activeReads += 1;
        maxActiveReads = activeReads > maxActiveReads
            ? activeReads
            : maxActiveReads;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activeReads -= 1;
        return Uint8List.fromList(path.codeUnits);
      },
    );

    expect(result.items, hasLength(5));
    expect(maxActiveReads, 2);
  });
}
