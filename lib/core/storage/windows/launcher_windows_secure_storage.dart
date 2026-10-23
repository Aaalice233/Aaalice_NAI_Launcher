import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:synchronized/synchronized.dart';

import 'dpapi_json_file_store.dart';

/// Windows 安全存储：读改写在同一把锁内完成，读不到文件时抛出而不是当作空表回写
class LauncherWindowsSecureStorage extends FlutterSecureStoragePlatform {
  LauncherWindowsSecureStorage({DpapiJsonFileStore? store})
    : _store = store ?? DpapiJsonFileStore.applicationSupport();

  final DpapiJsonFileStore _store;
  final Lock _lock = Lock();

  // 插件的 dartPluginClass 在 main 之前已注册，必须在任何安全存储访问前覆盖
  static void register() {
    FlutterSecureStoragePlatform.instance = LauncherWindowsSecureStorage();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    _rejectLegacyCredentialStore(options);
    return _lock.synchronized(() async => (await _store.load())[key]);
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) {
    _rejectLegacyCredentialStore(options);
    return _lock.synchronized(
      () async => (await _store.load()).containsKey(key),
    );
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) {
    _rejectLegacyCredentialStore(options);
    return _lock.synchronized(_store.load);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) {
    _rejectLegacyCredentialStore(options);
    return _lock.synchronized(
      () => _store.update((data) {
        if (data[key] == value) return false;
        data[key] = value;
        return true;
      }),
    );
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) {
    _rejectLegacyCredentialStore(options);
    return _lock.synchronized(
      () => _store.update((data) => data.remove(key) != null),
    );
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) {
    _rejectLegacyCredentialStore(options);
    return _lock.synchronized(_store.clear);
  }

  // 该选项要求从 Credential Manager 迁移旧值；本应用从未开启，静默忽略会让调用方误以为已迁移
  static void _rejectLegacyCredentialStore(Map<String, String> options) {
    if (options['useBackwardCompatibility'] == 'true') {
      throw UnsupportedError(
        'useBackwardCompatibility is not supported on Windows',
      );
    }
  }
}
