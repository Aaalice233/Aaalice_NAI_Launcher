import '../../../core/network/proxy_service.dart';

/// 代理模式
enum ProxyMode {
  /// 自动检测系统代理
  auto,

  /// 手动配置代理
  manual,
}

/// 代理设置
class ProxySettings {
  /// 是否启用代理
  final bool enabled;

  /// 代理模式
  final ProxyMode mode;

  /// 手动配置的代理主机
  final String? manualHost;

  /// 手动配置的代理端口
  final int? manualPort;

  const ProxySettings({
    this.enabled = false,
    this.mode = ProxyMode.auto,
    this.manualHost,
    this.manualPort,
  });

  /// 获取当前有效的代理地址
  ///
  /// 返回格式: "host:port" 或 null
  String? get effectiveProxyAddress {
    if (!enabled) return null;

    if (mode == ProxyMode.manual) {
      if (manualHost != null &&
          manualHost!.isNotEmpty &&
          manualPort != null &&
          manualPort! > 0) {
        return '$manualHost:$manualPort';
      }
      return null;
    }

    // 自动模式：从系统获取
    return ProxyService.getSystemProxyAddress();
  }

  /// 复制并修改
  ProxySettings copyWith({
    bool? enabled,
    ProxyMode? mode,
    String? manualHost,
    int? manualPort,
  }) {
    return ProxySettings(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      manualHost: manualHost ?? this.manualHost,
      manualPort: manualPort ?? this.manualPort,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProxySettings &&
        other.enabled == enabled &&
        other.mode == mode &&
        other.manualHost == manualHost &&
        other.manualPort == manualPort;
  }

  @override
  int get hashCode => Object.hash(enabled, mode, manualHost, manualPort);

  @override
  String toString() {
    return 'ProxySettings(enabled: $enabled, mode: $mode, '
        'manualHost: $manualHost, manualPort: $manualPort, '
        'effectiveProxy: $effectiveProxyAddress)';
  }
}
