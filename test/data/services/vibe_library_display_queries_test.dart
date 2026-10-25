import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/utils/vibe_library_path_helper.dart';
import 'package:nai_launcher/data/cloud_sync/vibe_library_cloud_sync_adapter.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_display_cache_repository.dart';
import 'package:nai_launcher/data/services/vibe_library_hive_repository.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _entriesBox = HiveVibeLibraryRepository.entriesBoxName;
const _displayBox = HiveVibeLibraryRepository.displayEntriesBoxName;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;
  late _ScriptedRepository repository;
  late VibeLibraryStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    hiveTempDir = await Directory.systemTemp.createTemp(
      'vibe_library_display_queries_test_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    repository = _ScriptedRepository();
    storage = VibeLibraryStorageService(repository: repository);
  });

  tearDown(() async {
    await storage.close();
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  void expectSourceTableStaysLazy() {
    expect(Hive.isBoxOpen(_entriesBox), isTrue);
    expect(
      () => Hive.box<VibeLibraryEntry>(_entriesBox),
      throwsA(isA<HiveError>()),
    );
    expect(Hive.lazyBox<VibeLibraryEntry>(_entriesBox).isOpen, isTrue);
  }

  Set<String> ids(Iterable<VibeLibraryEntry> entries) =>
      entries.map((entry) => entry.id).toSet();

  Future<void> reopenStorage() async {
    await storage.close();
    repository = _ScriptedRepository();
    storage = VibeLibraryStorageService(repository: repository);
    await storage.init();
  }

  test('full reads and scans never open the source table eagerly', () async {
    await storage.saveEntry(_entry('a'));
    await storage.saveEntry(_entry('b'));

    final all = await storage.getAllEntries();
    expect(all.map((entry) => entry.vibeEncoding), [
      'encoding-a',
      'encoding-b',
    ]);
    expect((await repository.readEntry('a'))?.rawImageData, isNotNull);
    expect(await storage.entryExists('b'), isTrue);
    expect(await storage.findEntryByName('B'), isNotNull);
    expect(await storage.getEntriesCount(), 2);

    expectSourceTableStaysLazy();
  });

  test(
    'entry queries answer from display rows with the source semantics',
    () async {
      await storage.saveEntry(
        _entry(
          'a',
          name: 'Sunset Glow',
          tags: const ['warm'],
          favorite: true,
          usedCount: 5,
          lastUsedAt: DateTime(2026, 10, 2),
          categoryId: 'c1',
        ),
      );
      await storage.saveEntry(
        _entry(
          'b',
          displayName: 'Night Sky',
          tags: const ['cool', 'Warm'],
          usedCount: 9,
          lastUsedAt: DateTime(2026, 10, 3),
          categoryId: 'c1',
        ),
      );
      await storage.saveEntry(_entry('c', name: 'plain', usedCount: 1));

      expect(ids(await storage.searchEntries('SKY')), {'b'});
      expect(ids(await storage.searchEntries('warm')), {'a', 'b'});
      expect(ids(await storage.searchEntries('')), {'a', 'b', 'c'});
      expect(ids(await storage.getFavoriteEntries()), {'a'});
      expect(
        (await storage.getRecentEntries(limit: 1)).map((entry) => entry.id),
        ['b'],
      );
      expect(ids(await storage.getEntriesByCategory('c1')), {'a', 'b'});
      expect(ids(await storage.getEntriesByCategory(null)), {'c'});
      expect(await storage.getEntriesCountByCategory('c1'), 2);
      expect(await storage.getEntriesCountByCategory(null), 1);
      expect(await storage.getEntriesCount(), 3);
      expect(await storage.getAllTags(), {'warm', 'cool', 'Warm'});
      expect(ids(await storage.getEntriesByTag('cool')), {'b'});
      expect(
        (await storage.getEntriesByUsage(limit: 2)).map((entry) => entry.id),
        ['b', 'a'],
      );

      final listed = await storage.getEntriesByCategory('c1');
      expect(listed.map((entry) => entry.vibeEncoding), everyElement(isEmpty));
      expect(listed.map((entry) => entry.rawImageData), everyElement(isNull));
      expectSourceTableStaysLazy();
    },
  );

  test('ready display queries leave the source table closed', () async {
    await storage.saveEntry(_entry('a'));
    await storage.getDisplayEntries();
    await reopenStorage();

    expect(await repository.isDisplayCacheReady(), isTrue);
    expect(ids(await storage.getDisplayEntries()), {'a'});
    expect(ids(await storage.getEntriesByCategory(null)), {'a'});
    expect(repository.entryKeyReads, 0);
    expect(repository.rebuildScans, 0);
    expect(repository.entryReads, 0);
    expect(Hive.isBoxOpen(_entriesBox), isFalse);
  });

  test('folder refresh rebuilds missing and ghost display rows', () async {
    await VibeLibraryPathHelper.instance.setPath('${hiveTempDir.path}/vibes');
    addTearDown(VibeLibraryPathHelper.instance.resetToDefault);
    await repository.putEntry(_entry('a').copyWith(filePath: null));
    await repository.putEntry(_entry('b').copyWith(filePath: null));
    expect(ids(await storage.getDisplayEntries()), {'a', 'b'});

    final source = Hive.lazyBox<VibeLibraryEntry>(_entriesBox);
    await source.delete('b');
    await source.put('d', _entry('d').copyWith(filePath: null));
    await reopenStorage();
    expect(ids(await storage.getDisplayEntries()), {'a', 'b'});

    expect((await storage.syncWithFileSystem()).errors, isEmpty);
    expect(ids(await storage.getDisplayEntries()), {'a', 'd'});

    final scans = repository.rebuildScans;
    expect((await storage.syncWithFileSystem()).errors, isEmpty);
    expect(repository.rebuildScans, scans + 1);
  });

  test('a failed rebuild scan keeps the ready display rows readable', () async {
    await storage.saveEntry(_entry('a'));
    await storage.saveEntry(_entry('b'));
    final cache = VibeDisplayCacheRepository(repository);
    expect(ids(await cache.getEntries()), {'a', 'b'});
    repository.failNextScan = true;

    await expectLater(cache.rebuild(), throwsStateError);

    expect(await repository.isDisplayCacheReady(), isTrue);
    expect(ids(await cache.getEntries()), {'a', 'b'});
  });

  test('a failed display mirror marks the cache stale until rebuilt', () async {
    await storage.saveEntry(_entry('a'));
    expect((await storage.getDisplayEntries()).single.isFavorite, isFalse);
    repository.failNextDisplayUpsert = true;

    await expectLater(storage.toggleFavorite('a'), throwsStateError);

    expect(await repository.isDisplayCacheReady(), isFalse);
    expect((await storage.getDisplayEntries()).single.isFavorite, isTrue);
    expect(await repository.isDisplayCacheReady(), isTrue);
  });

  test(
    'writes racing a display rebuild still land in the rebuilt rows',
    () async {
      for (final id in ['a', 'b', 'c']) {
        await storage.saveEntry(_entry(id));
      }
      expect(await repository.isDisplayCacheReady(), isFalse);
      final paused = repository.pauseNextRebuild();

      final rebuild = storage.getDisplayEntries();
      await paused.reached;
      // 'a' 已在暂停前读出旧值；'d' 不在重建的键快照里；'c' 在快照里但已删除
      final writes = [
        storage.toggleFavorite('a'),
        storage.saveEntry(_entry('d')),
        storage.deleteEntry('c'),
      ];
      await repository.sourceWritesSettled(puts: {'a', 'd'}, deletes: {'c'});
      paused.resume();
      await rebuild;
      await Future.wait(writes);

      final rows = await storage.getDisplayEntries();
      expect(ids(rows), {'a', 'b', 'd'});
      expect(rows.firstWhere((entry) => entry.id == 'a').isFavorite, isTrue);
    },
  );

  test('concurrent display reads share one rebuild', () async {
    await storage.saveEntry(_entry('a'));
    await storage.saveEntry(_entry('b'));

    final reads = await Future.wait([
      storage.getDisplayEntries(),
      storage.getRecentDisplayEntries(),
      storage.searchEntries(''),
    ]);

    expect(ids(reads.first), {'a', 'b'});
    expect(repository.rebuildScans, 1);
  });

  test('deleting a category uses current membership from the source', () async {
    final parent = VibeLibraryCategory(
      id: 'parent',
      name: 'Parent',
      createdAt: DateTime(2026),
    );
    final category = VibeLibraryCategory(
      id: 'c1',
      name: 'Category',
      parentId: parent.id,
      createdAt: DateTime(2026),
    );
    await storage.saveCategory(parent);
    await storage.saveCategory(category);
    await storage.saveEntry(_entry('a', categoryId: 'c1'));
    await storage.saveEntry(_entry('b', categoryId: 'c1'));
    await storage.saveEntry(_entry('c', categoryId: 'other'));
    expect(ids(await storage.getEntriesByCategory('c1')), {'a', 'b'});
    await repository.putEntry(_entry('b', categoryId: 'other'));
    await repository.putEntry(_entry('c', categoryId: 'c1'));

    expect(await storage.deleteCategory('c1'), isTrue);

    final source = Hive.lazyBox<VibeLibraryEntry>(_entriesBox);
    expect((await source.get('a'))?.categoryId, 'parent');
    expect((await source.get('b'))?.categoryId, 'other');
    expect((await source.get('c'))?.categoryId, 'parent');
    expect(await storage.getCategory('c1'), isNull);
    expectSourceTableStaysLazy();
  });

  test(
    'folder refresh keeps the renamed entry when its display path is stale',
    () async {
      final vibeDirectory = '${hiveTempDir.path}/vibes_renamed';
      await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
      addTearDown(VibeLibraryPathHelper.instance.resetToDefault);

      final saved = await storage.saveEntry(
        _entry(
          'kept',
          categoryId: 'category',
          tags: ['tag'],
          favorite: true,
        ).copyWith(filePath: null),
      );
      expect(
        (await storage.getDisplayEntries()).single.filePath,
        saved.filePath,
      );

      final renamed = await File(
        saved.filePath!,
      ).rename('$vibeDirectory/renamed.naiv4vibe');
      await repository.putEntry(
        saved.copyWith(name: 'renamed', filePath: renamed.path),
      );
      await reopenStorage();
      expect(
        Hive.box<VibeLibraryEntry>(_displayBox).get(saved.id)?.filePath,
        saved.filePath,
      );

      final result = await storage.syncWithFileSystem();

      expect(result.errors, isEmpty);
      expect(result.deletedCount, 0);
      final source = Hive.lazyBox<VibeLibraryEntry>(_entriesBox);
      expect(source.keys, [saved.id]);
      final refreshed = (await source.get(saved.id))!;
      expect(refreshed.categoryId, 'category');
      expect(refreshed.tags, ['tag']);
      expect(refreshed.isFavorite, isTrue);
      expectSourceTableStaysLazy();
    },
  );

  test(
    'cloud export reads current metadata even with stale display values',
    () async {
      final file = await File(
        '${hiveTempDir.path}/kept.naiv4vibe',
      ).writeAsBytes([1, 2, 3, 4]);
      final entry = _entry(
        'kept',
        categoryId: 'category',
        tags: ['tag'],
        usedCount: 3,
      ).copyWith(filePath: file.path);
      await storage.saveEntry(entry);
      await repository.putEntry(_entry('fileless').copyWith(filePath: null));
      final legacyFile = await File(
        '${hiveTempDir.path}/legacy.naiv4vibe',
      ).writeAsBytes([5, 6]);
      await Hive.lazyBox<VibeLibraryEntry>(
        _entriesBox,
      ).put(7, _entry('legacy').copyWith(filePath: legacyFile.path));
      await storage.getDisplayEntries();
      await repository.putEntry(entry.copyWith(isFavorite: true));
      await reopenStorage();
      expect(
        Hive.box<VibeLibraryEntry>(_displayBox).get(entry.id)?.isFavorite,
        isFalse,
      );

      final records = await VibeLibraryCloudSyncAdapter(
        storage,
      ).exportRecords().toList();

      final byId = {for (final record in records) record.id: record};
      expect(byId.keys, {'entry:kept', 'entry:legacy'});
      final record = byId['entry:kept']!;
      expect(record.data['categoryId'], 'category');
      expect(record.data['tags'], ['tag']);
      expect(record.data['isFavorite'], isTrue);
      expect(record.data['usedCount'], 3);
      expect(record.data['fileName'], 'kept.naiv4vibe');
      expect(record.resource!.length, 4);
      expect(byId['entry:legacy']!.resource!.length, 2);
      expect(repository.rebuildScans, 0);
      expectSourceTableStaysLazy();
    },
  );

  test(
    'folder refresh repairs stale display fields without rewriting unchanged entries',
    () async {
      final vibeDirectory =
          '${hiveTempDir.path}${Platform.pathSeparator}vibes_refresh';
      await VibeLibraryPathHelper.instance.setPath(vibeDirectory);
      addTearDown(VibeLibraryPathHelper.instance.resetToDefault);

      final saved = await storage.saveEntry(
        VibeLibraryEntry.fromVibeReference(
          name: 'refresh',
          vibeData: VibeReference(
            displayName: 'refresh',
            vibeEncoding: 'file-encoding',
            thumbnail: Uint8List.fromList([1, 2, 3]),
            sourceType: VibeSourceType.naiv4vibe,
          ),
          categoryId: 'kept-category',
        ),
      );
      final custom = Uint8List.fromList(
        img.encodePng(img.Image(width: 2, height: 2)),
      );
      await storage.updateEntryThumbnail(saved.id, custom);
      await storage.getDisplayEntries();

      final result = await storage.syncWithFileSystem();

      expect(result.errors, isEmpty);
      expect(result.upsertedCount + result.unchangedCount, 1);
      expect(result.deletedCount, 0);
      final source = Hive.lazyBox<VibeLibraryEntry>(_entriesBox);
      final refreshed = (await source.get(saved.id))!;
      expect(refreshed.thumbnail, custom);
      expect(refreshed.categoryId, 'kept-category');
      expect(ids(await storage.getDisplayEntries()), {saved.id});
      expectSourceTableStaysLazy();

      expect(await storage.getDisplayThumbnail(saved.id), isNotNull);
      expect(await repository.readThumbnail(saved.id), isNotNull);
      await repository.putEntry(refreshed.copyWith(isFavorite: true));
      final display = Hive.box<VibeLibraryEntry>(_displayBox);
      expect(display.get(saved.id)?.isFavorite, isFalse);
      final writesBefore = repository.putCount;

      final second = await storage.syncWithFileSystem();

      expect(second.errors, isEmpty);
      expect(second.upsertedCount, 0);
      expect(second.unchangedCount, 1);
      expect(repository.putCount, writesBefore);
      expect(display.get(saved.id)?.isFavorite, isTrue);
      expect(await repository.readThumbnail(saved.id), isNotNull);
      expect((await source.get(saved.id))?.thumbnail, custom);
    },
  );
}

VibeLibraryEntry _entry(
  String id, {
  String? name,
  String? displayName,
  String? categoryId,
  List<String> tags = const [],
  bool favorite = false,
  int usedCount = 0,
  DateTime? lastUsedAt,
}) => VibeLibraryEntry(
  id: id,
  name: name ?? id,
  vibeDisplayName: displayName ?? id,
  vibeEncoding: 'encoding-$id',
  rawImageData: Uint8List.fromList([1, 2, 3]),
  strength: 0.6,
  infoExtracted: 0.7,
  sourceTypeIndex: VibeSourceType.naiv4vibe.index,
  categoryId: categoryId,
  tags: tags,
  isFavorite: favorite,
  usedCount: usedCount,
  lastUsedAt: lastUsedAt,
  createdAt: DateTime(2026, 10, 25),
  filePath: 'C:/vibes/missing/$id.naiv4vibe',
);

class _PausedRebuild {
  final _reached = Completer<void>();
  final _resume = Completer<void>();

  Future<void> get reached => _reached.future;
  void resume() => _resume.complete();
}

class _ScriptedRepository extends HiveVibeLibraryRepository {
  bool failNextDisplayUpsert = false;
  bool failNextScan = false;
  int entryKeyReads = 0;
  int entryReads = 0;
  int rebuildScans = 0;
  _PausedRebuild? _pause;
  final _putIds = <String>{};
  final _deletedIds = <String>{};
  final _sourceWrites = StreamController<void>.broadcast();

  _PausedRebuild pauseNextRebuild() {
    _putIds.clear();
    _deletedIds.clear();
    return _pause = _PausedRebuild();
  }

  Future<void> sourceWritesSettled({
    required Set<String> puts,
    required Set<String> deletes,
  }) async {
    bool settled() =>
        _putIds.containsAll(puts) && _deletedIds.containsAll(deletes);
    while (!settled()) {
      await _sourceWrites.stream.first;
    }
  }

  int putCount = 0;

  @override
  Future<void> putEntry(VibeLibraryEntry entry) async {
    await super.putEntry(entry);
    putCount++;
    _putIds.add(entry.id);
    _sourceWrites.add(null);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await super.deleteEntry(id);
    _deletedIds.add(id);
    _sourceWrites.add(null);
  }

  @override
  Future<Set<String>> readEntryIds() {
    entryKeyReads++;
    return super.readEntryIds();
  }

  @override
  Future<VibeLibraryEntry?> readEntry(String id) {
    entryReads++;
    return super.readEntry(id);
  }

  @override
  Future<void> upsertDisplayEntryIfReady(VibeLibraryEntry entry) {
    if (failNextDisplayUpsert) {
      failNextDisplayUpsert = false;
      throw StateError('display write failed');
    }
    return super.upsertDisplayEntryIfReady(entry);
  }

  @override
  Future<void> forEachEntry(
    Future<void> Function(VibeLibraryEntry entry) visit,
  ) {
    rebuildScans++;
    if (failNextScan) {
      failNextScan = false;
      return super.forEachEntry((entry) async {
        await visit(entry);
        throw StateError('source scan failed');
      });
    }
    final pause = _pause;
    _pause = null;
    if (pause == null) return super.forEachEntry(visit);
    var first = true;
    return super.forEachEntry((entry) async {
      if (first) {
        first = false;
        pause._reached.complete();
        await pause._resume.future;
      }
      await visit(entry);
    });
  }
}
