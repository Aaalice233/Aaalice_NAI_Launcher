import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/hash_calculator.dart';

import '../../../helpers/shared_compute_gate.dart';

void main() {
  final calculator = FileHashCalculator();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('file-hash-calculator-');
    calculator
      ..clearCache()
      ..resetStatistics();
  });

  tearDown(() async {
    calculator.clearCache();
    await directory.delete(recursive: true);
  });

  File fileNamed(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  // 显式设定修改时间，不依赖文件系统的时间精度
  Future<void> writeFile(
    File file,
    List<int> bytes, {
    required DateTime modified,
  }) async {
    await file.writeAsBytes(bytes, flush: true);
    await file.setLastModified(modified);
  }

  String hashOf(List<int> bytes) =>
      calculator.calculateFromBytes(Uint8List.fromList(bytes));

  test('same-path overwrite of equal length yields the new hash', () async {
    final file = fileNamed('source.bin');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));
    expect(await calculator.calculate(file.path), hashOf([1, 2, 3]));

    await writeFile(file, [4, 5, 6], modified: DateTime(2026, 9, 2));

    expect(await calculator.calculate(file.path), hashOf([4, 5, 6]));
  });

  test('a size change is detected when the modified time is kept', () async {
    final file = fileNamed('source.bin');
    final modified = DateTime(2026, 9, 1);
    await writeFile(file, [1, 2, 3], modified: modified);
    await calculator.calculate(file.path);

    await writeFile(file, [1, 2, 3, 4], modified: modified);

    expect(await calculator.calculate(file.path), hashOf([1, 2, 3, 4]));
  });

  test('an unchanged file is answered from the path cache', () async {
    final file = fileNamed('stable.bin');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));

    final first = await calculator.calculate(file.path);
    final second = await calculator.calculate(file.path);

    expect(second, first);
    expect(calculator.hashComputeCount, 1);
    expect(calculator.hashCacheHitCount, 1);
  });

  test('a registered hash only holds while the file stays the same', () async {
    final file = fileNamed('saved.png');
    await writeFile(file, [7, 8, 9], modified: DateTime(2026, 9, 1));
    await calculator.registerPathHash(file.path, hashOf([7, 8, 9]));
    expect(calculator.verifiedHashForPathSync(file.path), hashOf([7, 8, 9]));

    await writeFile(file, [9, 8, 7], modified: DateTime(2026, 9, 2));

    expect(calculator.verifiedHashForPathSync(file.path), isNull);
    expect(await calculator.calculate(file.path), hashOf([9, 8, 7]));
    expect(calculator.verifiedHashForPathSync(file.path), hashOf([9, 8, 7]));
  });

  test('registering a file that is already gone records nothing', () async {
    final missing = fileNamed('missing.png');

    await calculator.registerPathHash(missing.path, hashOf([1]));

    expect(calculator.getHashForPath(missing.path), isNull);
    expect(calculator.verifiedHashForPathSync(missing.path), isNull);
  });

  group('background hashing', () {
    final large = Uint8List.fromList(
      List.generate(
        FileHashCalculator.backgroundHashMinBytes,
        (index) => index * 31 & 0xff,
      ),
    );

    test('small byte arrays are hashed without the compute gate', () async {
      final release = holdSharedComputeGate();
      try {
        expect(
          await calculator.calculateFromBytesInBackground(
            Uint8List.fromList([1, 2, 3]),
          ),
          hashOf([1, 2, 3]),
        );
      } finally {
        await release();
      }
    });

    test('large byte arrays match the sync hash behind the gate', () async {
      final hash = await expectQueuedBehindSharedComputeGate(
        () => calculator.calculateFromBytesInBackground(large),
      );

      expect(hash, calculator.calculateFromBytes(large));
    });

    test('large files match the sync hash behind the gate', () async {
      final file = fileNamed('large.bin');
      await writeFile(file, large, modified: DateTime(2026, 9, 1));

      final hash = await expectQueuedBehindSharedComputeGate(
        () => calculator.calculate(file.path),
      );

      expect(hash, calculator.calculateFromBytes(large));
      expect(calculator.verifiedHashForPathSync(file.path), hash);
    });
  });

  test('a deleted file is not answered from its old mapping', () async {
    final file = fileNamed('deleted.bin');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));
    await calculator.calculate(file.path);

    await file.delete();

    expect(calculator.verifiedHashForPathSync(file.path), isNull);
    await expectLater(
      calculator.calculate(file.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}
