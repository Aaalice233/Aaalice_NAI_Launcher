import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/critical_network_activity.dart';
import '../../core/services/interactive_work_gate.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_user_info_api_service.dart';
import '../../data/models/user/user_subscription.dart';
import '../../data/services/anlas_statistics_service.dart';
import '../../data/services/auth_provider.dart';
import 'subscription_billing.dart';
import 'subscription_billing_freshness.dart';

part 'subscription_provider.g.dart';

enum SubscriptionRefreshPriority { background, postBilling, userInitiated }

final subscriptionBillingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

typedef _AuthSession = ({
  bool authenticated,
  String? accountId,
  bool subscriptionUnsupported,
});

_AuthSession _authSessionOf(AuthState auth) => (
  authenticated: auth.isAuthenticated,
  accountId: auth.isAuthenticated ? auth.accountId : null,
  subscriptionUnsupported: auth.isAuthenticated && auth.subscriptionUnsupported,
);

/// 订阅状态 Notifier
///
/// 管理用户订阅信息和 Anlas 余额
@riverpod
class SubscriptionNotifier extends _$SubscriptionNotifier {
  _AuthSession? _session;
  SubscriptionState? _lastKnownState;
  bool _hasInitiallyLoaded = false;
  Timer? _refreshTimer;
  Future<void>? _inflightFetch;
  CancelToken? _inflightFetchCancelToken;
  Future<bool>? _inflightBalanceRefresh;
  CancelToken? _inflightBalanceRefreshCancelToken;
  bool _balanceRefreshQueued = false;
  SubscriptionRefreshPriority _activeBalanceRefreshPriority =
      SubscriptionRefreshPriority.background;
  SubscriptionRefreshPriority _queuedBalanceRefreshPriority =
      SubscriptionRefreshPriority.background;
  int _balanceRefreshGeneration = 0;
  bool _lastBalanceRefreshWasPreempted = false;
  Timer? _postBillingRefreshTimer;
  int _networkFailureCount = 0;
  bool _isAppVisible = true;
  bool _criticalActivityListenerAttached = false;
  int? _seenEndedActivityCount;
  bool _refreshDeferredForCriticalActivity = false;
  SubscriptionRefreshPriority _deferredRefreshPriority =
      SubscriptionRefreshPriority.background;
  final SubscriptionBillingFreshness _billingFreshness =
      SubscriptionBillingFreshness();
  Future<bool>? _billingRefresh;

  /// 自动刷新间隔
  static const Duration _refreshInterval = Duration(seconds: 30);
  static const Duration _initialFetchTimeout = Duration(seconds: 6);
  static const Duration _maxBackoffInterval = Duration(minutes: 2);
  static const Duration postBillingRefreshDelay = Duration(milliseconds: 500);

  // 放行判断最多等这么久：进行中的计费请求迟迟不结束或刷新卡住，都要尽快给出不免费的结论
  static const Duration billingRefreshTimeout = Duration(seconds: 10);

  @override
  SubscriptionState build() {
    ref.keepAlive();
    if (!_criticalActivityListenerAttached) {
      _attachCriticalActivityListener();
    }

    // 每次重建都会经 onDispose 停掉计时器、待办与在途请求，只能由会话本身的变化触发
    final session = ref.watch(authNotifierProvider.select(_authSessionOf));
    final previousSession = _session;
    final loggedIn =
        session.authenticated &&
        previousSession != null &&
        !previousSession.authenticated;
    final switchedAccount =
        session.authenticated &&
        previousSession?.authenticated == true &&
        session.accountId != previousSession?.accountId;
    final loggedOut =
        !session.authenticated && previousSession?.authenticated == true;

    if (switchedAccount || loggedOut) {
      _inflightFetchCancelToken?.cancel('Authentication session changed');
      _inflightBalanceRefreshCancelToken?.cancel(
        'Authentication session changed',
      );
      _inflightFetch = null;
      _inflightFetchCancelToken = null;
      _inflightBalanceRefresh = null;
      _inflightBalanceRefreshCancelToken = null;
      _balanceRefreshQueued = false;
      _balanceRefreshGeneration += 1;
      _lastKnownState = null;
      _hasInitiallyLoaded = false;
      _networkFailureCount = 0;
      _refreshDeferredForCriticalActivity = false;
      _deferredRefreshPriority = SubscriptionRefreshPriority.background;
      _billingFreshness.reset();
      _billingRefresh = null;
      _stopAutoRefresh();
      _cancelPostBillingRefresh();
    }

    // 第三方站点不提供 /user/subscription：整条订阅链路静默，不拉取不轮询。
    final subscriptionUnsupported = session.subscriptionUnsupported;

    final hydratedState = subscriptionUnsupported
        ? null
        : _hydrateFromAuthState(ref.read(authNotifierProvider));

    // React to authentication state changes
    if (subscriptionUnsupported) {
      _stopAutoRefresh();
      _cancelPostBillingRefresh();
    } else if (loggedIn || switchedAccount) {
      // Login succeeded - use the subscription info already fetched during
      // token validation, then refresh in the background if needed.
      if (hydratedState == null) {
        Future.microtask(() => unawaited(fetchSubscription()));
      }
    } else if (previousSession == null &&
        session.authenticated &&
        !_hasInitiallyLoaded) {
      // First build and already authenticated - fetch subscription
      // 使用 _hasInitiallyLoaded 标记避免重复加载（预热阶段可能已加载）
      if (hydratedState == null) {
        Future.microtask(() => unawaited(fetchSubscription()));
      }
    }

    _session = session;

    // Cleanup on dispose
    ref.onDispose(() {
      _stopAutoRefresh();
      _cancelPostBillingRefresh();
      _billingFreshness.suspend();
      _inflightFetchCancelToken?.cancel('Subscription notifier disposed');
      _inflightBalanceRefreshCancelToken?.cancel(
        'Subscription notifier disposed',
      );
      CriticalNetworkActivityCoordinator.instance.removeListener(
        _handleCriticalNetworkActivityChanged,
      );
      _criticalActivityListenerAttached = false;
    });

    if (subscriptionUnsupported) {
      const unsupportedState = SubscriptionState.unsupported();
      _lastKnownState = unsupportedState;
      return unsupportedState;
    }

    if (hydratedState != null) {
      _lastKnownState = hydratedState;
      return hydratedState;
    }
    return _lastKnownState ?? const SubscriptionState.initial();
  }

  // 重建时监听会先断开、稍后才重新挂上，其间结束的计费请求同样要开启落库窗口
  void _attachCriticalActivityListener() {
    final coordinator = CriticalNetworkActivityCoordinator.instance;
    _criticalActivityListenerAttached = true;
    coordinator.addListener(_handleCriticalNetworkActivityChanged);
    _billingFreshness.resume(postBillingRefreshDelay);
    final seen = _seenEndedActivityCount;
    _seenEndedActivityCount = coordinator.endedActivityCount;
    if (seen != null && seen != coordinator.endedActivityCount) {
      _billingFreshness.billingRequestEnded(postBillingRefreshDelay);
    }
  }

  void _updateState(SubscriptionState nextState) {
    _lastKnownState = nextState;
    state = nextState;
  }

  void _applyFetchedSubscription(
    UserSubscription subscription, {
    required int? billingToken,
  }) {
    final verificationChanged = _billingFreshness.recordVerified(
      billingToken,
      ref.read(subscriptionBillingClockProvider)(),
    );
    final nextState = SubscriptionState.loaded(subscription);
    if (state != nextState) {
      _updateState(nextState);
    } else if (verificationChanged) {
      // 余额与配额相同也可能恢复免费资格，Riverpod 不会派发相等的状态。
      ref.notifyListeners();
    }
  }

  SubscriptionState? _hydrateFromAuthState(AuthState authState) {
    if (!authState.isAuthenticated ||
        authState.subscriptionInfo == null ||
        _hasInitiallyLoaded) {
      return null;
    }

    try {
      final subscription = UserSubscription.fromJson(
        authState.subscriptionInfo!,
      );
      _hasInitiallyLoaded = true;
      _networkFailureCount = 0;
      // Token validation already returned this exact subscription payload.
      // Start the regular cadence without issuing a duplicate request during
      // the first interactive seconds of the main application.
      _startAutoRefresh();
      return SubscriptionState.loaded(subscription);
    } catch (e) {
      AppLogger.w(
        'Failed to hydrate subscription from auth state: $e',
        'Subscription',
      );
      return null;
    }
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
    if (!_isAppVisible) {
      _refreshTimer = null;
      return;
    }
    AppLogger.d(
      'Scheduling next subscription refresh in ${delay.inSeconds}s',
      'Subscription',
    );
    _refreshTimer = Timer(delay, () {
      unawaited(_runScheduledRefresh());
    });
  }

  Future<void> _runScheduledRefresh() async {
    try {
      await InteractiveWorkGate.instance.runWhenIdle(
        priority: InteractiveWorkPriority.maintenance,
        action: () async {
          if (!_isAppVisible) return;
          await _runRefreshCycle();
        },
      );
    } catch (error, stackTrace) {
      AppLogger.w(
        'Scheduled subscription refresh failed: $error',
        'Subscription',
      );
      AppLogger.d('$stackTrace', 'Subscription');
    }
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
    if (CriticalNetworkActivityCoordinator.instance.isActive) {
      _deferRefresh(SubscriptionRefreshPriority.background);
      _refreshTimer = null;
      AppLogger.d(
        'Subscription background refresh deferred for critical network activity',
        'Subscription',
      );
      return;
    }
    if (!state.isLoaded) {
      await fetchSubscription();
      if (state.isLoaded) {
        _networkFailureCount = 0;
        _scheduleNextRefresh(_refreshInterval);
      }
      return;
    }

    final success = await refreshBalance();
    if (success) {
      _networkFailureCount = 0;
      _scheduleNextRefresh(_refreshInterval);
      return;
    }
    if (_lastBalanceRefreshWasPreempted) return;

    _networkFailureCount += 1;
    final backoff = _computeBackoffDuration();
    AppLogger.w(
      'Subscription refresh failed, applying exponential backoff: ${backoff.inSeconds}s (failures=$_networkFailureCount)',
      'Subscription',
    );
    _scheduleNextRefresh(backoff);
  }

  /// Stops periodic network work while the window is hidden and performs one
  /// fresh synchronization when it is shown again; losing focus changes nothing.
  void setAppVisible(bool isVisible) {
    if (_isAppVisible == isVisible) return;
    _isAppVisible = isVisible;

    if (!isVisible) {
      _stopAutoRefresh();
      if (_activeBalanceRefreshPriority ==
              SubscriptionRefreshPriority.background &&
          _inflightBalanceRefreshCancelToken?.isCancelled == false) {
        _inflightBalanceRefreshCancelToken?.cancel(
          'Subscription background refresh paused with application lifecycle',
        );
      }
      return;
    }

    final session = _session;
    if (session != null &&
        session.authenticated &&
        !session.subscriptionUnsupported) {
      _scheduleNextRefresh(Duration.zero);
    }
  }

  void _handleCriticalNetworkActivityChanged() {
    if (CriticalNetworkActivityCoordinator.instance.isActive) {
      if (_inflightFetchCancelToken?.isCancelled == false) {
        _deferRefresh(SubscriptionRefreshPriority.background);
        _inflightFetchCancelToken?.cancel(
          'Subscription fetch preempted by critical network activity',
        );
      }
      if (_inflightBalanceRefreshCancelToken?.isCancelled == false) {
        _deferRefresh(_activeBalanceRefreshPriority);
        _inflightBalanceRefreshCancelToken?.cancel(
          'Balance refresh preempted by critical network activity',
        );
      }
      return;
    }
    // 租约随传输结束释放，扣点要再过一个落库窗口才可信，计费数据从这一刻起作废
    _seenEndedActivityCount =
        CriticalNetworkActivityCoordinator.instance.endedActivityCount;
    _billingFreshness.billingRequestEnded(postBillingRefreshDelay);
    if (!_refreshDeferredForCriticalActivity || !_isAppVisible) {
      return;
    }
    _refreshDeferredForCriticalActivity = false;
    final priority = _deferredRefreshPriority;
    _deferredRefreshPriority = SubscriptionRefreshPriority.background;
    AppLogger.d(
      'Critical network activity ended; resuming one deferred subscription refresh',
      'Subscription',
    );
    if (priority == SubscriptionRefreshPriority.background) {
      _scheduleNextRefresh(Duration.zero);
    } else {
      unawaited(refreshBalance(priority: priority));
    }
  }

  void _deferRefresh(SubscriptionRefreshPriority priority) {
    _refreshDeferredForCriticalActivity = true;
    if (priority.index > _deferredRefreshPriority.index) {
      _deferredRefreshPriority = priority;
    }
    AppLogger.d(
      'Subscription refresh deferred: priority=${priority.name}',
      'Subscription',
    );
  }

  /// 获取订阅信息
  Future<void> fetchSubscription() async {
    if (ref.read(authNotifierProvider).subscriptionUnsupported) {
      return;
    }
    if (CriticalNetworkActivityCoordinator.instance.isActive) {
      _deferRefresh(SubscriptionRefreshPriority.background);
      return;
    }
    if (_inflightFetch != null) {
      return _inflightFetch;
    }

    final cancelToken = CancelToken();
    _inflightFetchCancelToken = cancelToken;
    final fetchFuture = _doFetchSubscription(cancelToken);
    _inflightFetch = fetchFuture;
    try {
      await fetchFuture;
    } finally {
      if (identical(_inflightFetch, fetchFuture)) {
        _inflightFetch = null;
        _inflightFetchCancelToken = null;
      }
    }
  }

  Future<void> _doFetchSubscription(CancelToken cancelToken) async {
    final authSession = ref.read(authNotifierProvider);
    if (!authSession.isAuthenticated) return;

    // 避免重复加载
    if (state.isLoading) return;

    // 如果已经加载过且不是错误状态，跳过（使用缓存）
    if (_hasInitiallyLoaded && !state.isError) {
      AppLogger.i('Subscription already loaded, skipping', 'Subscription');
      return;
    }

    // 首次拉取保持 initial，避免 UI 进入阻塞式 loading 体验
    if (_hasInitiallyLoaded) {
      _updateState(const SubscriptionState.loading());
    }

    try {
      final billingToken = _billingFreshness.requestToken();
      final apiService = ref.read(naiUserInfoApiServiceProvider);
      final data = await apiService.getUserSubscription(
        receiveTimeout: _initialFetchTimeout,
        cancelToken: cancelToken,
      );
      if (!_isCurrentAuthSession(authSession)) return;

      final subscription = UserSubscription.fromJson(data);
      _applyFetchedSubscription(subscription, billingToken: billingToken);
      _hasInitiallyLoaded = true;
      _startAutoRefresh();

      AppLogger.i(
        'Subscription loaded: ${subscription.tierName}, '
            'Anlas: ${subscription.anlasBalance}',
        'Subscription',
      );
    } catch (e) {
      if (!_isCurrentAuthSession(authSession)) return;
      if (e is DioException && CancelToken.isCancel(e)) {
        AppLogger.d(
          'Subscription fetch cancelled for critical network activity',
          'Subscription',
        );
        return;
      }
      AppLogger.e('Failed to fetch subscription: $e', 'Subscription');

      // 首次加载失败时不进入 error 态，避免 UI 因网络抖动出现卡顿感
      if (_hasInitiallyLoaded) {
        _updateState(SubscriptionState.error(e.toString()));
      } else {
        _updateState(const SubscriptionState.initial());
      }

      // 检查是否是网络连接错误，如果是则不标记为已加载，允许后续重试
      final errorStr = e.toString().toLowerCase();
      final isNetworkError =
          errorStr.contains('timeout') ||
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
      }
    }
  }

  /// 重置加载状态（用于强制刷新）
  void resetLoadState() {
    _hasInitiallyLoaded = false;
  }

  /// 在可能产生 Anlas 扣费的请求结束后刷新余额。
  ///
  /// 延迟窗口与 NovelAI 网页端保持一致，并合并短时间内连续完成的编码、生成
  /// 等请求，避免在服务端余额尚未落库时读到旧值。
  void schedulePostBillingRefresh({Duration delay = postBillingRefreshDelay}) {
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated || authState.subscriptionUnsupported) {
      return;
    }

    _postBillingRefreshTimer?.cancel();
    _postBillingRefreshTimer = Timer(delay, () {
      _postBillingRefreshTimer = null;
      if (CriticalNetworkActivityCoordinator.instance.isActive) {
        _deferRefresh(SubscriptionRefreshPriority.postBilling);
        AppLogger.d(
          'Post-billing balance refresh deferred for critical network activity',
          'Subscription',
        );
        return;
      }
      unawaited(
        refreshBalance(priority: SubscriptionRefreshPriority.postBilling),
      );
    });
  }

  void _cancelPostBillingRefresh() {
    _postBillingRefreshTimer?.cancel();
    _postBillingRefreshTimer = null;
  }

  /// 立即刷新余额。
  ///
  /// 刷新进行中收到的新请求不会被丢弃：当前请求结束后再拉取一次，确保生成
  /// 完成时恰逢定时刷新也能拿到扣费后的余额。
  Future<bool> refreshBalance({
    SubscriptionRefreshPriority priority =
        SubscriptionRefreshPriority.background,
  }) {
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated || authState.subscriptionUnsupported) {
      return Future.value(false);
    }
    if (CriticalNetworkActivityCoordinator.instance.isActive) {
      _deferRefresh(priority);
      return Future.value(false);
    }

    final inflightRefresh = _inflightBalanceRefresh;
    if (inflightRefresh != null) {
      _balanceRefreshQueued = true;
      if (priority.index > _queuedBalanceRefreshPriority.index) {
        _queuedBalanceRefreshPriority = priority;
      }
      return inflightRefresh;
    }

    _activeBalanceRefreshPriority = priority;
    _queuedBalanceRefreshPriority = SubscriptionRefreshPriority.background;
    final refreshGeneration = _balanceRefreshGeneration;
    late final Future<bool> trackedRefresh;
    trackedRefresh = _drainBalanceRefreshQueue(priority, refreshGeneration)
        .whenComplete(() {
          if (identical(_inflightBalanceRefresh, trackedRefresh)) {
            _inflightBalanceRefresh = null;
            _inflightBalanceRefreshCancelToken = null;
          }
        });
    _inflightBalanceRefresh = trackedRefresh;
    return trackedRefresh;
  }

  Future<bool> _drainBalanceRefreshQueue(
    SubscriptionRefreshPriority initialPriority,
    int refreshGeneration,
  ) async {
    var latestRefreshSucceeded = false;
    var currentPriority = initialPriority;
    do {
      if (CriticalNetworkActivityCoordinator.instance.isActive) {
        _deferRefresh(currentPriority);
        _balanceRefreshQueued = false;
        _lastBalanceRefreshWasPreempted = true;
        return false;
      }
      _balanceRefreshQueued = false;
      _activeBalanceRefreshPriority = currentPriority;
      latestRefreshSucceeded = await _refreshBalanceOnce();
      if (refreshGeneration != _balanceRefreshGeneration) return false;
      currentPriority = _queuedBalanceRefreshPriority;
      _queuedBalanceRefreshPriority = SubscriptionRefreshPriority.background;
    } while (_balanceRefreshQueued);
    return latestRefreshSucceeded;
  }

  Future<bool> _refreshBalanceOnce() async {
    // 保持当前状态，静默刷新
    final authSession = ref.read(authNotifierProvider);
    if (!authSession.isAuthenticated) return false;
    final cancelToken = CancelToken();
    _inflightBalanceRefreshCancelToken = cancelToken;
    _lastBalanceRefreshWasPreempted = false;

    try {
      final billingToken = _billingFreshness.requestToken();
      final apiService = ref.read(naiUserInfoApiServiceProvider);
      final data = await apiService.getUserSubscription(
        receiveTimeout: _initialFetchTimeout,
        cancelToken: cancelToken,
      );
      if (!_isCurrentAuthSession(authSession)) return false;

      final subscription = UserSubscription.fromJson(data);
      _applyFetchedSubscription(subscription, billingToken: billingToken);
      _networkFailureCount = 0;
      return true;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        _lastBalanceRefreshWasPreempted = true;
        AppLogger.d(
          'Balance refresh cancelled for critical network activity',
          'Subscription',
        );
        return false;
      }
      AppLogger.w('Failed to refresh balance: $e', 'Subscription');
      // 刷新失败不更新状态，保持上次数据
      return false;
    } finally {
      if (identical(_inflightBalanceRefreshCancelToken, cancelToken)) {
        _inflightBalanceRefreshCancelToken = null;
      }
    }
  }

  /// 估价与放行统一读这份视图；过期数据刷新失败后不承认 Opus 免费额度。
  SubscriptionBillingView get billingView => SubscriptionBillingView.resolve(
    state.subscription,
    unverified: _billingFreshness.unverified,
  );

  /// 会扣点的放行判断前调用：订阅数据过期、或有计费请求在进行或刚结束时，先等它
  /// 落定再刷新，并发调用共用同一次刷新。
  ///
  /// 等不到或刷新失败返回 false，此后 [billingView] 按不免费计价，直到下一次成功核实。
  Future<bool> ensureFreshForBilling() {
    if (!_needsBillingRefresh) return Future.value(true);
    final pending = _billingRefresh;
    if (pending != null) return pending;
    late final Future<bool> refresh;
    refresh = _refreshForBilling().whenComplete(() {
      if (identical(_billingRefresh, refresh)) _billingRefresh = null;
    });
    _billingRefresh = refresh;
    return refresh;
  }

  // 等待期间切换了账号时，这次判断不改动新会话的核实状态，但自己仍按不免费处理
  Future<SubscriptionBillingView> freshBillingView() async =>
      await ensureFreshForBilling()
      ? billingView
      : SubscriptionBillingView.unverified;

  // 进行中的计费请求可能正在消耗配额池，之前取回的数据说明不了它之后的状态
  bool get _isFreshForBilling =>
      state.isLoaded &&
      !CriticalNetworkActivityCoordinator.instance.isActive &&
      _billingFreshness.isFresh(ref.read(subscriptionBillingClockProvider)());

  // 没有订阅数据时本来就不计任何 Opus 免费额度，不必为放行再请求
  bool get _needsBillingRefresh {
    final session = _session;
    if (session == null ||
        !session.authenticated ||
        session.subscriptionUnsupported ||
        state.subscription == null) {
      return false;
    }
    return !_isFreshForBilling;
  }

  Future<bool> _refreshForBilling() async {
    final sessionGeneration = _balanceRefreshGeneration;
    final refreshed = await _awaitFreshSubscription().timeout(
      billingRefreshTimeout,
      onTimeout: () => false,
    );
    if (refreshed) return true;
    if (sessionGeneration != _balanceRefreshGeneration) return false;
    final stillSettling =
        CriticalNetworkActivityCoordinator.instance.isActive ||
        _billingFreshness.isSettling;
    AppLogger.w(
      stillSettling
          ? 'Subscription could not be verified before billing: a billed '
                'request has not settled yet; Opus allowance is not applied '
                'until the next successful refresh'
          : 'Subscription refresh before billing failed; Opus allowance is not '
                'applied until the next successful refresh',
      'Subscription',
    );
    if (_billingFreshness.markUnverified()) ref.notifyListeners();
    return false;
  }

  Future<bool> _awaitFreshSubscription() async {
    await _awaitBillingSettled();
    final inflight = _inflightBalanceRefresh;
    if (inflight != null) {
      await inflight;
      if (_isFreshForBilling) return true;
    }
    await refreshBalance(priority: SubscriptionRefreshPriority.userInitiated);
    return _isFreshForBilling;
  }

  Future<void> _awaitBillingSettled() async {
    final coordinator = CriticalNetworkActivityCoordinator.instance;
    while (true) {
      if (coordinator.isActive) {
        await coordinator.whenInactive();
      } else if (_billingFreshness.isSettling) {
        await _billingFreshness.whenSettled();
      } else {
        return;
      }
    }
  }

  bool _isCurrentAuthSession(AuthState expected) {
    final current = ref.read(authNotifierProvider);
    if (!current.isAuthenticated) return false;
    if (identical(current, expected)) return true;

    final expectedAccountId = expected.accountId;
    return expectedAccountId != null && current.accountId == expectedAccountId;
  }
}

/// 估价统一读这份视图，内容与 [SubscriptionNotifier.billingView] 一致。
final subscriptionBillingViewProvider =
    Provider.autoDispose<SubscriptionBillingView>((ref) {
      ref.watch(subscriptionNotifierProvider);
      return ref.read(subscriptionNotifierProvider.notifier).billingView;
    });

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
      final anlasService = await ref.read(
        anlasStatisticsServiceProvider.future,
      );
      await anlasService.recordCost(cost);
      AppLogger.i('Auto-recorded Anlas cost: $cost', 'AnlasBalanceWatcher');
    } catch (e) {
      AppLogger.e(
        'Failed to auto-record Anlas cost: $e',
        'AnlasBalanceWatcher',
      );
    }
  }
}

/// 按计费口径的 Opus 状态：过期数据刷新失败后不再算作 Opus。
@riverpod
bool isOpusSubscription(Ref ref) =>
    ref.watch(subscriptionBillingViewProvider).isOpus;
