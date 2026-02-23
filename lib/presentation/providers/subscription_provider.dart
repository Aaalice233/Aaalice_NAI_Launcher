import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_user_info_api_service.dart';
import '../../data/models/user/user_subscription.dart';
import '../../data/services/anlas_statistics_service.dart';
import 'auth_provider.dart';

part 'subscription_provider.g.dart';

/// 订阅状态 Notifier
///
/// 管理用户订阅信息和 Anlas 余额
@riverpod
class SubscriptionNotifier extends _$SubscriptionNotifier {
  AuthState? _previousAuthState;
  bool _hasInitiallyLoaded = false;
  Timer? _refreshTimer;
  Future<void>? _inflightFetch;
  bool _isRefreshingBalance = false;
  Timer? _networkRecoveryProbeTimer;
  bool _isNetworkRecoveryProbing = false;
  int _networkFailureCount = 0;

  /// 自动刷新间隔
  static const Duration _refreshInterval = Duration(seconds: 5);
  static const Duration _initialFetchTimeout = Duration(seconds: 6);
  static const Duration _maxBackoffInterval = Duration(minutes: 2);
  static const Duration _networkProbeInterval = Duration(seconds: 3);
  static const Duration _networkProbeTimeout = Duration(seconds: 2);

  @override
  SubscriptionState build() {
    ref.keepAlive();

    // Watch authentication state changes
    final authState = ref.watch(authNotifierProvider);

    // React to authentication state changes
    if (_previousAuthState != null) {
      if (authState.isAuthenticated && !_previousAuthState!.isAuthenticated) {
        // Login succeeded - fetch subscription info and start auto refresh
        Future.microtask(() => unawaited(fetchSubscription()));
      } else if (!authState.isAuthenticated &&
          _previousAuthState!.isAuthenticated) {
        // Logged out - clear subscription info and stop auto refresh
        state = const SubscriptionState.initial();
        _hasInitiallyLoaded = false;
        _networkFailureCount = 0;
        _stopAutoRefresh();
        _stopNetworkRecoveryProbe();
      }
    } else if (authState.isAuthenticated && !_hasInitiallyLoaded) {
      // First build and already authenticated - fetch subscription
      // 使用 _hasInitiallyLoaded 标记避免重复加载（预热阶段可能已加载）
      Future.microtask(() => unawaited(fetchSubscription()));
    }

    // Store current auth state for next comparison
    _previousAuthState = authState;

    // Cleanup on dispose
    ref.onDispose(() {
      _stopAutoRefresh();
      _stopNetworkRecoveryProbe();
    });

    return const SubscriptionState.initial();
  }

  /// 启动自动刷新定时器
  void _startAutoRefresh() {
    _scheduleNextRefresh(_refreshInterval);
  }

  /// 停止自动刷新定时器
  void _stopAutoRefresh() {
    if (_refreshTimer != null) {
      AppLogger.d('Stopping auto refresh timer', 'Subscription');
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _scheduleNextRefresh(Duration delay) {
    _refreshTimer?.cancel();
    AppLogger.d('Scheduling next subscription refresh in ${delay.inSeconds}s', 'Subscription');
    _refreshTimer = Timer(delay, () {
      unawaited(_runRefreshCycle());
    });
  }

  Duration _computeBackoffDuration() {
    final exponent = _networkFailureCount.clamp(0, 8);
    final nextSeconds = _refreshInterval.inSeconds * (1 << exponent);
    final cappedSeconds = nextSeconds > _maxBackoffInterval.inSeconds
        ? _maxBackoffInterval.inSeconds
        : nextSeconds;
    return Duration(seconds: cappedSeconds);
  }

  Future<void> _runRefreshCycle() async {
    if (!state.isLoaded) {
      await fetchSubscription();
      if (state.isLoaded) {
        _networkFailureCount = 0;
        _stopNetworkRecoveryProbe();
        _scheduleNextRefresh(_refreshInterval);
      }
      return;
    }

    final success = await refreshBalance();
    if (success) {
      _networkFailureCount = 0;
      _stopNetworkRecoveryProbe();
      _scheduleNextRefresh(_refreshInterval);
      return;
    }

    _networkFailureCount += 1;
    final backoff = _computeBackoffDuration();
    AppLogger.w(
      'Subscription refresh failed, applying exponential backoff: ${backoff.inSeconds}s (failures=$_networkFailureCount)',
      'Subscription',
    );
    _scheduleNextRefresh(backoff);
    _startNetworkRecoveryProbe();
  }

  void _startNetworkRecoveryProbe() {
    if (_networkRecoveryProbeTimer != null) {
      return;
    }

    AppLogger.d('Starting network recovery probe', 'Subscription');
    _networkRecoveryProbeTimer = Timer.periodic(_networkProbeInterval, (_) async {
      if (_isNetworkRecoveryProbing) {
        return;
      }

      _isNetworkRecoveryProbing = true;
      try {
        final reachable = await _isNovelApiReachable();
        if (!reachable) {
          return;
        }

        AppLogger.i('Network recovered, triggering immediate subscription refresh', 'Subscription');
        _networkFailureCount = 0;
        _stopNetworkRecoveryProbe();
        _scheduleNextRefresh(Duration.zero);
      } finally {
        _isNetworkRecoveryProbing = false;
      }
    });
  }

  void _stopNetworkRecoveryProbe() {
    if (_networkRecoveryProbeTimer != null) {
      AppLogger.d('Stopping network recovery probe', 'Subscription');
      _networkRecoveryProbeTimer?.cancel();
      _networkRecoveryProbeTimer = null;
    }
  }

  Future<bool> _isNovelApiReachable() async {
    try {
      final result = await InternetAddress.lookup('api.novelai.net')
          .timeout(_networkProbeTimeout);
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 获取订阅信息
  Future<void> fetchSubscription() async {
    if (_inflightFetch != null) {
      return _inflightFetch;
    }

    final fetchFuture = _doFetchSubscription();
    _inflightFetch = fetchFuture;
    try {
      await fetchFuture;
    } finally {
      _inflightFetch = null;
    }
  }

  Future<void> _doFetchSubscription() async {
    // 避免重复加载
    if (state.isLoading) return;

    // 如果已经加载过且不是错误状态，跳过（使用缓存）
    if (_hasInitiallyLoaded && !state.isError) {
      AppLogger.i('Subscription already loaded, skipping', 'Subscription');
      return;
    }

    // 首次拉取保持 initial，避免 UI 进入阻塞式 loading 体验
    if (_hasInitiallyLoaded) {
      state = const SubscriptionState.loading();
    }

    try {
      final apiService = ref.read(naiUserInfoApiServiceProvider);
      final data = await apiService.getUserSubscription(
        receiveTimeout: _initialFetchTimeout,
      );
      final subscription = UserSubscription.fromJson(data);
      state = SubscriptionState.loaded(subscription);
      _hasInitiallyLoaded = true;
      _startAutoRefresh();

      AppLogger.i(
        'Subscription loaded: ${subscription.tierName}, '
            'Anlas: ${subscription.anlasBalance}',
        'Subscription',
      );
    } catch (e) {
      AppLogger.e('Failed to fetch subscription: $e', 'Subscription');

      // 首次加载失败时不进入 error 态，避免 UI 因网络抖动出现卡顿感
      if (_hasInitiallyLoaded) {
        state = SubscriptionState.error(e.toString());
      } else {
        state = const SubscriptionState.initial();
      }

      // 检查是否是网络连接错误，如果是则不标记为已加载，允许后续重试
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('timeout') ||
          errorStr.contains('connection') ||
          errorStr.contains('network') ||
          errorStr.contains('socket') ||
          errorStr.contains('failed host lookup');

      if (!isNetworkError) {
        // 非网络错误（如认证失败），标记为已尝试加载
        _hasInitiallyLoaded = true;
      } else {
        // 网络错误，不标记为已加载，允许在网络恢复后重试
        AppLogger.w('Network error detected, allowing retry', 'Subscription');
        _networkFailureCount += 1;
        _scheduleNextRefresh(_computeBackoffDuration());
        _startNetworkRecoveryProbe();
      }
    }
  }

  /// 重置加载状态（用于强制刷新）
  void resetLoadState() {
    _hasInitiallyLoaded = false;
  }

  /// 刷新余额（生成后调用）
  Future<bool> refreshBalance() async {
    if (_isRefreshingBalance) {
      return false;
    }

    _isRefreshingBalance = true;

    // 保持当前状态，静默刷新
    try {
      final apiService = ref.read(naiUserInfoApiServiceProvider);
      final data = await apiService.getUserSubscription(
        receiveTimeout: _initialFetchTimeout,
      );
      final subscription = UserSubscription.fromJson(data);
      state = SubscriptionState.loaded(subscription);
      return true;
    } catch (e) {
      AppLogger.w('Failed to refresh balance: $e', 'Subscription');
      // 刷新失败不更新状态，保持上次数据
      return false;
    } finally {
      _isRefreshingBalance = false;
    }
  }
}

/// 便捷的余额 Provider
@riverpod
int? anlasBalance(Ref ref) {
  final subscriptionState = ref.watch(subscriptionNotifierProvider);
  return subscriptionState.balance;
}

/// 余额变化监听器 - 自动记录点数消耗
/// 监听余额减少，自动记录到统计数据
@Riverpod(keepAlive: true)
class AnlasBalanceWatcher extends _$AnlasBalanceWatcher {
  int? _lastBalance;

  @override
  void build() {
    final currentBalance = ref.watch(anlasBalanceProvider);
    
    // 检测余额减少
    if (_lastBalance != null && currentBalance != null) {
      final cost = _lastBalance! - currentBalance;
      if (cost > 0) {
        // 延迟一点记录，避免刷新时的瞬时状态
        Future.microtask(() => _recordCost(cost));
      }
    }
    
    _lastBalance = currentBalance;
  }

  Future<void> _recordCost(int cost) async {
    try {
      final anlasService = await ref.read(anlasStatisticsServiceProvider.future);
      await anlasService.recordCost(cost);
      AppLogger.i('Auto-recorded Anlas cost: $cost', 'AnlasBalanceWatcher');
    } catch (e) {
      AppLogger.e('Failed to auto-record Anlas cost: $e', 'AnlasBalanceWatcher');
    }
  }
}

/// 便捷的 Opus 状态 Provider
@riverpod
bool isOpusSubscription(Ref ref) {
  final subscriptionState = ref.watch(subscriptionNotifierProvider);
  return subscriptionState.isOpus;
}
