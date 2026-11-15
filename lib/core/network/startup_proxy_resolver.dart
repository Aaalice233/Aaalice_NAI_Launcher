import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../data/models/settings/proxy_settings.dart';
import '../constants/storage_keys.dart';
import '../platform/platform_capabilities.dart';
import '../storage/local_storage_service.dart';
import 'proxy_service.dart';
import 'proxy_settings_provider.dart';

/// 从 [LocalStorageService] 解析启动时要注入 [HttpOverrides.global] 的代理地址。
String? resolveStartupProxyAddressFromStorage(
  LocalStorageService storage,
  PlatformCapabilities capabilities,
) {
  final enabled =
      storage.getSetting<bool>(StorageKeys.proxyEnabled, defaultValue: true) ??
      true;
  if (!enabled) return null;

  final storedMode =
      storage.getSetting<String>(StorageKeys.proxyMode, defaultValue: 'auto') ??
      'auto';
  return _resolveFromValues(
    storedMode: storedMode,
    host: storage.getSetting<String>(StorageKeys.proxyManualHost),
    port: storage.getSetting<int>(StorageKeys.proxyManualPort),
    capabilities: capabilities,
  );
}

/// 启动时要注入 [HttpOverrides.global] 的代理地址，未启用或拿不到时返回 null。
///
/// 启动时初始化全局路由，后续设置修改由 ProxySettingsNotifier 即时应用。
/// 模式按 [resolveProxyMode] 折算：移动端读不到系统代理，只使用手动地址。
@visibleForTesting
String? resolveStartupProxyAddress(
  Box<dynamic> settingsBox,
  PlatformCapabilities capabilities,
) {
  final enabled =
      settingsBox.get(StorageKeys.proxyEnabled, defaultValue: true) as bool;
  if (!enabled) return null;

  final storedMode =
      settingsBox.get(StorageKeys.proxyMode, defaultValue: 'auto') as String;
  return _resolveFromValues(
    storedMode: storedMode,
    host: settingsBox.get(StorageKeys.proxyManualHost) as String?,
    port: settingsBox.get(StorageKeys.proxyManualPort) as int?,
    capabilities: capabilities,
  );
}

String? _resolveFromValues({
  required String storedMode,
  required String? host,
  required int? port,
  required PlatformCapabilities capabilities,
}) {
  final mode = resolveProxyMode(
    ProxyMode.values.asNameMap()[storedMode] ?? ProxyMode.auto,
    capabilities,
  );
  if (mode == ProxyMode.manual) {
    if (host != null && host.isNotEmpty && port != null && port > 0) {
      return '$host:$port';
    }
    return null;
  }
  return ProxyService.getSystemProxyAddress();
}
