import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late _MemorySecureStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('account_remove_test_');
    Hive.init(p.join(tempDir.path, 'hive'));
    storage = _MemorySecureStorage();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('移除账号清掉凭据、第三方端点与头像文件，并把默认身份交给剩余账号', () async {
    final container = createContainer();
    final notifier = container.read(accountManagerNotifierProvider.notifier);
    await notifier.whenLoaded;

    final removed = await notifier.addAccount(
      identifier: 'relay',
      token: 'relay-token',
      nickname: 'Relay',
      apiEndpoint: NaiApiEndpointConfig.fromInput(
        mainBaseUrl: 'https://relay.example.com',
      ),
    );
    final kept = await notifier.addAccount(
      identifier: 'official',
      token: 'pst-official',
      nickname: 'Official',
    );
    await storage.saveAccountAccessKey(removed.id, 'access-key');
    final avatar = File(p.join(tempDir.path, '${removed.id}.png'))
      ..writeAsBytesSync([1, 2, 3]);
    await notifier.updateAccount(removed.copyWith(avatarPath: avatar.path));
    expect(
      container.read(accountManagerNotifierProvider).accounts.first.isDefault,
      isTrue,
    );

    await notifier.removeAccount(removed.id);

    final state = container.read(accountManagerNotifierProvider);
    expect(state.accounts.map((a) => a.id), [kept.id]);
    expect(state.accounts.single.isDefault, isTrue);
    expect(state.accountApiEndpoints, isEmpty);
    expect(await storage.getAccountToken(removed.id), isNull);
    expect(await storage.getAccountAccessKey(removed.id), isNull);
    expect(await storage.getAccountToken(kept.id), 'pst-official');
    expect(avatar.existsSync(), isFalse);

    await Hive.box('accounts').close();
    final reloaded = createContainer();
    final reloadedNotifier = reloaded.read(
      accountManagerNotifierProvider.notifier,
    );
    await reloadedNotifier.whenLoaded;
    expect(
      reloaded.read(accountManagerNotifierProvider).accounts.map((a) => a.id),
      [kept.id],
    );
    expect(reloadedNotifier.hasCustomApiEndpoint(removed.id), isFalse);
  });

  test('移除后才返回的 token 刷新不会把凭据写回已移除账号', () async {
    final container = createContainer();
    final notifier = container.read(accountManagerNotifierProvider.notifier);
    await notifier.whenLoaded;
    final removed = await notifier.addAccount(
      identifier: 'first',
      token: 'pst-first',
      nickname: 'First',
    );
    final kept = await notifier.addAccount(
      identifier: 'second',
      token: 'pst-second',
      nickname: 'Second',
    );

    await notifier.removeAccount(removed.id);
    await notifier.updateAccountToken(removed.id, 'pst-late-refresh');
    await notifier.updateAccountToken(kept.id, 'pst-refreshed');

    expect(await storage.getAccountToken(removed.id), isNull);
    expect(await storage.getAccountToken(kept.id), 'pst-refreshed');
  });

  test('移除不存在的账号不改动已有数据', () async {
    final container = createContainer();
    final notifier = container.read(accountManagerNotifierProvider.notifier);
    await notifier.whenLoaded;
    final kept = await notifier.addAccount(
      identifier: 'official',
      token: 'pst-official',
      nickname: 'Official',
    );

    await notifier.removeAccount('missing');

    expect(
      container.read(accountManagerNotifierProvider).accounts.map((a) => a.id),
      [kept.id],
    );
    expect(await storage.getAccountToken(kept.id), 'pst-official');
  });
}

class _MemorySecureStorage extends SecureStorageService {
  final _tokens = <String, String>{};
  final _accessKeys = <String, String>{};

  @override
  Future<void> saveAccountToken(String accountId, String token) async {
    _tokens[accountId] = token;
  }

  @override
  Future<String?> getAccountToken(String accountId) async => _tokens[accountId];

  @override
  Future<void> deleteAccountToken(String accountId) async {
    _tokens.remove(accountId);
  }

  @override
  Future<void> saveAccountAccessKey(String accountId, String accessKey) async {
    _accessKeys[accountId] = accessKey;
  }

  @override
  Future<String?> getAccountAccessKey(String accountId) async =>
      _accessKeys[accountId];

  @override
  Future<void> deleteAccountAccessKey(String accountId) async {
    _accessKeys.remove(accountId);
  }
}
