import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';
import 'base_data_source.dart';
import 'connection_pool_holder.dart';
import 'data_source.dart' hide BaseDataSource;
import 'data_source_registry.dart' as registry;

/// DataSourceProvider 状态
class DataSourceProviderState {
  final Map<String, EnhancedBaseDataSource> _dataSources;
  final Map<String, DataSourceHealth> _healthStatus;
  final bool isDisposed;

  const DataSourceProviderState({
    Map<String, EnhancedBaseDataSource>? dataSources,
    Map<String, DataSourceHealth>? healthStatus,
    this.isDisposed = false,
  })  : _dataSources = dataSources ?? const {},
        _healthStatus = healthStatus ?? const {};

  DataSourceProviderState copyWith({
    Map<String, EnhancedBaseDataSource>? dataSources,
    Map<String, DataSourceHealth>? healthStatus,
    bool? isDisposed,
  }) {
    return DataSourceProviderState(
      dataSources: dataSources ?? _dataSources,
      healthStatus: healthStatus ?? _healthStatus,
      isDisposed: isDisposed ?? this.isDisposed,
    );
  }

  /// 获取所有数据源
  Map<String, EnhancedBaseDataSource> get dataSources =>
      Map.unmodifiable(_dataSources);

  /// 获取所有健康状态
  Map<String, DataSourceHealth> get healthStatus =>
      Map.unmodifiable(_healthStatus);

  /// 获取指定数据源
  EnhancedBaseDataSource? getDataSource(String name) => _dataSources[name];

  /// 获取指定数据源健康状态
  DataSourceHealth? getHealth(String name) => _healthStatus[name];

  /// 检查数据源是否健康
  bool isHealthy(String name) {
    final health = _healthStatus[name];
    return health?.isHealthy ?? false;
  }

  /// 获取所有健康的数据源名称
  List<String> get healthyDataSources => _healthStatus.entries
      .where((e) => e.value.isHealthy)
      .map((e) => e.key)
      .toList();
}

/// DataSourceProvider
///
/// 管理所有 DataSource 的生命周期，提供：
/// - DataSource 注册和获取
/// - 自动初始化
/// - 健康检查
/// - 自动重连支持
/// - 与 Riverpod 集成
class DataSourceProvider extends StateNotifier<DataSourceProviderState> {
  final registry.DataSourceRegistry _registry;

  DataSourceProvider({registry.DataSourceRegistry? explicitRegistry})
      : _registry = explicitRegistry ?? registry.DataSourceRegistry.instance,
        super(const DataSourceProviderState());

  /// 注册数据源
  ///
  /// [name] 数据源名称（唯一标识）
  /// [dataSource] 数据源实例
  /// [autoInitialize] 是否自动初始化（默认true）
  Future<void> register(
    String name,
    EnhancedBaseDataSource dataSource, {
    bool autoInitialize = true,
  }) async {
    if (state.isDisposed) {
      throw StateError('DataSourceProvider is disposed');
    }

    // 添加到注册表
    _registry.register(dataSource as registry.DataSource, autoInitialize: false);

    // 更新状态
    final newDataSources =
        Map<String, EnhancedBaseDataSource>.from(state._dataSources);
    newDataSources[name] = dataSource;
    state = state.copyWith(dataSources: newDataSources);

    AppLogger.i('Registered DataSource: $name', 'DataSourceProvider');

    // 自动初始化
    if (autoInitialize) {
      await initializeDataSource(name);
    }
  }

  /// 注销数据源
  ///
  /// [name] 数据源名称
  /// [dispose] 是否释放资源（默认true）
  Future<void> unregister(String name, {bool dispose = true}) async {
    final dataSource = state._dataSources[name];
    if (dataSource == null) return;

    // 从注册表移除
    await _registry.unregister(name, dispose: dispose);

    // 更新状态
    final newDataSources =
        Map<String, EnhancedBaseDataSource>.from(state._dataSources);
    newDataSources.remove(name);

    final newHealth = Map<String, DataSourceHealth>.from(state._healthStatus);
    newHealth.remove(name);

    state = state.copyWith(
      dataSources: newDataSources,
      healthStatus: newHealth,
    );

    AppLogger.i('Unregistered DataSource: $name', 'DataSourceProvider');
  }

  /// 初始化指定数据源
  ///
  /// [name] 数据源名称
  Future<void> initializeDataSource(String name) async {
    final dataSource = state._dataSources[name];
    if (dataSource == null) {
      throw StateError('DataSource not found: $name');
    }

    try {
      await dataSource.initialize();

      // 执行健康检查
      final health = await dataSource.checkHealth();
      _updateHealth(name, health);

      AppLogger.i('Initialized DataSource: $name', 'DataSourceProvider');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize DataSource: $name',
        e,
        stack,
        'DataSourceProvider',
      );
      rethrow;
    }
  }

  /// 初始化所有数据源
  ///
  /// 按依赖顺序初始化
  Future<void> initializeAll() async {
    // 等待连接池初始化
    await _waitForConnectionPool();

    // 从注册表获取所有数据源
    final allNames = _registry.sourceNames;

    for (final name in allNames) {
      final dataSource = _registry.tryGetSource(name) as dynamic;

      // 检查是否是 EnhancedBaseDataSource
      if (dataSource is EnhancedBaseDataSource) {
        // 检查是否已在状态中
        if (!state._dataSources.containsKey(name)) {
          final newDataSources =
              Map<String, EnhancedBaseDataSource>.from(state._dataSources);
          newDataSources[name] = dataSource;
          state = state.copyWith(dataSources: newDataSources);
        }

        await initializeDataSource(name);
      }
    }

    AppLogger.i(
      'All DataSources initialized: ${allNames.length}',
      'DataSourceProvider',
    );
  }

  /// 检查所有数据源健康状态
  ///
  /// 返回不健康的数据源列表
  Future<List<String>> checkAllHealth() async {
    final unhealthy = <String>[];

    for (final entry in state._dataSources.entries) {
      final name = entry.key;
      final dataSource = entry.value;

      try {
        final health = await dataSource.checkHealth();
        _updateHealth(name, health);

        if (!health.isHealthy) {
          unhealthy.add(name);
        }
      } catch (e, stack) {
        AppLogger.e(
          'Health check failed for $name',
          e,
          stack,
          'DataSourceProvider',
        );
        unhealthy.add(name);
      }
    }

    return unhealthy;
  }

  /// 检查指定数据源健康状态
  ///
  /// [name] 数据源名称
  Future<DataSourceHealth?> checkHealth(String name) async {
    final dataSource = state._dataSources[name];
    if (dataSource == null) return null;

    final health = await dataSource.checkHealth();
    _updateHealth(name, health);
    return health;
  }

  /// 尝试恢复不健康的数据源
  ///
  /// [name] 数据源名称
  /// 返回是否恢复成功
  Future<bool> tryRecover(String name) async {
    final dataSource = state._dataSources[name];
    if (dataSource == null) return false;

    AppLogger.w(
      'Attempting to recover DataSource: $name',
      'DataSourceProvider',
    );

    try {
      // 先清除
      await dataSource.clear();

      // 重新初始化
      await dataSource.initialize();

      // 检查健康状态
      final health = await dataSource.checkHealth();
      _updateHealth(name, health);

      if (health.isHealthy) {
        AppLogger.i('Recovered DataSource: $name', 'DataSourceProvider');
        return true;
      } else {
        AppLogger.w(
          'Recovery failed for $name: ${health.message}',
          'DataSourceProvider',
        );
        return false;
      }
    } catch (e, stack) {
      AppLogger.e(
        'Recovery failed for $name',
        e,
        stack,
        'DataSourceProvider',
      );
      return false;
    }
  }

  /// 尝试恢复所有不健康的数据源
  ///
  /// 返回恢复成功的数据源列表
  Future<List<String>> tryRecoverAll() async {
    final unhealthy = await checkAllHealth();
    final recovered = <String>[];

    for (final name in unhealthy) {
      if (await tryRecover(name)) {
        recovered.add(name);
      }
    }

    return recovered;
  }

  /// 获取数据源
  ///
  /// [name] 数据源名称
  T? getDataSource<T extends EnhancedBaseDataSource>(String name) {
    return state._dataSources[name] as T?;
  }

  /// 获取或抛出
  ///
  /// [name] 数据源名称
  T getDataSourceOrThrow<T extends EnhancedBaseDataSource>(String name) {
    final ds = getDataSource<T>(name);
    if (ds == null) {
      throw StateError('DataSource not found: $name');
    }
    return ds;
  }

  /// 更新健康状态
  void _updateHealth(String name, DataSourceHealth health) {
    final newHealth = Map<String, DataSourceHealth>.from(state._healthStatus);
    newHealth[name] = health;
    state = state.copyWith(healthStatus: newHealth);
  }

  /// 等待连接池初始化
  Future<void> _waitForConnectionPool() async {
    var attempts = 0;
    const maxAttempts = 50;

    while (!ConnectionPoolHolder.isInitialized && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!ConnectionPoolHolder.isInitialized) {
      throw StateError('Connection pool not initialized after 5s');
    }
  }

  /// 清除所有数据源缓存
  Future<void> clearAllCaches() async {
    for (final dataSource in state._dataSources.values) {
      await dataSource.clear();
    }
    AppLogger.i('All DataSource caches cleared', 'DataSourceProvider');
  }

  /// 释放所有数据源
  @override
  Future<void> dispose() async {
    if (state.isDisposed) return;

    // 释放所有数据源
    for (final dataSource in state._dataSources.values) {
      await dataSource.dispose();
    }

    state = state.copyWith(isDisposed: true);

    AppLogger.i('DataSourceProvider disposed', 'DataSourceProvider');
    super.dispose();
  }

  /// 获取诊断信息
  Map<String, dynamic> getDiagnostics() {
    return {
      'dataSourceCount': state._dataSources.length,
      'dataSources': state._dataSources.map(
        (name, ds) => MapEntry(
          name,
          {
            'type': ds.type.toString(),
            'state': ds.state.toString(),
            'isInitialized': ds.isInitialized,
          },
        ),
      ),
      'healthStatus': state._healthStatus.map(
        (name, health) => MapEntry(
          name,
          {
            'status': health.status.toString(),
            'message': health.message,
          },
        ),
      ),
      'isDisposed': state.isDisposed,
    };
  }
}

/// Riverpod Provider
///
/// 全局 DataSourceProvider 实例
final dataSourceProvider =
    StateNotifierProvider<DataSourceProvider, DataSourceProviderState>((ref) {
  final provider = DataSourceProvider();

  // 自动初始化
  provider.initializeAll();

  // 在 Provider 销毁时清理
  ref.onDispose(() {
    provider.dispose();
  });

  return provider;
});

/// 特定 DataSource Provider
///
/// 用于获取特定的 DataSource
///
/// 使用示例：
/// ```dart
/// final galleryDataSource = ref.watch(galleryDataSourceProvider);
/// ```
final specificDataSourceProvider =
    Provider.family<EnhancedBaseDataSource?, String>((ref, name) {
  final state = ref.watch(dataSourceProvider);
  return state.getDataSource(name);
});

/// DataSource 健康状态 Stream Provider
///
/// 用于监控 DataSource 健康状态变化
final dataSourceHealthStreamProvider =
    StreamProvider.family<DataSourceHealth, String>((ref, name) async* {
  final initialState = ref.read(dataSourceProvider);

  // 初始状态
  final initialHealth = initialState.getHealth(name);
  if (initialHealth != null) {
    yield initialHealth;
  }

  // 监听状态变化
  await for (final state in ref.watch(
    dataSourceProvider.select(
      (s) => Stream.periodic(
        const Duration(seconds: 1),
        (_) => s,
      ),
    ),
  )) {
    final health = state.getHealth(name);
    if (health != null) {
      yield health;
    }
  }
});
