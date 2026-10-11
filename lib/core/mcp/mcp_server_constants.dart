/// Fixed defaults shared by the in-app MCP server, its settings UI and the
/// stdio proxy CLI.
abstract final class McpServerDefaults {
  // 避开微信等常见软件占用的 14xxx 段；客户端把端点 URL 写进配置文件，端口必须跨启动稳定。
  static const int port = 20624;
  static const int minPort = 1024;
  static const int maxPort = 65535;
  static const String endpointPath = '/mcp';
  static const String loopbackHost = '127.0.0.1';
  static const String serverName = 'nai-launcher';
  static const String transport = 'streamable-http';
  static const String discoveryFileName = 'mcp-server.json';
  static const int maxBodyBytes = 8 << 20;
  static const int maxSessions = 16;
  static const Duration sessionIdleTimeout = Duration(minutes: 30);
  static const Duration approvalTimeout = Duration(minutes: 5);
  static const Duration keepAliveInterval = Duration(seconds: 15);
  static const String sessionIdHeader = 'Mcp-Session-Id';
  static const String protocolVersionHeader = 'MCP-Protocol-Version';
  static const String callIdMetaKey = 'nai_launcher/call_id';
}
