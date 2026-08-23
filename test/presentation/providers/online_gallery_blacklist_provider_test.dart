import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/models/danbooru/danbooru_user.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_blacklist_provider.dart';

void main() {
  ProviderContainer createContainer({
    required _FakeStorage storage,
    required _FakeDanbooruApiService api,
    bool loggedIn = true,
  }) {
    return ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => storage),
        danbooruApiServiceProvider.overrideWithValue(api),
        danbooruAuthProvider.overrideWith(
          () => _FakeDanbooruAuth(loggedIn: loggedIn),
        ),
      ],
    );
  }

  test('pull refreshes cloud tags without overwriting local tags', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag']
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
        'old_cloud_tag',
      ];
    final api = _FakeDanbooruApiService(
      fetchedTags: ['Cloud Tag', '-cloud_tag_2'],
    );
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);

    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    expect(await notifier.pullFromCloud(), isTrue);
    final state = container.read(onlineGalleryBlacklistNotifierProvider);
    expect(state.localTags, {'local_tag'});
    expect(state.remoteTags, {'cloud_tag', 'cloud_tag_2'});
    expect(storage.values[StorageKeys.onlineGalleryBlacklistTags], [
      'local_tag',
    ]);
  });

  test('push replaces cloud tags with the exact local list', () async {
    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>[
        'z_local',
        'a_local',
      ]
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
        'cloud_only',
      ];
    final api = _FakeDanbooruApiService();
    final container = createContainer(storage: storage, api: api);
    addTearDown(container.dispose);

    final notifier = container.read(
      onlineGalleryBlacklistNotifierProvider.notifier,
    );
    await notifier.ensureInitialized();

    expect(await notifier.pushLocalToCloud(), isTrue);
    expect(api.updatedTags, ['a_local', 'z_local']);
    final state = container.read(onlineGalleryBlacklistNotifierProvider);
    expect(state.localTags, {'a_local', 'z_local'});
    expect(state.remoteTags, {'a_local', 'z_local'});
  });

  test(
    'editing cloud mode updates cloud without changing local tags',
    () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag']
        ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
          'cloud_tag',
        ];
      final api = _FakeDanbooruApiService();
      final container = createContainer(storage: storage, api: api);
      addTearDown(container.dispose);

      final notifier = container.read(
        onlineGalleryBlacklistNotifierProvider.notifier,
      );
      await notifier.ensureInitialized();
      await notifier.setSelectedSource(OnlineGalleryBlacklistSource.cloud);

      expect(await notifier.addTag('new cloud tag'), isTrue);
      expect(api.updatedTags, ['cloud_tag', 'new_cloud_tag']);
      final state = container.read(onlineGalleryBlacklistNotifierProvider);
      expect(state.localTags, {'local_tag'});
      expect(state.remoteTags, {'cloud_tag', 'new_cloud_tag'});
    },
  );

  test(
    'selected source is persisted and cloud falls back locally offline',
    () async {
      final storage = _FakeStorage()
        ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['local_tag']
        ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = <String>[
          'cloud_tag',
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

      expect(state.selectedSource, OnlineGalleryBlacklistSource.cloud);
      expect(state.effectiveSource, OnlineGalleryBlacklistSource.local);
      expect(state.effectiveTags, {'local_tag'});
    },
  );
}

class _FakeDanbooruAuth extends DanbooruAuth {
  _FakeDanbooruAuth({required this.loggedIn});

  final bool loggedIn;

  @override
  DanbooruAuthState build() {
    if (!loggedIn) return const DanbooruAuthState();
    return DanbooruAuthState(
      credentials: const DanbooruCredentials(
        username: 'tester',
        apiKey: 'api-key',
      ),
      user: const DanbooruUser(id: 1, name: 'tester'),
      lastVerifiedAt: DateTime.now(),
    );
  }
}

class _FakeDanbooruApiService extends DanbooruApiService {
  _FakeDanbooruApiService({this.fetchedTags = const []}) : super(Dio());

  final List<String> fetchedTags;
  List<String>? updatedTags;

  @override
  Future<List<String>> fetchBlacklistedTags() async => fetchedTags;

  @override
  Future<bool> updateBlacklistedTags(List<String> tags) async {
    updatedTags = List.of(tags);
    return true;
  }
}

class _FakeStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return (values[key] ?? defaultValue) as T?;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    values.remove(key);
  }
}
