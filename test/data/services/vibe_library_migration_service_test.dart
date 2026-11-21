import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:hive_ce/src/adapters/date_time_adapter.dart';
// ignore: implementation_imports
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_file_storage_service.dart';
import 'package:nai_launcher/data/services/vibe_library_hive_repository.dart';
import 'package:nai_launcher/data/services/vibe_library_migration_service.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Repository extends Mock implements VibeLibraryRepositoryProtocol {}

const _entriesBoxName = HiveVibeLibraryRepository.entriesBoxName;
const _schemaVersionKey = 'vibe_library_schema_version';
const _inProgressKey = 'vibe_library_migration_in_progress';
const _backupDirKey = 'vibe_library_migration_backup_dir';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String hivePath;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('vibe_migration_test_');
    PathProviderPlatform.instance = _PathProvider(root.path);
    hivePath = p.join(root.path, 'support', 'hive');
  });

  tearDownAll(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  setUp(() async {
    Hive.init(hivePath);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    final directory = Directory(hivePath);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('rewriting the source table marks the display rows stale', () async {
    final box = await Hive.openLazyBox<VibeLibraryEntry>(
      HiveVibeLibraryRepository.entriesBoxName,
    );
    await box.close();
    final repository = _Repository();
    when(() => repository.setDisplayCacheReady(false)).thenAnswer((_) async {});

    final result = await VibeLibraryMigrationService(
      repository: repository,
    ).migrateIfNeeded();

    expect(result.success, isTrue);
    verify(() => repository.setDisplayCacheReady(false)).called(1);
    expect(
      Hive.box(StorageKeys.settingsBox).get('vibe_library_schema_version'),
      23,
    );
  });

  test('an up-to-date schema leaves the display rows alone', () async {
    await Hive.box(
      StorageKeys.settingsBox,
    ).put('vibe_library_schema_version', 23);
    final repository = _Repository();

    final result = await VibeLibraryMigrationService(
      repository: repository,
    ).migrateIfNeeded();

    expect(result.success, isTrue);
    verifyZeroInteractions(repository);
  });

  HiveInterface fixtureHive() => HiveImpl()
    ..init(hivePath)
    ..registerAdapter(LegacyVibeLibraryEntryV20Adapter())
    ..registerAdapter(VibeLibraryEntryAdapter());

  File entriesFile(String extension) =>
      File(p.join(hivePath, '$_entriesBoxName.$extension'));

  Future<List<Directory>> corruptBackups() async {
    final backupRoot = Directory(
      p.join(hivePath, 'vibe_library_migration_backup'),
    );
    return (await backupRoot.list().toList())
        .whereType<Directory>()
        .where((directory) => p.basename(directory.path).startsWith('corrupt_'))
        .toList();
  }

  VibeLibraryMigrationService migration(_RecordingFileStorage files) {
    final repository = _Repository();
    when(() => repository.setDisplayCacheReady(false)).thenAnswer((_) async {});
    return VibeLibraryMigrationService(
      repository: repository,
      fileStorage: files,
    );
  }

  for (final (version, stage, exportedCount) in <(int?, String, int)>[
    (null, 'export', 1),
    (null, 'verify', 2),
    (20, 'verify', 2),
  ]) {
    final name =
        'rollback restores converted Vibes after $stage, schema $version';
    test(name, () async {
      final settingsBox = Hive.box(StorageKeys.settingsBox);
      if (version != null) await settingsBox.put(_schemaVersionKey, version);
      final first = _legacyEntry('first');
      final second = _legacyEntry('second');
      await _writeEntries(fixtureHive(), {first.id: first, second.id: second});
      final lockFile = await entriesFile('lock').writeAsString('stale lock');
      final crcFile = await entriesFile('crc').writeAsString('original crc');
      final snapshots = {
        for (final file in [entriesFile('hive'), lockFile, crcFile])
          p.basename(file.path): await file.readAsBytes(),
      };
      final files = _RecordingFileStorage(hivePath);

      final result = await migration(files).migrateIfNeeded(
        onProgress: (progress) {
          if (progress.stage == stage &&
              (stage != 'export' || progress.current == 2)) {
            throw StateError('injected failure after conversion');
          }
        },
      );

      expect(result.success, isFalse);
      expect(result.error, contains('injected failure after conversion'));
      expect(Hive.isBoxOpen(_entriesBoxName), isFalse);
      for (final snapshot in snapshots.entries) {
        expect(
          await File(p.join(hivePath, snapshot.key)).readAsBytes(),
          snapshot.value,
          reason: '${snapshot.key} is restored from the backup',
        );
      }
      expect(
        await Directory(hivePath).list().any(
          (entity) => entity.path.endsWith('.restore'),
        ),
        isFalse,
      );
      expect(result.backupPath, isNotNull);
      expect(await Directory(result.backupPath!).exists(), isTrue);
      expect(settingsBox.get(_backupDirKey), result.backupPath);
      expect(files.exports, hasLength(exportedCount));
      for (final file in files.exports) {
        expect(await file.exists(), isFalse);
      }
      expect(settingsBox.get(_schemaVersionKey), version);
      expect(settingsBox.containsKey(_schemaVersionKey), version != null);
      expect(settingsBox.get(_inProgressKey), isFalse);
      final box = await Hive.openLazyBox<LegacyVibeLibraryEntryV20>(
        _entriesBoxName,
      );
      expect(box.keys, unorderedEquals([first.id, second.id]));
      expect((await box.get(first.id))?.vibeEncoding, first.vibeEncoding);
      expect((await box.get(second.id))?.vibeEncoding, second.vibeEncoding);
    });
  }

  test('first export failure leaves the Hive entries file untouched', () async {
    final legacy = _legacyEntry('first');
    await _writeEntries(fixtureHive(), {legacy.id: legacy});
    final source = entriesFile('hive');
    final before = await source.readAsBytes();
    final blockedExportPath = p.join(hivePath, 'blocked-export');
    await File(blockedExportPath).create();
    final settingsBox = Hive.box(StorageKeys.settingsBox);
    await settingsBox.put(StorageKeys.vibeLibrarySavePath, blockedExportPath);
    final repository = _Repository();
    when(() => repository.setDisplayCacheReady(false)).thenAnswer((_) async {});

    final result = await VibeLibraryMigrationService(
      repository: repository,
    ).migrateIfNeeded(
      onProgress: (progress) {
        if (progress.stage == 'backup' && progress.current == 1) {
          final backupPath = settingsBox.get(_backupDirKey) as String;
          // An empty backup makes an unexpected restore visible in the source.
          File(p.join(backupPath, p.basename(source.path))).writeAsBytesSync([]);
        }
      },
    );

    expect(result.success, isFalse);
    expect(await source.readAsBytes(), before);
  });

  test('interrupted migration converts only the remaining old Vibe', () async {
    final converted = _currentEntry(p.join(root.path, 'existing.naiv4vibe'));
    final legacy = _legacyEntry('remaining');
    await _writeEntries(fixtureHive(), {
      converted.id: converted,
      'old-key': legacy,
    });
    final settingsBox = Hive.box(StorageKeys.settingsBox);
    await settingsBox.put(_inProgressKey, true);
    final files = _RecordingFileStorage(hivePath);

    final result = await migration(files).migrateIfNeeded();

    expect(result.success, isTrue, reason: result.error);
    expect(result.exportedCount, 1);
    expect(files.exports, hasLength(1));
    expect(await files.exports.single.readAsString(), legacy.vibeEncoding);
    expect(settingsBox.get(_schemaVersionKey), 23);
    expect(settingsBox.get(_inProgressKey), isFalse);
    final box = await Hive.openLazyBox<VibeLibraryEntry>(_entriesBoxName);
    expect(box.keys, unorderedEquals([converted.id, legacy.id]));
    expect(await box.get(converted.id), converted);
    final migrated = (await box.get(legacy.id))!;
    expect(migrated.vibeEncoding, legacy.vibeEncoding);
    expect(migrated.tags, legacy.tags);
    expect(migrated.filePath, files.exports.single.path);
  });

  test('cold start preserves current Vibes without a version', () async {
    final entry = _currentEntry(p.join(root.path, 'existing.naiv4vibe'));
    await _writeEntries(fixtureHive(), {entry.id: entry});
    Hive.resetAdapters();
    // Resetting the registry also removes the built-in DateTime adapter.
    Hive.registerAdapter(DateTimeWithTimezoneAdapter(), internal: true);
    expect(Hive.isAdapterRegistered(23), isFalse);
    final source = entriesFile('hive');
    final before = await source.readAsBytes();
    final files = _RecordingFileStorage(hivePath);

    final result = await migration(files).migrateIfNeeded();

    expect(result.success, isTrue, reason: result.error);
    expect(await corruptBackups(), isEmpty);
    expect(await source.readAsBytes(), before);
    expect(result.exportedCount, 0);
    expect(files.exports, isEmpty);
    expect(Hive.box(StorageKeys.settingsBox).get(_schemaVersionKey), 23);
    final box = await Hive.openLazyBox<VibeLibraryEntry>(_entriesBoxName);
    expect(box.keys, [entry.id]);
    expect(await box.get(entry.id), entry);
  });

  test('unknown Vibe type IDs still use the corrupt backup', () async {
    final fixture = HiveImpl()
      ..init(hivePath)
      ..registerAdapter(_UnknownVibeEntryAdapter());
    final entry = _legacyEntry('unknown');
    await _writeEntries(fixture, {entry.id: entry});
    final source = entriesFile('hive');
    final before = await source.readAsBytes();
    final files = _RecordingFileStorage(hivePath);

    final result = await migration(files).migrateIfNeeded();

    expect(result.success, isTrue, reason: result.error);
    expect(result.exportedCount, 0);
    expect(files.exports, isEmpty);
    expect(await source.exists(), isFalse);
    final backup = (await corruptBackups()).single;
    expect(
      await File(p.join(backup.path, p.basename(source.path))).readAsBytes(),
      before,
    );
    expect(Hive.box(StorageKeys.settingsBox).get(_schemaVersionKey), 23);
  });
}

Future<void> _writeEntries(
  HiveInterface fixture,
  Map<String, Object> entries,
) async {
  final box = await fixture.openLazyBox<dynamic>(_entriesBoxName);
  try {
    await box.putAll(entries);
  } finally {
    await box.close();
  }
}

LegacyVibeLibraryEntryV20 _legacyEntry(String id) => LegacyVibeLibraryEntryV20(
  id: id,
  name: id,
  vibeDisplayName: id,
  vibeEncoding: '$id-encoding',
  vibeThumbnail: null,
  rawImageData: null,
  strength: 0.4,
  infoExtracted: 0.7,
  sourceTypeIndex: VibeSourceType.naiv4vibe.index,
  categoryId: 'legacy-category',
  tags: const ['legacy'],
  isFavorite: true,
  usedCount: 2,
  lastUsedAt: null,
  createdAt: DateTime.utc(2026),
  thumbnail: null,
);

VibeLibraryEntry _currentEntry(String filePath) => VibeLibraryEntry(
  id: 'current',
  name: 'already converted',
  vibeDisplayName: 'Already converted',
  vibeEncoding: 'current-encoding',
  encodingModel: 'nai-diffusion-4-full',
  strength: 0.5,
  infoExtracted: 0.7,
  sourceTypeIndex: VibeSourceType.naiv4vibe.index,
  categoryId: 'category',
  tags: const ['keep'],
  isFavorite: true,
  usedCount: 3,
  createdAt: DateTime.utc(2026),
  filePath: filePath,
);

class _RecordingFileStorage extends VibeFileStorageService {
  _RecordingFileStorage(this.directory);

  final String directory;
  final exports = <File>[];

  @override
  Future<String> saveVibeToFile(
    VibeReference vibe, {
    String? customName,
    String? defaultModel,
  }) async {
    final file = await File(
      p.join(directory, '$customName.naiv4vibe'),
    ).writeAsString(vibe.vibeEncoding);
    exports.add(file);
    return file.path;
  }
}

class _UnknownVibeEntryAdapter extends LegacyVibeLibraryEntryV20Adapter {
  @override
  int get typeId => 200;
}

class _PathProvider extends PathProviderPlatform {
  _PathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => p.join(root, 'support');

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root, 'documents');
}
