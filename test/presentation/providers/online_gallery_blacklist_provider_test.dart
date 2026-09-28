import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/models/danbooru/danbooru_user.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_blacklist.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_blacklist_provider.dart';

void main() {
  ProviderContainer createContainer({
    required _FakeStorage storage,
    required _FakeDanbooruApiService api,
    bool loggedIn = true,
    int userId = 1,
  }) {
    return ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => storage),
        danbooruApiServiceProvider.overrideWithValue(api),
        danbooruAuthProvider.overrideWith(
          () => _FakeDanbooruAuth(loggedIn: loggedIn, userId: userId),
        ),
      ],
    );
  }

  test('legacy local and cloud lists migrate into one lossless list', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag']
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
        'old cloud tag',
      ];
    final container = createContainer(
      storage: storage,
      api: _FakeDanbooruApiService(),
      loggedIn: false,
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    final state = container.read(onlineGalleryBlacklistNotifierProvider);
    expect(state.tags, {'local_tag', 'old_cloud_tag'});
    expect(storage.values[StorageKeys.onlineGalleryBlacklistV2], isA<String>());
    expect(storage.values[StorageKeys.onlineGalleryBlacklistTags], [
      'local_tag',
      'old_cloud_tag',
    ]);
  });

  test(
    'unscoped migrated cloud data requires an explicit confirmed push',
    () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
          'unknown_account_tag',
        ];
      final api = _FakeDanbooruApiService();
      final container = createContainer(storage: storage, api: api);
      addTearDown(container.dispose);
      final notifier = container.read(
        onlineGalleryBlacklistNotifierProvider.notifier,
      );
      await notifier.ensureInitialized();

      await notifier.addTag('local_edit');
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(api.updateCalls, 0);

      await notifier.pullFromCloud(background: true);
      final preview = await notifier.preparePushToCloud();
      expect(preview?.containsLegacyUnscopedData, isTrue);
      expect(api.updateCalls, 0);
      expect(
        await notifier.pushToCloud(
          preview!,
          confirmEmptyReplacement: false,
          confirmLegacyMigration: false,
        ),
        isFalse,
      );
      expect(api.updateCalls, 0);

      expect(
        await notifier.pushToCloud(
          preview,
          confirmEmptyReplacement: false,
          confirmLegacyMigration: true,
        ),
        isTrue,
      );
      expect(api.rules, ['local_edit', 'unknown_account_tag']);
      final persisted = GalleryBlacklistStore.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
                storage.values[StorageKeys.onlineGalleryBlacklistV2] as String,
              )
              as Map,
        ),
      );
      expect(persisted.legacyUnscopedRules, isEmpty);
    },
  );

  test('pull merges simple cloud tags and preserves advanced rules', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag'];
    final api = _FakeDanbooruApiService(
      rules: ['cloud_tag', 'furry -rating:g'],
    );
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    final result = await notifier.pullFromCloud();

    expect(result?.addedCount, 1);
    final state = container.read(onlineGalleryBlacklistNotifierProvider);
    expect(state.tags, {'local_tag', 'cloud_tag'});
    expect(state.remoteTags, {'cloud_tag'});
    expect(state.opaqueRemoteRules, ['furry -rating:g']);
  });

  test('pull merge can be undone without deleting cloud rules', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag'];
    final api = _FakeDanbooruApiService(rules: ['cloud_tag']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    await notifier.pullFromCloud();
    expect(
      container.read(onlineGalleryBlacklistNotifierProvider).canUndo,
      isTrue,
    );
    expect(await notifier.undoLastMutation(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(container.read(onlineGalleryBlacklistNotifierProvider).tags, {
      'local_tag',
    });
    expect(api.rules, ['cloud_tag']);
  });

  test('undo after a completed local add performs compensating sync', () async {
    final storage = _FakeStorage();
    final api = _FakeDanbooruApiService();
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    await notifier.addTag('temporary_tag');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(api.rules, ['temporary_tag']);

    expect(await notifier.undoLastMutation(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(
      container.read(onlineGalleryBlacklistNotifierProvider).tags,
      isEmpty,
    );
    expect(api.rules, isEmpty);
  });

  test(
    'push refuses destructive empty replacement without confirmation',
    () async {
      final storage = _FakeStorage();
      final api = _FakeDanbooruApiService(rules: ['cloud_only']);
      final container = createContainer(storage: storage, api: api);
      addTearDown(container.dispose);
      final notifier = container.read(
        onlineGalleryBlacklistNotifierProvider.notifier,
      );
      await notifier.ensureInitialized();

      final preview = await notifier.preparePushToCloud();
      expect(preview?.requiresEmptyConfirmation, isTrue);
      expect(
        await notifier.pushToCloud(
          preview!,
          confirmEmptyReplacement: false,
          confirmLegacyMigration: false,
        ),
        isFalse,
      );
      expect(api.updateCalls, 0);
      expect(api.rules, ['cloud_only']);
    },
  );

  test(
    'confirmed push exactly replaces cloud and verifies read-back',
    () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>[
          'z_local',
          'a_local',
        ];
      final api = _FakeDanbooruApiService(
        rules: ['cloud_only', 'furry -rating:g'],
      );
      final container = createContainer(storage: storage, api: api);
      addTearDown(container.dispose);
      final notifier = container.read(
        onlineGalleryBlacklistNotifierProvider.notifier,
      );
      await notifier.ensureInitialized();

      final preview = await notifier.preparePushToCloud();
      expect(preview?.removedTags, {'cloud_only'});
      expect(preview?.opaqueRulesToRemove, ['furry -rating:g']);
      expect(
        await notifier.pushToCloud(
          preview!,
          confirmEmptyReplacement: false,
          confirmLegacyMigration: false,
        ),
        isTrue,
      );

      expect(api.rules, ['a_local', 'z_local']);
      final state = container.read(onlineGalleryBlacklistNotifierProvider);
      expect(state.tags, {'a_local', 'z_local'});
      expect(state.remoteTags, {'a_local', 'z_local'});
      expect(state.opaqueRemoteRules, isEmpty);
    },
  );

  test(
    'verified cloud write is not reported as failed when local save fails',
    () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local'];
      final api = _FakeDanbooruApiService(rules: ['remote']);
      final container = createContainer(storage: storage, api: api);
      addTearDown(container.dispose);
      final notifier = container.read(
        onlineGalleryBlacklistNotifierProvider.notifier,
      );
      await notifier.ensureInitialized();

      final preview = await notifier.preparePushToCloud();
      storage.failWrites = true;
      expect(
        await notifier.pushToCloud(
          preview!,
          confirmEmptyReplacement: false,
          confirmLegacyMigration: false,
        ),
        isTrue,
      );

      expect(api.rules, ['local']);
      expect(
        container.read(onlineGalleryBlacklistNotifierProvider).lastSyncError,
        contains('Cloud blacklist was updated'),
      );
    },
  );

  test('push rejects a cloud change made after diff review', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local'];
    final api = _FakeDanbooruApiService(rules: ['before']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    final preview = await notifier.preparePushToCloud();
    api.rules = ['before', 'other_device'];

    expect(
      await notifier.pushToCloud(
        preview!,
        confirmEmptyReplacement: false,
        confirmLegacyMigration: false,
      ),
      isFalse,
    );
    expect(api.updateCalls, 0);
    expect(api.rules, ['before', 'other_device']);
  });

  test('ordinary edits preserve remote additions and advanced rules', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag'];
    final api = _FakeDanbooruApiService(
      rules: ['cloud_tag', 'furry -rating:g'],
    );
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    expect(await notifier.addTag('new cloud tag'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(api.rules, [
      'cloud_tag',
      'furry -rating:g',
      'local_tag',
      'new_cloud_tag',
    ]);
    expect(container.read(onlineGalleryBlacklistNotifierProvider).tags, {
      'local_tag',
      'new_cloud_tag',
    });
  });

  test('removing before the first pull cannot resurrect the tag', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['remote_tag'];
    final api = _FakeDanbooruApiService(rules: ['remote_tag']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    await notifier.removeTag('remote_tag');
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(api.rules, isEmpty);
    expect(
      container.read(onlineGalleryBlacklistNotifierProvider).tags,
      isEmpty,
    );
    final pull = await notifier.pullFromCloud();
    expect(pull?.addedCount, 0);
    expect(
      container.read(onlineGalleryBlacklistNotifierProvider).tags,
      isEmpty,
    );
  });

  test('removing the last tag syncs that explicit deletion', () async {
    final storage = _FakeStorage();
    final api = _FakeDanbooruApiService(rules: ['remote_tag']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();
    await notifier.pullFromCloud();

    await notifier.removeTag('remote_tag');
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(api.rules, isEmpty);
    expect(
      container.read(onlineGalleryBlacklistNotifierProvider).tags,
      isEmpty,
    );
    final persisted = GalleryBlacklistStore.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(
              storage.values[StorageKeys.onlineGalleryBlacklistV2] as String,
            )
            as Map,
      ),
    );
    expect(persisted.pendingRemoteDeletions, contains('remote_tag'));
  });

  test('verified deletion stays pending for another known account', () async {
    final initial = GalleryBlacklistStore(
      desiredTags: const {'shared_tag'},
      remoteSnapshots: {
        for (final accountKey in ['danbooru:1', 'danbooru:2'])
          accountKey: GalleryBlacklistRemoteSnapshot(
            accountKey: accountKey,
            rules: const ['shared_tag'],
            lastSyncAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
      },
    );
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistV2] = jsonEncode(
        initial.toJson(),
      );
    final api = _FakeDanbooruApiService(rules: ['shared_tag']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    await notifier.removeTag('shared_tag');
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(api.rules, isEmpty);
    final persisted = GalleryBlacklistStore.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(
              storage.values[StorageKeys.onlineGalleryBlacklistV2] as String,
            )
            as Map,
      ),
    );
    expect(persisted.pendingRemoteDeletions, contains('shared_tag'));
    expect(persisted.tombstones, contains('shared_tag'));
  });

  test(
    'explicit deletions survive pulls and apply to an unseen account',
    () async {
      final initial = GalleryBlacklistStore(
        tombstones: const {'shared_tag'},
        pendingRemoteDeletions: const {'shared_tag'},
        remoteSnapshots: {
          'danbooru:1': GalleryBlacklistRemoteSnapshot(
            accountKey: 'danbooru:1',
            rules: const [],
            lastSyncAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        },
      );
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryBlacklistV2] = jsonEncode(
          initial.toJson(),
        );
      final api = _FakeDanbooruApiService();
      final container = createContainer(storage: storage, api: api);
      addTearDown(container.dispose);
      final notifier = container.read(
        onlineGalleryBlacklistNotifierProvider.notifier,
      );
      await notifier.ensureInitialized();

      await notifier.pullFromCloud();
      var persisted = GalleryBlacklistStore.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
                storage.values[StorageKeys.onlineGalleryBlacklistV2] as String,
              )
              as Map,
        ),
      );
      expect(persisted.pendingRemoteDeletions, contains('shared_tag'));

      (container.read(danbooruAuthProvider.notifier) as _FakeDanbooruAuth)
          .loginAs(2);
      api.rules = ['shared_tag'];
      await notifier.addTag('local_tag');
      await Future<void>.delayed(const Duration(milliseconds: 650));

      expect(api.rules, ['local_tag']);
      persisted = GalleryBlacklistStore.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
                storage.values[StorageKeys.onlineGalleryBlacklistV2] as String,
              )
              as Map,
        ),
      );
      expect(persisted.pendingRemoteDeletions, contains('shared_tag'));
    },
  );

  test('adding after local clear preserves cloud-only tags', () async {
    final storage = _FakeStorage();
    final api = _FakeDanbooruApiService(rules: ['cloud_a', 'cloud_b']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();
    await notifier.pullFromCloud();
    await notifier.clearTags();

    await notifier.addTag('local_c');
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(api.rules.toSet(), {'cloud_a', 'cloud_b', 'local_c'});
    expect(container.read(onlineGalleryBlacklistNotifierProvider).tags, {
      'local_c',
    });
  });

  test('failed remote delete never resurrects a locally deleted tag', () async {
    final storage = _FakeStorage();
    final api = _FakeDanbooruApiService(rules: ['blocked_tag']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();
    await notifier.pullFromCloud();
    expect(await notifier.removeTag('blocked_tag'), isTrue);

    api.failUpdates = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    await notifier.pullFromCloud();

    final state = container.read(onlineGalleryBlacklistNotifierProvider);
    expect(state.tags, isNot(contains('blocked_tag')));
    expect(state.tombstones, contains('blocked_tag'));
  });

  test('a local edit committed during pull is never overwritten', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['before'];
    final api = _FakeDanbooruApiService();
    final delayedFetch = Completer<List<String>>();
    api.nextFetch = delayedFetch;
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    final pull = notifier.pullFromCloud();
    await Future<void>.delayed(Duration.zero);
    final add = notifier.addTag('during_pull');
    delayedFetch.complete(['cloud_tag']);
    await Future.wait([pull, add]);

    expect(container.read(onlineGalleryBlacklistNotifierProvider).tags, {
      'before',
      'during_pull',
      'cloud_tag',
    });
  });

  test(
    'incremental sync waits for an overlapping pull instead of dropping',
    () async {
      final storage = _FakeStorage();
      final api = _FakeDanbooruApiService();
      final container = createContainer(storage: storage, api: api);
      addTearDown(container.dispose);
      final notifier = container.read(
        onlineGalleryBlacklistNotifierProvider.notifier,
      );
      await notifier.ensureInitialized();

      expect(await notifier.addTag('local_edit'), isTrue);
      final pullGate = Completer<List<String>>();
      api.nextFetch = pullGate;
      final pull = notifier.pullFromCloud();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(api.updateCalls, 0);

      pullGate.complete(['cloud_tag']);
      await pull;
      await Future<void>.delayed(const Duration(milliseconds: 650));

      expect(api.rules, containsAll(<String>['cloud_tag', 'local_edit']));
      expect(api.updateCalls, 1);
    },
  );

  test('a local edit during push remains pending and is synced next', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['before'];
    final api = _FakeDanbooruApiService(rules: ['cloud_old']);
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();
    final preview = await notifier.preparePushToCloud();
    final updateGate = Completer<void>();
    api.updateGate = updateGate;

    final push = notifier.pushToCloud(
      preview!,
      confirmEmptyReplacement: false,
      confirmLegacyMigration: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await notifier.addTag('during_push'), isTrue);
    updateGate.complete();
    expect(await push, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(api.rules, containsAll(<String>['before', 'during_push']));
    expect(container.read(onlineGalleryBlacklistNotifierProvider).tags, {
      'before',
      'during_push',
    });
  });

  test('a late response from account A cannot populate account B', () async {
    final storage = _FakeStorage();
    final api = _FakeDanbooruApiService();
    final delayedFetch = Completer<List<String>>();
    api.nextFetch = delayedFetch;
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    final pull = notifier.pullFromCloud();
    await Future<void>.delayed(Duration.zero);
    (container.read(danbooruAuthProvider.notifier) as _FakeDanbooruAuth)
        .loginAs(2);
    delayedFetch.complete(['account_a_tag']);
    expect(await pull, isNull);

    final state = container.read(onlineGalleryBlacklistNotifierProvider);
    expect(state.currentAccountKey, 'danbooru:2');
    expect(state.remoteTags, isEmpty);
    expect(state.tags, isEmpty);
  });

  test('failed local persistence never reports or exposes the edit', () async {
    final storage = _FakeStorage();
    final container = createContainer(
      storage: storage,
      api: _FakeDanbooruApiService(),
      loggedIn: false,
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();
    storage.failWrites = true;

    await expectLater(notifier.addTag('must_not_appear'), throwsStateError);

    expect(
      container.read(onlineGalleryBlacklistNotifierProvider).tags,
      isEmpty,
    );
  });

  test('startup retries a previously failed remote reconciliation', () async {
    final initial = GalleryBlacklistStore(
      desiredTags: const {'local_tag'},
      remoteSnapshots: {
        'danbooru:1': GalleryBlacklistRemoteSnapshot(
          accountKey: 'danbooru:1',
          rules: const [],
          lastSyncAt: DateTime.now(),
          lastError: 'network unavailable',
        ),
      },
    );
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistV2] = jsonEncode(
        initial.toJson(),
      );
    final api = _FakeDanbooruApiService();
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    await notifier.syncOnStartup();
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(api.updateCalls, 1);
    expect(api.rules, ['local_tag']);
    expect(
      container.read(onlineGalleryBlacklistNotifierProvider).lastSyncError,
      isNull,
    );
  });

  test('offline mode always filters with the unified local list', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag']
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
        'legacy_cloud_tag',
      ]
      ..values[StorageKeys.onlineGalleryBlacklistSource] = 'cloud';
    final container = createContainer(
      storage: storage,
      api: _FakeDanbooruApiService(),
      loggedIn: false,
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    final state = container.read(onlineGalleryBlacklistNotifierProvider);
    expect(state.isCloudAvailable, isFalse);
    expect(state.tags, {'local_tag', 'legacy_cloud_tag'});
  });
}

class _FakeDanbooruAuth extends DanbooruAuth {
  _FakeDanbooruAuth({required this.loggedIn, required this.userId});

  final bool loggedIn;
  final int userId;

  @override
  DanbooruAuthState build() {
    if (!loggedIn) return const DanbooruAuthState();
    return _loggedInState(userId);
  }

  void loginAs(int id) => state = _loggedInState(id);

  DanbooruAuthState _loggedInState(int id) => DanbooruAuthState(
    credentials: const DanbooruCredentials(
      username: 'tester',
      apiKey: 'api-key',
    ),
    user: DanbooruUser(id: id, name: 'tester'),
    lastVerifiedAt: DateTime.now(),
  );
}

class _FakeDanbooruApiService extends DanbooruApiService {
  _FakeDanbooruApiService({List<String> rules = const []})
    : rules = List.of(rules),
      super(Dio());

  List<String> rules;
  bool failUpdates = false;
  int updateCalls = 0;
  Completer<List<String>>? nextFetch;
  Completer<void>? updateGate;

  @override
  Future<List<String>> fetchBlacklistRules({CancelToken? cancelToken}) async {
    final pending = nextFetch;
    if (pending != null) {
      nextFetch = null;
      return pending.future;
    }
    return List.of(rules);
  }

  @override
  Future<void> updateBlacklistRules(
    List<String> rules, {
    CancelToken? cancelToken,
    int? expectedUserId,
  }) async {
    updateCalls++;
    if (failUpdates) throw DioException(requestOptions: RequestOptions());
    await updateGate?.future;
    this.rules = List.of(rules);
  }
}

class _FakeStorage extends LocalStorageService {
  final Map<String, Object?> values = {};
  bool failWrites = false;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return (values[key] ?? defaultValue) as T?;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (failWrites) throw StateError('storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> setSettings(Map<String, Object?> updates) async {
    if (failWrites) throw StateError('storage unavailable');
    values.addAll(updates);
  }

  @override
  Future<void> deleteSetting(String key) async {
    values.remove(key);
  }
}
