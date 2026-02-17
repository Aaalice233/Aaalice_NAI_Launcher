import '../utils/app_logger.dart';

/// 数据源状态
enum DataSourceState {
  uninitialized,
  initializing,
  ready,
  error,
  disposed,
}

/// 数据源类型
enum DataSourceType {
  gallery,
  metadata,
  tags,
  favorites,
  search,
  settings,
  translation,
  cooccurrence,
  danbooruTag,
}

/// 健康状态
enum HealthStatus {
  healthy,
  degraded,
  corrupted,
  unknown,
}

/// 健康检查结果
class DataSourceHealth {
  final HealthStatus status;
  final String message;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  const DataSourceHealth({
    required this.status,
    required this.message,
    this.details = const {},
    required this.timestamp,
  });

  bool get isHealthy => status == HealthStatus.healthy;
  bool get isCorrupted => status == HealthStatus.corrupted;
}

/// 数据源元数据信息
class DataSourceInfo {
  final String name;
  final DataSourceType type;
  final DataSourceState state;
  final String? errorMessage;
  final DateTime? initializedAt;
  final Map<String, dynamic> metadata;

  const DataSourceInfo({
    required this.name,
    required this.type,
    required this.state,
    this.errorMessage,
    this.initializedAt,
    this.metadata = const {},
  });

  DataSourceInfo copyWith({
    String? name,
    DataSourceType? type,
    DataSourceState? state,
    String? errorMessage,
    DateTime? initializedAt,
    Map<String, dynamic>? metadata,
  }) {
    return DataSourceInfo(
      name: name ?? this.name,
      type: type ?? this.type,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      initializedAt: initializedAt ?? this.initializedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isReady => state == DataSourceState.ready;
  bool get hasError => state == DataSourceState.error;
}

/// 数据源接口
///
/// 定义所有数据源必须实现的基本生命周期方法和功能。
/// 数据源负责管理特定领域的数据访问，提供缓存、健康检查和恢复功能。
abstract class DataSource {
  /// 数据源名称（唯一标识符）
  String get name;

  /// 数据源类型
  DataSourceType get type;

  /// 依赖的数据源名称集合
  /// 用于定义数据源之间的初始化顺序依赖
  Set<String> get dependencies;

  /// 当前状态
  DataSourceState get state;

  /// 数据源信息
  DataSourceInfo get info;

  /// 是否已初始化
  bool get isInitialized => state == DataSourceState.ready;

  /// 初始化数据源
  ///
  /// 在调用此方法前，必须确保所有依赖的数据源已初始化完成。
  /// 初始化过程中应建立数据库连接、加载必要的数据和配置。
  Future<void> initialize();

  /// 执行健康检查
  ///
  /// 检查数据源的可用性和数据完整性。
  /// 返回详细的健康状态信息。
  Future<DataSourceHealth> checkHealth();

  /// 清除数据
  ///
  /// 清除所有缓存数据，但不释放数据源本身。
  /// 可用于内存不足时的清理或数据重置。
  Future<void> clear();

  /// 从预构建数据库恢复数据
  ///
  /// 从预构建的数据库文件中恢复数据。
  /// 用于首次安装或数据损坏时的数据恢复。
  Future<void> restore();

  /// 释放数据源资源
  ///
  /// 关闭数据库连接、释放缓存、清理资源。
  /// 数据源被注销时自动调用。
  Future<void> dispose();
}

/// 基础数据源实现
///
/// 提供通用的状态管理和日志功能，具体数据源可以继承此类。
abstract class BaseDataSource implements DataSource {
  DataSourceState _state = DataSourceState.uninitialized;
  String? _errorMessage;
  DateTime? _initializedAt;

  @override
  DataSourceState get state => _state;

  @override
  DataSourceInfo get info => DataSourceInfo(
        name: name,
        type: type,
        state: _state,
        errorMessage: _errorMessage,
        initializedAt: _initializedAt,
      );

  @override
  bool get isInitialized => _state == DataSourceState.ready;

  /// 设置状态为初始化中
  void _setInitializing() {
    _state = DataSourceState.initializing;
    _errorMessage = null;
    AppLogger.d('DataSource "$name" initializing', 'DataSource');
  }

  /// 设置状态为就绪
  void _setReady() {
    _state = DataSourceState.ready;
    _initializedAt = DateTime.now();
    AppLogger.i('DataSource "$name" ready', 'DataSource');
  }

  /// 设置状态为错误
  void _setError(String message) {
    _state = DataSourceState.error;
    _errorMessage = message;
    AppLogger.e('DataSource "$name" error: $message', null, null, 'DataSource');
  }

  /// 设置状态为已释放
  void _setDisposed() {
    _state = DataSourceState.disposed;
    AppLogger.d('DataSource "$name" disposed', 'DataSource');
  }

  /// 子类实现的初始化逻辑
  Future<void> doInitialize();

  /// 子类实现的健康检查逻辑
  Future<DataSourceHealth> doCheckHealth();

  /// 子类实现的清除逻辑
  Future<void> doClear();

  /// 子类实现的恢复逻辑
  Future<void> doRestore();

  /// 子类实现的释放逻辑
  Future<void> doDispose();

  @override
  Future<void> initialize() async {
    if (_state == DataSourceState.ready) {
      AppLogger.d('DataSource "$name" already initialized', 'DataSource');
      return;
    }

    _setInitializing();

    try {
      await doInitialize();
      _setReady();
    } catch (e, stack) {
      _setError(e.toString());
      AppLogger.e(
        'Failed to initialize DataSource "$name"',
        e,
        stack,
        'DataSource',
      );
      rethrow;
    }
  }

  @override
  Future<DataSourceHealth> checkHealth() async {
    try {
      if (_state != DataSourceState.ready) {
        return DataSourceHealth(
          status: HealthStatus.unknown,
          message: 'DataSource not ready (state: $_state)',
          timestamp: DateTime.now(),
        );
      }

      return await doCheckHealth();
    } catch (e, stack) {
      AppLogger.e(
        'Health check failed for DataSource "$name"',
        e,
        stack,
        'DataSource',
      );
      return DataSourceHealth(
        status: HealthStatus.corrupted,
        message: 'Health check failed: $e',
        details: {'error': e.toString()},
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await doClear();
      AppLogger.i('DataSource "$name" cleared', 'DataSource');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to clear DataSource "$name"',
        e,
        stack,
        'DataSource',
      );
      rethrow;
    }
  }

  @override
  Future<void> restore() async {
    try {
      await doRestore();
      AppLogger.i('DataSource "$name" restored', 'DataSource');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to restore DataSource "$name"',
        e,
        stack,
        'DataSource',
      );
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await doDispose();
      _setDisposed();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to dispose DataSource "$name"',
        e,
        stack,
        'DataSource',
      );
    }
  }
}
