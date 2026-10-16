import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/data/services/metadata/hash_calculator.dart';

import '../../../helpers/content_hash.dart';
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

  String hashOf(List<int> bytes) => contentHashOf(bytes);

  Future<String> hashAt(String path) async =>
      (await calculator.snapshot(path)).hash;

  test('same-path overwrite of equal length yields the new hash', () async {
    final file = fileNamed('source.bin');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));
    expect(await hashAt(file.path), hashOf([1, 2, 3]));

    await writeFile(file, [4, 5, 6], modified: DateTime(2026, 9, 2));

    expect(await hashAt(file.path), hashOf([4, 5, 6]));
  });

  test('a size change is detected when the modified time is kept', () async {
    final file = fileNamed('source.bin');
    final modified = DateTime(2026, 9, 1);
    await writeFile(file, [1, 2, 3], modified: modified);
    await hashAt(file.path);

    await writeFile(file, [1, 2, 3, 4], modified: modified);

    expect(await hashAt(file.path), hashOf([1, 2, 3, 4]));
  });

  test('an unchanged file is answered from the path cache', () async {
    final file = fileNamed('stable.bin');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));

    final first = await hashAt(file.path);
    final second = await hashAt(file.path);

    expect(second, first);
    expect(calculator.hashComputeCount, 1);
    expect(calculator.hashCacheHitCount, 1);
  });

  test('a registered hash only holds while the file stays the same', () async {
    final file = fileNamed('saved.png');
    await writeFile(file, [7, 8, 9], modified: DateTime(2026, 9, 1));
    expect(
      await calculator.registerWrittenBytes(
        file.path,
        Uint8List.fromList([7, 8, 9]),
      ),
      hashOf([7, 8, 9]),
    );
    expect(calculator.verifiedHashForPathSync(file.path), hashOf([7, 8, 9]));
    expect(await calculator.verifiedHashForPath(file.path), hashOf([7, 8, 9]));

    await writeFile(file, [9, 8, 7], modified: DateTime(2026, 9, 2));

    expect(await calculator.verifiedHashForPath(file.path), isNull);
    expect(calculator.verifiedHashForPathSync(file.path), isNull);
    expect(await hashAt(file.path), hashOf([9, 8, 7]));
    expect(calculator.verifiedHashForPathSync(file.path), hashOf([9, 8, 7]));
  });

  test('registering a file that is already gone records nothing', () async {
    final missing = fileNamed('missing.png');

    await calculator.registerWrittenBytes(missing.path, Uint8List.fromList([1]));

    expect(calculator.getStatistics()['pathMappings'], 0);
  });

  test('a file replaced before registering keeps no mapping', () async {
    final file = fileNamed('saved.png');
    await writeFile(file, [1, 2, 3, 4], modified: DateTime(2026, 9, 1));

    final hash = await calculator.registerWrittenBytes(
      file.path,
      Uint8List.fromList([7, 8, 9]),
    );

    expect(hash, hashOf([7, 8, 9]));
    expect(calculator.getStatistics()['pathMappings'], 0);
  });

  test('a snapshot tells whether later reads still see the hashed file', () async {
    final file = fileNamed('source.png');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));
    final snapshot = await calculator.snapshot(file.path);
    expect(snapshot.hash, hashOf([1, 2, 3]));
    expect(await snapshot.isUnchanged(), isTrue);

    await writeFile(file, [4, 5, 6], modified: DateTime(2026, 9, 2));

    expect(await snapshot.isUnchanged(), isFalse);
  });

  test('a snapshot answered from the path cache keeps its identity', () async {
    final file = fileNamed('cached.png');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));
    await hashAt(file.path);

    final snapshot = await calculator.snapshot(file.path);
    expect(calculator.hashCacheHitCount, 1);
    expect(await snapshot.isUnchanged(), isTrue);

    await writeFile(file, [1, 2, 3, 4], modified: DateTime(2026, 9, 1));

    expect(await snapshot.isUnchanged(), isFalse);
  });

  group('background hashing', () {
    final large = Uint8List.fromList(
      List.generate(
        FileHashCalculator.backgroundHashMinBytes,
        (index) => index * 31 & 0xff,
      ),
    );

    test('small byte arrays are hashed without the compute gate', () async {
      final hash = await expectRunsWithoutComputeGate(
        ComputeGate(),
        () => calculator.calculateFromBytesInBackground(
          Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(hash, hashOf([1, 2, 3]));
    });

    test('large byte arrays match the sync hash behind the gate', () async {
      final hash = await expectQueuedBehindSharedComputeGate(
        () => calculator.calculateFromBytesInBackground(large),
      );

      expect(hash, contentHashOf(large));
    });

    test('large files match the sync hash behind the gate', () async {
      final file = fileNamed('large.bin');
      await writeFile(file, large, modified: DateTime(2026, 9, 1));

      final hash = await expectQueuedBehindSharedComputeGate(
        () => hashAt(file.path),
      );

      expect(hash, contentHashOf(large));
      expect(calculator.verifiedHashForPathSync(file.path), hash);
    });
  });

  test('a deleted file is not answered from its old mapping', () async {
    final file = fileNamed('deleted.bin');
    await writeFile(file, [1, 2, 3], modified: DateTime(2026, 9, 1));
    await hashAt(file.path);

    await file.delete();

    expect(calculator.verifiedHashForPathSync(file.path), isNull);
    await expectLater(
      hashAt(file.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}
