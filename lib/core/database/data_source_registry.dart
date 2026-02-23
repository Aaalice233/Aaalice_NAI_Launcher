import '../utils/app_logger.dart';

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

/// 数据源状态
enum DataSourceState {
  uninitialized,
  initializing,
  ready,
  error,
  disposed,
}

/// 数据源信息
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

/// 健康状态
enum HealthStatus {
  healthy,
  degraded,
  corrupted,
  unknown,
}

/// 数据源健康信息
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

/// 数据源接口
abstract class DataSource {
  /// 数据源名称
  String get name;

  /// 数据源类型
  DataSourceType get type;

  /// 依赖的数据源名称集合
  Set<String> get dependencies;

  /// 初始化数据源
  Future<void> initialize();

  /// 释放数据源资源
  Future<void> dispose();

  /// 获取数据源状态
  DataSourceState get state;

  /// 获取数据源信息
  DataSourceInfo get info;

  /// 是否已初始化
  bool get isInitialized;

  /// 执行健康检查
  Future<DataSourceHealth> checkHealth();

  /// 清除数据
  Future<void> clear();

  /// 从预构建数据库恢复
  Future<void> restore();
}

/// 数据源注册表
///
/// 管理所有数据源的注册、初始化和生命周期
class DataSourceRegistry {
  DataSourceRegistry._();

  static final DataSourceRegistry _instance = DataSourceRegistry._();

  /// 获取单例实例
  static DataSourceRegistry get instance => _instance;

  final Map<String, DataSource> _sources = {};
  final Map<String, DataSourceInfo> _sourceInfos = {};
  bool _initialized = false;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 获取已注册的数据源数量
  int get sourceCount => _sources.length;

  /// 获取所有数据源名称
  List<String> get sourceNames => _sources.keys.toList();

  /// 初始化注册表
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.i('DataSourceRegistry initialized', 'DataSourceRegistry');
    _initialized = true;
  }

  /// 注册数据源
  ///
  /// [source] 要注册的数据源
  /// [autoInitialize] 是否自动初始化
  void register(DataSource source, {bool autoInitialize = false}) {
    if (_sources.containsKey(source.name)) {
      throw ArgumentError('DataSource "${source.name}" is already registered');
    }

    _sources[source.name] = source;
    _sourceInfos[source.name] = DataSourceInfo(
      name: source.name,
      type: source.type,
      state: DataSourceState.uninitialized,
    );

    AppLogger.d('Registered data source: ${source.name}', 'DataSourceRegistry');

    if (autoInitialize) {
      initializeSource(source.name);
    }
  }

  /// 取消注册数据源
  ///
  /// [name] 数据源名称
  /// [dispose] 是否释放资源
  Future<void> unregister(String name, {bool dispose = true}) async {
    final source = _sources[name];
    if (source == null) {
      AppLogger.w('DataSource "$name" not found', 'DataSourceRegistry');
      return;
    }

    if (dispose) {
      await source.dispose();
    }

    _sources.remove(name);
    _sourceInfos.remove(name);

    AppLogger.d('Unregistered data source: $name', 'DataSourceRegistry');
  }

  /// 初始化数据源
  ///
  /// [name] 数据源名称
  Future<void> initializeSource(String name) async {
    final source = _sources[name];
    if (source == null) {
      throw ArgumentError('DataSource "$name" not found');
    }

    _updateSourceInfo(name, DataSourceState.initializing);

    try {
      await source.initialize();
      _updateSourceInfo(
        name,
        DataSourceState.ready,
        initializedAt: DateTime.now(),
      );
      AppLogger.i('Initialized data source: $name', 'DataSourceRegistry');
    } catch (e, stack) {
      _updateSourceInfo(
        name,
        DataSourceState.error,
        errorMessage: e.toString(),
      );
      AppLogger.e(
        'Failed to initialize data source: $name',
        e,
        stack,
        'DataSourceRegistry',
      );
      rethrow;
    }
  }

  /// 初始化所有数据源
  ///
  /// [parallel] 是否并行初始化
  Future<void> initializeAll({bool parallel = false}) async {
    if (_sources.isEmpty) {
      AppLogger.d('No data sources to initialize', 'DataSourceRegistry');
      return;
    }

    AppLogger.i('Initializing all data sources (${_sources.length})', 'DataSourceRegistry');

    if (parallel) {
      await Future.wait(
        _sources.keys.map((name) => initializeSource(name).catchError((e) {
          AppLogger.w('Failed to initialize $name: $e', 'DataSourceRegistry');
        }),),
      );
    } else {
      for (final name in _sources.keys) {
        try {
          await initializeSource(name);
        } catch (e) {
          AppLogger.w('Failed to initialize $name: $e', 'DataSourceRegistry');
        }
      }
    }

    final readyCount = _sourceInfos.values.where((i) => i.isReady).length;
    AppLogger.i(
      'Data sources initialization complete: $readyCount/${_sources.length} ready',
      'DataSourceRegistry',
    );
  }

  /// 按依赖顺序初始化所有数据源
  ///
  /// 根据数据源之间的依赖关系，按正确顺序初始化。
  /// 首先初始化无依赖的数据源，然后初始化依赖已就绪的数据源。
  Future<void> initializeAllWithDependencies() async {
    if (_sources.isEmpty) {
      AppLogger.d('No data sources to initialize', 'DataSourceRegistry');
      return;
    }

    AppLogger.i(
      'Initializing data sources with dependency resolution (${_sources.length})',
      'DataSourceRegistry',
    );

    final initialized = <String>{};
    final failed = <String>{};
    var previousCount = -1;

    // 迭代初始化，直到没有新的数据源可以被初始化
    while (initialized.length + failed.length < _sources.length) {
      final readyToInit = <String>[];

      for (final entry in _sources.entries) {
        final name = entry.key;
        final source = entry.value;

        if (initialized.contains(name) || failed.contains(name)) {
          continue;
        }

        // 检查所有依赖是否已初始化
        final dependenciesReady = source.dependencies.every(
          (dep) => initialized.contains(dep),
        );

        if (dependenciesReady) {
          readyToInit.add(name);
        }
      }

      // 如果没有新的数据源可以初始化，检测循环依赖
      if (readyToInit.isEmpty) {
        if (initialized.length == previousCount) {
          final remaining = _sources.keys
              .where((n) => !initialized.contains(n) && !failed.contains(n))
              .toList();
          AppLogger.e(
            'Circular dependency detected or unresolvable dependencies: $remaining',
            null,
            null,
            'DataSourceRegistry',
          );
          throw StateError(
            'Unable to resolve dependencies for data sources: $remaining',
          );
        }
        break;
      }

      previousCount = initialized.length;

      // 并行初始化准备好的数据源
      await Future.wait(
        readyToInit.map((name) async {
          try {
            await initializeSource(name);
            initialized.add(name);
          } catch (e) {
            AppLogger.w('Failed to initialize $name: $e', 'DataSourceRegistry');
            failed.add(name);
          }
        }),
      );
    }

    AppLogger.i(
      'Data sources initialization complete: ${initialized.length}/${_sources.length} ready, ${failed.length} failed',
      'DataSourceRegistry',
    );

    if (failed.isNotEmpty) {
      AppLogger.w('Failed data sources: ${failed.join(', ')}', 'DataSourceRegistry');
    }
  }

  /// 释放所有数据源
  Future<void> disposeAll() async {
    AppLogger.i('Disposing all data sources', 'DataSourceRegistry');

    for (final source in _sources.values) {
      try {
        await source.dispose();
        _updateSourceInfo(source.name, DataSourceState.disposed);
      } catch (e, stack) {
        AppLogger.e(
          'Failed to dispose data source: ${source.name}',
          e,
          stack,
          'DataSourceRegistry',
        );
      }
    }

    _sources.clear();
    _sourceInfos.clear();
    _initialized = false;

    AppLogger.i('All data sources disposed', 'DataSourceRegistry');
  }

  /// 获取数据源
  ///
  /// [name] 数据源名称
  /// [throwIfNotReady] 如果数据源未就绪是否抛出异常
  T getSource<T extends DataSource>(String name, {bool throwIfNotReady = true}) {
    final source = _sources[name];
    if (source == null) {
      throw ArgumentError('DataSource "$name" not found');
    }

    if (throwIfNotReady && !source.info.isReady) {
      throw StateError('DataSource "$name" is not ready (state: ${source.info.state})');
    }

    return source as T;
  }

  /// 安全获取数据源
  ///
  /// 如果数据源不存在或未就绪，返回null
  T? tryGetSource<T extends DataSource>(String name) {
    final source = _sources[name];
    if (source == null || !source.info.isReady) {
      return null;
    }
    return source as T;
  }

  /// 获取数据源信息
  DataSourceInfo? getInfo(String name) {
    return _sourceInfos[name];
  }

  /// 获取所有数据源信息
  List<DataSourceInfo> getAllInfos() {
    return _sourceInfos.values.toList();
  }

  /// 获取指定类型的数据源
  List<DataSource> getSourcesByType(DataSourceType type) {
    return _sources.values.where((s) => s.type == type).toList();
  }

  /// 获取数据源的依赖列表
  ///
  /// [name] 数据源名称
  /// 返回依赖的数据源名称列表，如果数据源不存在则返回空列表
  List<String> getDependencies(String name) {
    final source = _sources[name];
    return source?.dependencies.toList() ?? [];
  }

  /// 检查数据源是否已注册
  bool isRegistered(String name) {
    return _sources.containsKey(name);
  }

  /// 检查数据源是否就绪
  bool isReady(String name) {
    return _sourceInfos[name]?.isReady ?? false;
  }

  /// 等待数据源就绪
  ///
  /// [name] 数据源名称
  /// [timeout] 超时时间
  Future<bool> waitForReady(String name, {Duration? timeout}) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < effectiveTimeout) {
      if (isReady(name)) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return false;
  }

  /// 等待所有数据源就绪
  ///
  /// [timeout] 每个数据源的超时时间
  Future<bool> waitForAllReady({Duration? timeout}) async {
    for (final name in _sources.keys) {
      final ready = await waitForReady(name, timeout: timeout);
      if (!ready) {
        return false;
      }
    }
    return true;
  }

  /// 更新数据源信息
  void _updateSourceInfo(
    String name,
    DataSourceState state, {
    String? errorMessage,
    DateTime? initializedAt,
  }) {
    final current = _sourceInfos[name];
    if (current == null) return;

    _sourceInfos[name] = current.copyWith(
      state: state,
      errorMessage: errorMessage,
      initializedAt: initializedAt ?? current.initializedAt,
    );
  }

  /// 获取注册表统计信息
  Map<String, dynamic> getStatistics() {
    final infos = _sourceInfos.values.toList();

    return {
      'total': infos.length,
      'ready': infos.where((i) => i.isReady).length,
      'initializing': infos.where((i) => i.state == DataSourceState.initializing).length,
      'error': infos.where((i) => i.hasError).length,
      'uninitialized': infos.where((i) => i.state == DataSourceState.uninitialized).length,
      'sources': infos.map((i) => {
        'name': i.name,
        'type': i.type.name,
        'state': i.state.name,
        'ready': i.isReady,
      },).toList(),
    };
  }

  /// 重置注册表
  Future<void> reset() async {
    await disposeAll();
    AppLogger.d('DataSourceRegistry reset', 'DataSourceRegistry');
  }
}
