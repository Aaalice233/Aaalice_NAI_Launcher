import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_blacklist.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/data/repositories/online_gallery_blacklist_repository.dart';

class _TrackingAdapter extends ValidatingCloudSyncDataAdapter {
  _TrackingAdapter(this.id, {this.reject = false});

  @override
  final String id;
  final bool reject;
  var mutations = 0;
  var preflights = 0;

  @override
  Set<String> get allowedKinds => const {'item'};

  @override
  Stream<PortableSyncRecord> exportRecords() => const Stream.empty();

  @override
  Future<void> preflight(List<PortableSyncRecord> records) async {
    preflights += records.length;
    await super.preflight(records);
    if (reject) throw const CloudSyncPreflightException('rejected');
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    mutations += records.length;
  }
}

void main() {
  test('registry finishes every preflight before any mutation', () async {
    final first = _TrackingAdapter('first');
    final second = _TrackingAdapter('second', reject: true);
    final registry = CloudSyncDataAdapterRegistry([first, second]);
    final records = [
      PortableSyncRecord(adapterId: 'first', id: 'a', kind: 'item'),
      PortableSyncRecord(adapterId: 'second', id: 'b', kind: 'item'),
    ];

    await expectLater(
      registry.apply(records),
      throwsA(isA<CloudSyncPreflightException>()),
    );
    expect(first.mutations, 0);
  });

  test(
    'registry refreshes applied adapter state after every mutation',
    () async {
      final first = _TrackingAdapter('first');
      final second = _TrackingAdapter('second');
      Set<String>? refreshed;
      final registry = CloudSyncDataAdapterRegistry([
        first,
        second,
      ], afterApply: (adapterIds) async => refreshed = adapterIds);

      await registry.apply([
        PortableSyncRecord(adapterId: 'first', id: 'a', kind: 'item'),
        PortableSyncRecord(adapterId: 'second', id: 'b', kind: 'item'),
      ]);

      expect(refreshed, {'first', 'second'});
      expect(first.mutations, 1);
      expect(second.mutations, 1);
    },
  );

  test('secret-looking fields are rejected recursively', () async {
    final adapter = _TrackingAdapter('safe');
    final record = PortableSyncRecord(
      adapterId: 'safe',
      id: 'record',
      kind: 'item',
      data: const {
        'nested': {'apiKey': 'must-not-sync'},
      },
    );
    await expectLater(
      adapter.preflight([record]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });

  test('registry preflights every exported record before capture', () async {
    final adapter = _ExportingAdapter([
      PortableSyncRecord(
        adapterId: 'exporter',
        id: 'safe',
        kind: 'item',
        data: const {
          'nested': {'label': 'safe'},
        },
      ),
    ]);
    final records = await CloudSyncDataAdapterRegistry([
      adapter,
    ]).exportRecords().toList();

    expect(records, hasLength(1));
    expect(adapter.preflights, 1);
  });

  test('registry rejects nested secrets even for a permissive adapter', () {
    final adapter = _PermissiveExportAdapter(
      PortableSyncRecord(
        adapterId: 'permissive',
        id: 'unsafe',
        kind: 'item',
        data: const {
          'accounts': [
            {
              'profile': {'password': 'must-not-upload'},
            },
          ],
        },
      ),
    );

    expect(
      CloudSyncDataAdapterRegistry([adapter]).exportRecords().toList(),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });

  test('settings adapter uses an explicit allowlist and round-trips', () async {
    final directory = await Directory.systemTemp.createTemp('sync-settings-');
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    final storage = LocalStorageService();
    await storage.setSetting(StorageKeys.locale, 'ja');
    await storage.setSetting(StorageKeys.accessToken, 'secret-token');
    await storage.setSetting(StorageKeys.imageSavePath, 'D:/private');
    await storage.setSetting(
      StorageKeys.watermarkConfigV1,
      const WatermarkSettings(enabled: true).encode(),
    );
    await storage.setSetting(
      StorageKeys.watermarkLogoPathV1,
      'D:/private/logo.png',
    );
    final adapter = SettingsCloudSyncAdapter(storage);

    final records = await adapter.exportRecords().toList();
    expect(records.map((record) => record.id), contains(StorageKeys.locale));
    expect(
      records.map((record) => record.id),
      isNot(contains(StorageKeys.accessToken)),
    );
    expect(
      records.map((record) => record.id),
      isNot(contains(StorageKeys.imageSavePath)),
    );
    expect(
      records.map((record) => record.id),
      contains(StorageKeys.watermarkConfigV1),
    );
    expect(
      records.map((record) => record.id),
      isNot(contains(StorageKeys.watermarkLogoPathV1)),
    );
    expect(records.every((record) => record.resource == null), isTrue);

    await storage.setSetting(StorageKeys.locale, 'en');
    await storage.deleteSetting(StorageKeys.watermarkConfigV1);
    await adapter.apply(records);
    expect(storage.getSetting<String>(StorageKeys.locale), 'ja');
    expect(
      WatermarkSettings.decode(
        storage.getSetting<String>(StorageKeys.watermarkConfigV1),
      ).settings.enabled,
      isTrue,
    );
  });

  test('portable preferences and explicit exclusions stay classified', () {
    expect(portableSettingKeys, contains(StorageKeys.defaultModel));
    expect(portableSettingKeys, contains(StorageKeys.watermarkConfigV1));
    expect(
      portableSettingKeys,
      isNot(contains(StorageKeys.watermarkLogoPathV1)),
    );
    expect(
      portableSettingKeys,
      contains(StorageKeys.autocompleteOpenOnTagClick),
    );
    expect(
      portableSettingKeys,
      isNot(contains(StorageKeys.quickTagCloudBrowsingFiltersV1)),
    );
    expect(
      portableOnlineGallerySettingKeys,
      contains(StorageKeys.quickTagCloudBrowsingFiltersV1),
    );
    expect(
      portableOnlineGallerySettingKeys,
      contains(StorageKeys.quickTagCloudContentAccessV1),
    );
    expect(portableSettingKeys, isNot(contains(StorageKeys.proxyManualHost)));
    expect(portableSettingKeys, isNot(contains(StorageKeys.comfyuiServerUrl)));
    expect(
      portableSettingKeys,
      isNot(contains(StorageKeys.vibeLibrarySavePath)),
    );
    expect(
      portableSettingKeys,
      isNot(contains(StorageKeys.onnxTaggerModelDirectory)),
    );
  });

  test('settings adapter applies only currently selected groups', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sync-selected-settings-',
    );
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    Hive.init(directory.path);
    await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    final storage = LocalStorageService();
    await storage.setSetting(
      StorageKeys.quickTagCloudBrowsingFiltersV1,
      'local-filter',
    );
    final adapter = SettingsCloudSyncAdapter(
      storage,
      includeOnlineGallerySettings: false,
    );

    await adapter.apply([
      PortableSyncRecord(
        adapterId: 'portable-settings',
        id: StorageKeys.locale,
        kind: 'setting',
        data: {'key': StorageKeys.locale, 'value': 'ja'},
      ),
      PortableSyncRecord(
        adapterId: 'portable-settings',
        id: StorageKeys.quickTagCloudBrowsingFiltersV1,
        kind: 'setting',
        data: {
          'key': StorageKeys.quickTagCloudBrowsingFiltersV1,
          'value': 'remote-filter',
        },
      ),
    ]);

    expect(storage.getSetting<String>(StorageKeys.locale), 'ja');
    expect(
      storage.getSetting<String>(StorageKeys.quickTagCloudBrowsingFiltersV1),
      'local-filter',
    );
  });

  test(
    'unified blacklist includes tombstones but excludes backend state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sync-blacklist-',
      );
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      Hive.init(directory.path);
      await Hive.openBox<dynamic>(StorageKeys.settingsBox);
      final repository = OnlineGalleryBlacklistRepository(
        LocalStorageService(),
      );
      await repository.save(
        GalleryBlacklistStore(
          revision: 4,
          desiredTags: const {'keep'},
          tombstones: const {'removed'},
          pendingRemoteDeletions: const {'backend-queue'},
          remoteSnapshots: {
            'account': GalleryBlacklistRemoteSnapshot(
              accountKey: 'account',
              rules: const ['remote'],
              lastSyncAt: DateTime.utc(2025),
            ),
          },
        ),
      );
      final adapter = GalleryBlacklistCloudSyncAdapter(repository);
      final record = (await adapter.exportRecords().toList()).single;

      expect(record.data['desiredTags'], ['keep']);
      expect(record.data['tombstones'], ['removed']);
      expect(record.data, isNot(contains('remoteSnapshots')));
      expect(record.data, isNot(contains('pendingRemoteDeletions')));
      expect(record.data.toString(), isNot(contains('account')));
    },
  );
}

class _ExportingAdapter extends _TrackingAdapter {
  _ExportingAdapter(this.records) : super('exporter');

  final List<PortableSyncRecord> records;

  @override
  Stream<PortableSyncRecord> exportRecords() => Stream.fromIterable(records);
}

class _PermissiveExportAdapter implements CloudSyncDataAdapter {
  _PermissiveExportAdapter(this.record);

  final PortableSyncRecord record;

  @override
  String get id => 'permissive';

  @override
  Stream<PortableSyncRecord> exportRecords() => Stream.value(record);

  @override
  Future<void> preflight(List<PortableSyncRecord> records) async {}

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {}
}
