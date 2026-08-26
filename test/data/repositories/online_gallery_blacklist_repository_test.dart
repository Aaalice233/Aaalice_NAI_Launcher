import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_blacklist.dart';
import 'package:nai_launcher/data/repositories/online_gallery_blacklist_repository.dart';

void main() {
  test('normalizer creates stable simple-tag keys', () {
    expect(
      GalleryBlacklistTagNormalizer.normalize('  -Cloud  Tag  '),
      'cloud_tag',
    );
    expect(GalleryBlacklistTagNormalizer.normalize('rating:e'), isNull);
    expect(GalleryBlacklistTagNormalizer.normalize('~cat'), isNull);
    expect(GalleryBlacklistTagNormalizer.normalize('cat*'), isNull);
    expect(GalleryBlacklistTagNormalizer.normalize('*cat'), isNull);
    expect(
      GalleryBlacklistTagNormalizer.simpleCloudRule('furry -rating:g'),
      isNull,
    );
    expect(GalleryBlacklistTagNormalizer.simpleCloudRule('Simple Tag'), isNull);
    expect(
      GalleryBlacklistTagNormalizer.simpleCloudRule('simple_tag'),
      'simple_tag',
    );
  });

  test('migration unions legacy lists before writing V2', () async {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>[
        'local_tag',
        'same_tag',
      ]
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
        'cloud tag',
        'same_tag',
      ]
      ..values[StorageKeys.onlineGalleryBlacklistLastSyncAt] = 1234;
    final repository = OnlineGalleryBlacklistRepository(storage);

    final migrated = repository.load();
    expect(migrated.desiredTags, {'local_tag', 'cloud_tag', 'same_tag'});
    expect(migrated.legacyUnscopedLastSyncAt?.millisecondsSinceEpoch, 1234);

    await repository.save(migrated);
    final encoded = storage.values[StorageKeys.onlineGalleryBlacklistV2];
    expect(encoded, isA<String>());
    final persisted = GalleryBlacklistStore.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded! as String) as Map),
    );
    expect(persisted.desiredTags, migrated.desiredTags);
    expect(storage.values[StorageKeys.onlineGalleryBlacklistTags], [
      'cloud_tag',
      'local_tag',
      'same_tag',
    ]);
    expect(
      storage.values[StorageKeys.onlineGalleryRemoteBlacklistTags],
      isEmpty,
    );
  });

  test('rollback shadow cannot resurrect a stale cloud cache', () async {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
        'stale_cloud_tag',
      ];
    final repository = OnlineGalleryBlacklistRepository(storage);
    await repository.save(
      const GalleryBlacklistStore(
        desiredTags: {'kept_local_tag'},
        tombstones: {'deleted_tag'},
        pendingRemoteDeletions: {'deleted_tag'},
        legacyUnscopedRules: ['unknown_account_tag'],
      ),
    );
    storage.values[StorageKeys.onlineGalleryBlacklistV2] = '{broken';

    final recovered = repository.load();

    expect(recovered.desiredTags, {'kept_local_tag'});
    expect(recovered.tombstones, {'deleted_tag'});
    expect(recovered.pendingRemoteDeletions, {'deleted_tag'});
    expect(recovered.legacyUnscopedRules, ['unknown_account_tag']);
  });

  test('invalid V2 element types fall back to the complete shadow', () async {
    final storage = _MemoryStorage();
    final repository = OnlineGalleryBlacklistRepository(storage);
    await repository.save(
      const GalleryBlacklistStore(
        desiredTags: {'safe_tag'},
        tombstones: {'deleted_tag'},
        pendingRemoteDeletions: {'deleted_tag'},
      ),
    );
    final malformed =
        jsonDecode(
              storage.values[StorageKeys.onlineGalleryBlacklistV2]! as String,
            )
            as Map<String, dynamic>;
    malformed['desiredTags'] = <Object>[123];
    storage.values[StorageKeys.onlineGalleryBlacklistV2] = jsonEncode(
      malformed,
    );

    final loaded = repository.load();

    expect(loaded.desiredTags, {'safe_tag'});
    expect(loaded.tombstones, {'deleted_tag'});
    expect(loaded.pendingRemoteDeletions, {'deleted_tag'});
  });

  test('structurally invalid V2 falls back to the rollback shadow', () {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryBlacklistV2] = '{}'
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['safe_tag'];

    final loaded = OnlineGalleryBlacklistRepository(storage).load();

    expect(loaded.desiredTags, {'safe_tag'});
  });

  test('malformed V2 falls back to lossless legacy migration', () {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryBlacklistV2] = '{broken'
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['safe_tag'];

    final loaded = OnlineGalleryBlacklistRepository(storage).load();

    expect(loaded.desiredTags, {'safe_tag'});
  });

  test('remote snapshots are account scoped after serialization', () {
    final store = GalleryBlacklistStore(
      pendingRemoteDeletions: const {'pending_delete'},
      remoteSnapshots: {
        'danbooru:1': GalleryBlacklistRemoteSnapshot(
          accountKey: 'danbooru:1',
          rules: const ['one', 'furry -rating:g'],
          lastSyncAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        'danbooru:2': GalleryBlacklistRemoteSnapshot(
          accountKey: 'danbooru:2',
          rules: const ['two'],
          lastSyncAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
      },
    );

    final restored = GalleryBlacklistStore.fromJson(store.toJson());

    expect(restored.pendingRemoteDeletions, {'pending_delete'});
    expect(restored.remoteSnapshots['danbooru:1']?.simpleTags, {'one'});
    expect(restored.remoteSnapshots['danbooru:1']?.opaqueRules, [
      'furry -rating:g',
    ]);
    expect(restored.remoteSnapshots['danbooru:2']?.simpleTags, {'two'});
  });
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<void> setSettings(Map<String, Object?> updates) async {
    values.addAll(updates);
  }
}
