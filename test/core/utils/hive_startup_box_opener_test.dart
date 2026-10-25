import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/utils/hive_startup_box_opener.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('nai_hive_startup_');
    Hive.init(hiveDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test(
    'recovers a failed startup box by backing it up and opening a new box',
    () async {
      final staleBoxFile = File(
        p.join(hiveDir.path, '${StorageKeys.galleryBox}.hive'),
      );
      await staleBoxFile.writeAsBytes(List<int>.generate(128, (i) => i));

      var attempts = 0;

      final result = await HiveStartupBoxOpener.openBox(
        StorageKeys.galleryBox,
        hivePath: hiveDir.path,
        openBoxOverride: () async {
          attempts++;
          if (attempts == 1) {
            throw HiveError('injected startup open failure');
          }
          await Hive.openBox(StorageKeys.galleryBox);
        },
      );

      expect(attempts, 2);
      expect(result.recovered, isTrue);
      expect(Hive.isBoxOpen(StorageKeys.galleryBox), isTrue);

      final box = Hive.box(StorageKeys.galleryBox);
      await box.put('probe', 'ok');
      expect(box.get('probe'), 'ok');

      final backupRoot = Directory(
        p.join(hiveDir.path, HiveStartupBoxOpener.recoveryBackupDirectoryName),
      );
      final backedUpHiveFiles = await backupRoot
          .list(recursive: true)
          .where(
            (entity) =>
                entity is File &&
                p.basename(entity.path) == '${StorageKeys.galleryBox}.hive',
          )
          .toList();

      expect(backedUpHiveFiles, hasLength(1));
      expect(
        await (backedUpHiveFiles.single as File).readAsBytes(),
        List<int>.generate(128, (i) => i),
      );
    },
  );

  test(
    'lazy startup boxes reopen existing data without loading values',
    () async {
      final seeded = await Hive.openBox<dynamic>(StorageKeys.historyBox);
      await seeded.put('probe', 'ok');
      await seeded.close();

      final result = await HiveStartupBoxOpener.openLazyBox<dynamic>(
        StorageKeys.historyBox,
        hivePath: hiveDir.path,
      );

      expect(result.recovered, isFalse);
      expect(
        () => Hive.box<dynamic>(StorageKeys.historyBox),
        throwsA(isA<HiveError>()),
      );
      final box = Hive.lazyBox<dynamic>(StorageKeys.historyBox);
      expect(await box.get('probe'), 'ok');
    },
  );

  test('lazy startup boxes share the backup-and-retry recovery', () async {
    await File(
      p.join(hiveDir.path, '${StorageKeys.historyBox}.hive'),
    ).writeAsBytes(List<int>.generate(64, (i) => i));
    var attempts = 0;

    final result = await HiveStartupBoxOpener.openLazyBox<dynamic>(
      StorageKeys.historyBox,
      hivePath: hiveDir.path,
      openBoxOverride: () async {
        attempts++;
        if (attempts == 1) {
          throw HiveError('injected startup open failure');
        }
        await Hive.openLazyBox<dynamic>(StorageKeys.historyBox);
      },
    );

    expect(attempts, 2);
    expect(result.recovered, isTrue);
    expect(result.backupDirectory, isNotNull);
    expect(Hive.lazyBox<dynamic>(StorageKeys.historyBox).isOpen, isTrue);
  });
}
