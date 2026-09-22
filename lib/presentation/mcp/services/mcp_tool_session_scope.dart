import 'dart:async';

/// 在途 `tools/call` 的传输会话，供工具内部没有参数可接的地方读取。只读工具并发
/// 执行，用可变字段会让两个客户端串台；Zone 的异步续体自动继承，同一次调用内前
/// 后读到的必然一致。
abstract final class McpToolSessionScope {
  static final Object _key = Object();

  static String? get currentSessionId {
    final value = Zone.current[_key];
    return value is String ? value : null;
  }

  static R run<R>(String sessionId, R Function() body) =>
      runZoned(body, zoneValues: {_key: sessionId});
}
