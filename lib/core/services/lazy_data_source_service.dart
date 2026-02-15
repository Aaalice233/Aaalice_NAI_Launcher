import 'dart:async';

import '../utils/app_logger.dart';

/// 数据源初始化进度
class DataSourceInitProgress {
  /// 数据源名称
  final String sourceName;

  /// 总体进度 (0.0 - 1.0)
  final double overallProgress;

  /// 当前阶段描述
  final String currentPhase;

  /// 是否完成
  final bool isComplete;

  /// 错误信息（如有）
  final String? error;

  const DataSourceInitProgress({
    required this.sourceName,
    required this.overallProgress,
    required this.currentPhase,
    this.isComplete = false,
    this.error,
  });

  factory DataSourceInitProgress.initial(String sourceName) =>
      DataSourceInitProgress(
        sourceName: sourceName,
        overallProgress: 0.0,
        currentPhase: '准备中',
      );

  factory DataSourceInitProgress.complete(String sourceName) =>
      DataSourceInitProgress(
        sourceName: sourceName,
        overallProgress: 1.0,
        currentPhase: '完成',
        isComplete: true,
      );
}

/// 刷新进度回调
typedef DataSourceProgressCallback = void Function(
  double progress,
  String? message,
);

/// 懒加载数据源接口
/// 统一共现数据、翻译数据、Danbooru标签的数据源架构
abstract class LazyDataSourceService<T> {
  /// 服务名称
  String get serviceName;

  /// 热数据键集合（启动时预加载到内存）
  Set<String> get hotKeys;

  /// 是否已初始化
  bool get isInitialized;

  /// 是否正在刷新
  bool get isRefreshing;

  /// 刷新进度回调
  DataSourceProgressCallback? onProgress;

  /// 初始化（加载热数据到内存）
  /// 这是预热阶段调用的方法，应该快速完成
  Future<void> initialize();

  /// 获取单个数据
  /// 优先从内存缓存获取，未命中则从SQLite加载
  Future<T?> get(String key);

  /// 批量获取数据
  /// 用于标签输入框的联想功能
  Future<List<T>> getMultiple(List<String> keys);

  /// 检查是否需要刷新（基于上次更新时间）
  Future<bool> shouldRefresh();

  /// 执行刷新（后台下载新数据）
  /// 这是进入主界面后后台执行的方法
  Future<void> refresh();

  /// 清除所有缓存数据
  Future<void> clearCache();
}

/// 统一的数据源管理器
/// 管理所有懒加载数据源的初始化和刷新
class UnifiedDataSourceManager {
  final List<LazyDataSourceService> _services = [];

  /// 注册数据源
  void register(LazyDataSourceService service) {
    _services.add(service);
    AppLogger.i(
      'Registered lazy data source: ${service.serviceName}',
      'UnifiedDataSource',
    );
  }

  /// 获取所有注册的数据源
  List<LazyDataSourceService> get services => List.unmodifiable(_services);

  /// 初始化所有数据源（并行）
  /// 返回进度流，包含每个数据源的初始化进度
  Stream<DataSourceInitProgress> initializeAll() async* {
    if (_services.isEmpty) {
      yield DataSourceInitProgress.complete('all');
      return;
    }

    // 为每个数据源创建初始进度
    final progressMap = <String, DataSourceInitProgress>{};
    for (final service in _services) {
      progressMap[service.serviceName] =
          DataSourceInitProgress.initial(service.serviceName);
    }

    // 并行初始化所有数据源
    final futures = _services.map((service) async {
      try {
        // 设置进度回调
        service.onProgress = (progress, message) {
          progressMap[service.serviceName] = DataSourceInitProgress(
            sourceName: service.serviceName,
            overallProgress: progress,
            currentPhase: message ?? '加载中',
          );
        };

        await service.initialize();

        progressMap[service.serviceName] = DataSourceInitProgress.complete(
          service.serviceName,
        );
      } catch (e) {
        AppLogger.e(
          'Failed to initialize ${service.serviceName}',
          e,
          null,
          'UnifiedDataSource',
        );
        progressMap[service.serviceName] = DataSourceInitProgress(
          sourceName: service.serviceName,
          overallProgress: 0.0,
          currentPhase: '初始化失败',
          error: e.toString(),
        );
      }
    }).toList();

    // 等待所有初始化完成
    await Future.wait(futures);

    // 发送最终完成进度
    yield DataSourceInitProgress.complete('all');
  }

  /// 获取所有需要刷新的数据源
  Future<List<LazyDataSourceService>> getServicesNeedingRefresh() async {
    final result = <LazyDataSourceService>[];

    for (final service in _services) {
      try {
        if (await service.shouldRefresh()) {
          result.add(service);
        }
      } catch (e) {
        AppLogger.w(
          'Failed to check refresh status for ${service.serviceName}: $e',
          'UnifiedDataSource',
        );
      }
    }

    return result;
  }

  /// 后台刷新所有需要刷新的数据源
  /// 非阻塞执行，返回刷新完成后的回调
  Future<void> refreshAllInBackground() async {
    final servicesToRefresh = await getServicesNeedingRefresh();

    if (servicesToRefresh.isEmpty) {
      AppLogger.i('No data sources need refresh', 'UnifiedDataSource');
      return;
    }

    AppLogger.i(
      'Starting background refresh for ${servicesToRefresh.length} data sources',
      'UnifiedDataSource',
    );

    // 并行执行所有刷新任务
    await Future.wait(
      servicesToRefresh.map((service) async {
        try {
          AppLogger.i(
            'Background refreshing: ${service.serviceName}',
            'UnifiedDataSource',
          );
          await service.refresh();
          AppLogger.i(
            'Background refresh completed: ${service.serviceName}',
            'UnifiedDataSource',
          );
        } catch (e) {
          AppLogger.e(
            'Background refresh failed for ${service.serviceName}',
            e,
            null,
            'UnifiedDataSource',
          );
        }
      }),
    );
  }

  /// 清除所有数据源的缓存
  Future<void> clearAllCaches() async {
    for (final service in _services) {
      try {
        await service.clearCache();
      } catch (e) {
        AppLogger.w(
          'Failed to clear cache for ${service.serviceName}: $e',
          'UnifiedDataSource',
        );
      }
    }
  }
}

/// 懒加载数据源接口 V2
/// 支持三阶段预热架构
abstract class LazyDataSourceServiceV2<T> implements LazyDataSourceService<T> {
  /// 初始化轻量级版本（仅建表/检查状态，不加载大量数据）
  /// 在 Critical 阶段调用
  Future<void> initializeLightweight();

  /// 后台预加载热数据
  /// 在 Background 阶段调用
  Future<void> preloadHotDataInBackground();

  /// 设置后台进度回调
  set onBackgroundProgress(DataSourceProgressCallback? callback);

  /// 是否需要后台刷新（基于上次更新时间）
  Future<bool> shouldRefreshInBackground();

  /// 取消后台操作
  void cancelBackgroundOperation();
}

/// 统一的数据源管理器 V2
class UnifiedDataSourceManagerV2 extends UnifiedDataSourceManager {
  final Map<String, LazyDataSourceServiceV2> _servicesV2 = {};

  /// 注册 V2 数据源
  void registerV2(LazyDataSourceServiceV2 service) {
    _servicesV2[service.serviceName] = service;
    super.register(service);
  }

  /// 阶段 1: 轻量级初始化所有数据源
  Future<void> initializeAllLightweight() async {
    for (final service in _servicesV2.values) {
      try {
        AppLogger.i('Lightweight init: ${service.serviceName}', 'UnifiedDataSourceV2');
        await service.initializeLightweight();
      } catch (e) {
        AppLogger.w('Lightweight init failed for ${service.serviceName}: $e', 'UnifiedDataSourceV2');
      }
    }
  }

  /// 阶段 3: 后台预加载热数据
  Future<void> preloadAllHotDataInBackground() async {
    await Future.wait(
      _servicesV2.values.map((service) async {
        try {
          await service.preloadHotDataInBackground();
        } catch (e) {
          AppLogger.w('Hot data preload failed for ${service.serviceName}: $e', 'UnifiedDataSourceV2');
        }
      }),
    );
  }
}
