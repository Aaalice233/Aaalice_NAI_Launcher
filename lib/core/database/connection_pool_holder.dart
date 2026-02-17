import 'connection_pool.dart';

/// ConnectionPool 全局持有者
/// 
/// 不是单例！支持在热重启或数据库恢复时替换实例。
/// 所有组件都通过此持有者获取 ConnectionPool，确保获取的是当前有效实例。
class ConnectionPoolHolder {
  static ConnectionPool? _instance;

  /// 获取当前实例
  static ConnectionPool get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'ConnectionPool not initialized. Call initialize() first.',
      );
    }
    return inst;
  }

  /// 检查是否已初始化
  static bool get isInitialized => _instance != null;

  /// 初始化（首次启动）
  static Future<ConnectionPool> initialize({
    required String dbPath,
    int maxConnections = 3,
  }) async {
    if (_instance != null) {
      throw StateError(
        'ConnectionPool already initialized. Use reset() to recreate.',
      );
    }

    _instance = ConnectionPool(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    await _instance!.initialize();
    return _instance!;
  }

  /// 重置（热重启或数据库恢复后）
  /// 
  /// 1. 关闭旧连接池
  /// 2. 创建新连接池
  /// 3. 替换全局实例
  static Future<ConnectionPool> reset({
    required String dbPath,
    int maxConnections = 3,
  }) async {
    // 1. 关闭旧连接池
    final oldInstance = _instance;
    if (oldInstance != null) {
      await oldInstance.dispose();
    }

    // 2. 创建新连接池
    _instance = ConnectionPool(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    await _instance!.initialize();

    return _instance!;
  }

  /// 获取当前实例（如果已初始化）
  static ConnectionPool? getInstanceOrNull() {
    return _instance;
  }

  /// 销毁（应用退出时）
  static Future<void> dispose() async {
    final inst = _instance;
    if (inst != null) {
      await inst.dispose();
      _instance = null;
    }
  }
}
