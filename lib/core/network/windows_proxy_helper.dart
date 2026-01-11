import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

import '../utils/app_logger.dart';

/// Windows 系统代理辅助类
/// 用于读取 Windows 注册表中的代理设置
class WindowsProxyHelper {
  /// 注册表路径
  static const String _registryPath =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  /// 代理启用键名
  static const String _proxyEnableKey = 'ProxyEnable';

  /// 代理服务器键名
  static const String _proxyServerKey = 'ProxyServer';

  /// 获取当前系统代理配置
  ///
  /// 返回格式：
  /// - "PROXY host:port" 如果代理已启用
  /// - "DIRECT" 如果代理未启用或获取失败
  static String? getSystemProxy() {
    // 仅在 Windows 平台执行
    if (!Platform.isWindows) {
      return null;
    }

    try {
      // 打开注册表项
      final key = Registry.openPath(
        RegistryHive.currentUser,
        path: _registryPath,
      );

      // 读取代理启用状态 (REG_DWORD)
      final proxyEnableValue = key.getValue(_proxyEnableKey);
      int? proxyEnable;
      if (proxyEnableValue != null && proxyEnableValue.data is int) {
        proxyEnable = proxyEnableValue.data as int;
      }

      AppLogger.d(
        'Windows Proxy Enable: $proxyEnable (type: ${proxyEnable?.runtimeType})',
        'PROXY',
      );

      // 如果代理未启用，返回 DIRECT
      if (proxyEnable != 1) {
        key.close();
        AppLogger.d('Proxy disabled, using DIRECT', 'PROXY');
        return 'DIRECT';
      }

      // 读取代理服务器地址 (REG_SZ)
      final proxyServerValue = key.getValue(_proxyServerKey);
      String? proxyServer;
      if (proxyServerValue != null && proxyServerValue.data is String) {
        proxyServer = proxyServerValue.data as String;
      }

      key.close();

      AppLogger.d('Raw Proxy Server string: "$proxyServer"', 'PROXY');

      // 解析代理服务器字符串
      final parsedProxy = _parseProxyServer(proxyServer);

      if (parsedProxy != null) {
        AppLogger.d('Parsed proxy: $parsedProxy', 'PROXY');
        return 'PROXY $parsedProxy';
      } else {
        AppLogger.d('Invalid proxy format, using DIRECT', 'PROXY');
        return 'DIRECT';
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to read Windows proxy settings: $e', 'PROXY', stackTrace);
      return 'DIRECT';
    }
  }

  /// 解析代理服务器字符串
  ///
  /// Windows 注册表中的格式可能是：
  /// - 简单格式: "127.0.0.1:7890"
  /// - 复杂格式: "http=127.0.0.1:7890;https=127.0.0.1:7890"
  /// - SOCKS 格式: "socks=127.0.0.1:1080"
  static String? _parseProxyServer(String? proxyServer) {
    if (proxyServer == null || proxyServer.isEmpty) {
      return null;
    }

    // 去除首尾空格
    proxyServer = proxyServer.trim();

    // 如果包含等号（复杂格式），尝试解析
    if (proxyServer.contains('=')) {
      // 尝试获取 http 或 https 代理
      // 格式: "http=host:port;https=host:port"
      final parts = proxyServer.split(';');
      for (final part in parts) {
        final kv = part.split('=');
        if (kv.length == 2) {
          final protocol = kv[0].trim().toLowerCase();
          final hostPort = kv[1].trim();

          // 优先使用 http，其次 https
          if ((protocol == 'http' || protocol == 'https') && hostPort.isNotEmpty) {
            return hostPort;
          }
        }
      }

      // 如果没找到 http/https，尝试获取 socks
      for (final part in parts) {
        final kv = part.split('=');
        if (kv.length == 2) {
          final protocol = kv[0].trim().toLowerCase();
          final hostPort = kv[1].trim();

          if (protocol == 'socks' && hostPort.isNotEmpty) {
            AppLogger.w('SOCKS proxy detected but Dart HttpClient has limited SOCKS support', 'PROXY');
            return hostPort;
          }
        }
      }

      return null;
    }

    // 简单格式：直接返回
    return proxyServer;
  }
}
