import 'dart:io';

import '../utils/app_logger.dart';

/// 系统代理 HTTP 覆盖类
///
/// 通过 [HttpOverrides.global] 注入，实现全局代理配置。
/// 该类会拦截所有基于 [dart:io.HttpClient] 的网络请求，
/// 包括 Dio 和 CachedNetworkImage。
class SystemProxyHttpOverrides extends HttpOverrides {
  /// 代理配置字符串
  final String _proxyString;

  /// 构造函数
  ///
  /// [proxyString] 格式为 "PROXY host:port" 或 "DIRECT"
  SystemProxyHttpOverrides(this._proxyString);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // 调用父类方法创建默认客户端
    final client = super.createHttpClient(context);

    // 设置代理配置
    // findProxy 回调接收请求 URI，返回代理字符串
    client.findProxy = (uri) {
      AppLogger.d(
        'Proxy request for: ${uri.host}:${uri.port} -> $_proxyString',
        'PROXY',
      );
      return _proxyString;
    };

    // 可选：处理代理服务器的证书验证问题
    // 对于某些本地代理工具（如 Fiddler、Charles），可能需要忽略证书验证
    // 注意：这会降低安全性，仅在开发环境使用
    // client.badCertificateCallback = (cert, host, port) => true;

    return client;
  }
}
