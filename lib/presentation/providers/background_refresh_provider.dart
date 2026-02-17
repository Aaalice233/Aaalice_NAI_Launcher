import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/lazy_data_source_service.dart';
import '../../core/utils/app_logger.dart';

part 'background_refresh_provider.g.dart';

/// 后台刷新状态
class BackgroundRefreshState {
  /// 当前正在刷新的数据源名称列表
  final List<String> activeRefreshes;

  /// 已完成的刷新
  final List<String> completedRefreshes;

  /// 失败的刷新
  final Map<String, String> failedRefreshes;

  /// 是否正在显示进度提示
  final bool showProgressIndicator;

  /// 总体进度 (0.0 - 1.0)
  final double overallProgress;

  /// 当前阶段描述
  final String currentPhase;

  const BackgroundRefreshState({
    this.activeRefreshes = const [],
    this.completedRefreshes = const [],
    this.failedRefreshes = const {},
    this.showProgressIndicator = false,
    this.overallProgress = 0.0,
    this.currentPhase = '',
  });

  factory BackgroundRefreshState.initial() => const BackgroundRefreshState();

  bool get isRefreshing => activeRefreshes.isNotEmpty;

  bool get hasCompleted => completedRefreshes.isNotEmpty;

  bool get hasFailed => failedRefreshes.isNotEmpty;

  BackgroundRefreshState copyWith({
    List<String>? activeRefreshes,
    List<String>? completedRefreshes,
    Map<String, String>? failedRefreshes,
    bool? showProgressIndicator,
    double? overallProgress,
    String? currentPhase,
  }) {
    return BackgroundRefreshState(
      activeRefreshes: activeRefreshes ?? this.activeRefreshes,
      completedRefreshes: completedRefreshes ?? this.completedRefreshes,
      failedRefreshes: failedRefreshes ?? this.failedRefreshes,
      showProgressIndicator: showProgressIndicator ?? this.showProgressIndicator,
      overallProgress: overallProgress ?? this.overallProgress,
      currentPhase: currentPhase ?? this.currentPhase,
    );
  }
}

/// 后台刷新管理器
/// 
/// 负责在进入主界面后检查并执行数据源的后台刷新
/// 非阻塞执行，不影响用户使用
@riverpod
class BackgroundRefreshNotifier extends _$BackgroundRefreshNotifier {
  final List<LazyDataSourceService> _services = [];

  @override
  BackgroundRefreshState build() {
    // 启动时检查是否需要刷新
    _checkAndRefresh();
    return BackgroundRefreshState.initial();
  }

  /// 注册数据源服务
  void registerServices(List<LazyDataSourceService> services) {
    _services.addAll(services);
  }

  /// 检查并执行后台刷新
  Future<void> _checkAndRefresh() async {
    // 延迟执行，确保主界面已加载
    await Future.delayed(const Duration(seconds: 2));

    // 检查是否有待处理的刷新标记
    final prefs = await SharedPreferences.getInstance();
    final hasPendingRefresh = prefs.getBool(StorageKeys.pendingDataSourceRefresh) ?? false;

    if (hasPendingRefresh) {
      AppLogger.i('Pending refresh detected, starting background refresh', 'BackgroundRefresh');
      // 清除标记
      await prefs.setBool(StorageKeys.pendingDataSourceRefresh, false);
    }

    // 注册所有数据源服务
    await _registerAllServices();

    // 获取所有需要刷新的数据源
    final servicesToRefresh = <LazyDataSourceService>[];
    for (final service in _services) {
      try {
        if (await service.shouldRefresh()) {
          servicesToRefresh.add(service);
        }
      } catch (e) {
        AppLogger.w(
          'Failed to check refresh status for ${service.serviceName}: $e',
          'BackgroundRefresh',
        );
      }
    }

    if (servicesToRefresh.isEmpty) {
      AppLogger.i('No data sources need refresh', 'BackgroundRefresh');
      return;
    }

    AppLogger.i(
      'Starting background refresh for ${servicesToRefresh.length} data sources',
      'BackgroundRefresh',
    );

    // 显示轻量级进度提示
    state = state.copyWith(
      showProgressIndicator: true,
      currentPhase: '正在更新数据...',
    );

    // 并行执行所有刷新任务
    final totalServices = servicesToRefresh.length;
    var completedCount = 0;

    await Future.wait(
      servicesToRefresh.map((service) async {
        await _refreshService(service);
        completedCount++;
        
        // 更新总体进度
        state = state.copyWith(
          overallProgress: completedCount / totalServices,
        );
      }),
    );

    // 隐藏进度提示（延迟一点，让用户看到完成状态）
    await Future.delayed(const Duration(seconds: 1));
    state = state.copyWith(showProgressIndicator: false);

    // 记录刷新结果
    AppLogger.i(
      'Background refresh completed: ${state.completedRefreshes.length} succeeded, '
      '${state.failedRefreshes.length} failed',
      'BackgroundRefresh',
    );
  }

  /// 注册所有数据源服务
  Future<void> _registerAllServices() async {
    // 注意：这里使用 ref.read 获取服务实例
    // 由于 build 方法中不能直接使用 ref，我们需要延迟获取
    Future.microtask(() {
      try {
        final danbooruTagsService = ref.read(danbooruTagsLazyServiceProvider);

        registerServices([
          danbooruTagsService,
        ]);
      } catch (e) {
        AppLogger.w('Failed to register some services: $e', 'BackgroundRefresh');
      }
    });
  }

  /// 刷新单个数据源
  Future<void> _refreshService(LazyDataSourceService service) async {
    // 添加到活跃刷新列表
    state = state.copyWith(
      activeRefreshes: [...state.activeRefreshes, service.serviceName],
      currentPhase: '正在更新 ${service.serviceName}...',
    );

    try {
      AppLogger.i('Background refreshing: ${service.serviceName}', 'BackgroundRefresh');

      // 设置进度回调
      service.onProgress = (progress, message) {
        state = state.copyWith(
          currentPhase: message ?? '正在更新 ${service.serviceName}...',
        );
      };

      await service.refresh();

      // 刷新成功
      state = state.copyWith(
        activeRefreshes: state.activeRefreshes
            .where((n) => n != service.serviceName)
            .toList(),
        completedRefreshes: [...state.completedRefreshes, service.serviceName],
      );

      AppLogger.i('Background refresh completed: ${service.serviceName}', 'BackgroundRefresh');
    } catch (e) {
      // 刷新失败
      state = state.copyWith(
        activeRefreshes: state.activeRefreshes
            .where((n) => n != service.serviceName)
            .toList(),
        failedRefreshes: {
          ...state.failedRefreshes,
          service.serviceName: e.toString(),
        },
      );

      AppLogger.e(
        'Background refresh failed for ${service.serviceName}',
        e,
        null,
        'BackgroundRefresh',
      );
    } finally {
      service.onProgress = null;
    }
  }

  /// 手动触发刷新
  Future<void> refreshAll() async {
    await _checkAndRefresh();
  }

  /// 清除失败记录
  void clearFailedRefreshes() {
    state = state.copyWith(failedRefreshes: {});
  }

  /// 重试失败的刷新
  Future<void> retryFailed() async {
    final failedServices = state.failedRefreshes.keys.toList();
    if (failedServices.isEmpty) return;

    state = state.copyWith(
      failedRefreshes: {},
      showProgressIndicator: true,
    );

    // 找到对应的服务实例并重试
    for (final serviceName in failedServices) {
      final service = _services.firstWhere(
        (s) => s.serviceName == serviceName,
        orElse: () => throw StateError('Service $serviceName not found'),
      );
      await _refreshService(service);
    }

    state = state.copyWith(showProgressIndicator: false);
  }
}

/// 后台刷新状态监听 Provider
/// 
/// 用于在 UI 中显示后台刷新状态
@riverpod
Stream<BackgroundRefreshState> backgroundRefreshStateStream(Ref ref) {
  // 返回一个基于 notifier 状态的流
  return Stream.periodic(
    const Duration(milliseconds: 100),
    (_) => ref.read(backgroundRefreshNotifierProvider),
  ).distinct();
}
