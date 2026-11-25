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

// 切换账号或重新登录校验期间仍算原会话：成功会换成新账号，失败恢复原会话时订阅侧无需变化
_AuthSession _authSessionOf(AuthState auth) {
  final signedIn = auth.isAuthenticated || auth.isRevalidatingSession;
  return (
    authenticated: signedIn,
    accountId: signedIn ? auth.accountId : null,
    subscriptionUnsupported: signedIn && auth.subscriptionUnsupported,
  );
}

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
  bool _refreshDeferred = false;
  bool _refreshCycleDeferred = false;
  SubscriptionRefreshPriority _deferredRefreshPriority =
      SubscriptionRefreshPriority.background;
  late final _billingFreshness = SubscriptionBillingFreshness(
    _resumeDeferredRefresh,
  );
  Future<bool>? _billingRefresh;

  /// 自动刷新间隔
  static const Duration _refreshInterval = Duration(seconds: 30);
  static const Duration _initialFetchTimeout = Duration(seconds: 6);
  static const Duration _maxBackoffInterval = Duration(minutes: 2);
  static const Duration postBillingRefreshDelay = Duration(milliseconds: 500);

  // 放行判断最多等这么久：进行中的计费请求迟迟不结束或刷新卡住，都要尽快给出不免费的结论
  static const Duration billingRefreshTimeout = Duration(seconds: 3);
  // 1% 约够生成 17 张 1MP 图，5% 可覆盖一次大批量请求和短时间内尚未刷新的消耗。
  static const double _trustedQuotaPercent = 5;

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
      _refreshDeferred = false;
      _refreshCycleDeferred = false;
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

    ref.listen(
      authNotifierProvider.select(
        (auth) => (
          revalidating: auth.isRevalidatingSession,
          session: _authSessionOf(auth),
        ),
      ),
      (previous, next) {
        if (previous?.revalidating != true || next.revalidating) return;
        // 换了账号或登出时由重建统一收尾，这里只处理恢复原会话
        if (next.session != _session) return;
        _resumeDeferredRefresh();
      },
    );

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
    _billingFreshness.recordVerified(
      billingToken,
      ref.read(subscriptionBillingClockProvider)(),
    );
    _updateState(SubscriptionState.loaded(subscription));
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
    if (_scheduledRefreshDeferred) {
      _deferRefresh(SubscriptionRefreshPriority.background);
      _refreshCycleDeferred = true;
      _refreshTimer = null;
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
    if (_lastBalanceRefreshWasPreempted) {
      _refreshCycleDeferred = _refreshDeferred;
      return;
    }

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
    // 租约随传输结束释放，延后的刷新要等最后一次扣点落库。
    _seenEndedActivityCount =
        CriticalNetworkActivityCoordinator.instance.endedActivityCount;
    _billingFreshness.billingRequestEnded(postBillingRefreshDelay);
  }

  void _resumeDeferredRefresh() {
    if (!_refreshDeferred || !_isAppVisible || _scheduledRefreshDeferred) {
      return;
    }
    _refreshDeferred = false;
    final priority = _deferredRefreshPriority;
    _deferredRefreshPriority = SubscriptionRefreshPriority.background;
    final cycleDeferred = _refreshCycleDeferred;
    _refreshCycleDeferred = false;
    AppLogger.d(
      'Resuming one deferred subscription refresh: priority=${priority.name}',
      'Subscription',
    );
    if (priority == SubscriptionRefreshPriority.background) {
      _scheduleNextRefresh(Duration.zero);
      return;
    }
    unawaited(refreshBalance(priority: priority));
    // 被推迟的定时刷新已并入这次刷新，但计时器在推迟时就停了，要从这里重新起表
    if (cycleDeferred) _scheduleNextRefresh(_refreshInterval);
  }

  // 会话校验期间存储里的令牌可能已是新账号的，请求结果说不清归属，和关键请求一样推迟
  bool get _requestsDeferred =>
      CriticalNetworkActivityCoordinator.instance.isActive ||
      ref.read(authNotifierProvider).isRevalidatingSession;

  bool get _scheduledRefreshDeferred =>
      _billingFreshness.isSettling || _requestsDeferred;

  bool get _hasSubscriptionSession {
    final session = _authSessionOf(ref.read(authNotifierProvider));
    return session.authenticated && !session.subscriptionUnsupported;
  }

  void _deferRefresh(SubscriptionRefreshPriority priority) {
    _refreshDeferred = true;
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
    if (_requestsDeferred) {
      _deferRefresh(SubscriptionRefreshPriority.background);
      _refreshCycleDeferred = true;
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
    if (!_hasSubscriptionSession) return;

    _cancelPostBillingRefresh();
    // 传输结束已启动落库窗口，余额刷新等它结束时一并发出。
    if (_billingFreshness.isSettling) {
      _deferRefresh(SubscriptionRefreshPriority.postBilling);
      return;
    }
    _postBillingRefreshTimer = Timer(delay, () {
      _postBillingRefreshTimer = null;
      if (_scheduledRefreshDeferred) {
        _deferRefresh(SubscriptionRefreshPriority.postBilling);
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
    if (!_hasSubscriptionSession) return Future.value(false);
    if (_requestsDeferred) {
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
      _balanceRefreshQueued = false;
      _activeBalanceRefreshPriority = currentPriority;
      latestRefreshSucceeded = await _refreshBalanceOnce();
      if (refreshGeneration != _balanceRefreshGeneration) return false;
      currentPriority = _queuedBalanceRefreshPriority;
      _queuedBalanceRefreshPriority = SubscriptionRefreshPriority.background;
      if (_balanceRefreshQueued && _scheduledRefreshDeferred) {
        _deferRefresh(currentPriority);
        _balanceRefreshQueued = false;
        _lastBalanceRefreshWasPreempted = true;
        return false;
      }
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

  /// 界面实时估价使用当前已知的订阅。
  SubscriptionBillingView get billingView =>
      SubscriptionBillingView.of(state.subscription);

  /// 数据不新鲜时只可能看错配额是否用尽，Opus 身份由到期时间本地判定。
  ({SubscriptionBillingView known, SubscriptionBillingView? worstCase})
  get generationPageBilling {
    final known = billingView;
    final usage = state.subscription?.usage;
    final trusted =
        usage == null ||
        usage.availablePercent >= _trustedQuotaPercent ||
        _isFreshForBilling;
    return (
      known: known,
      worstCase: trusted
          ? null
          : SubscriptionBillingView(
              isOpus: known.isOpus,
              opusQuotaExhausted: true,
            ),
    );
  }

  /// 需要核实时等待扣点落库，并发调用共用一次刷新。失败只影响本次判断。
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

  /// 需要先核实的计费操作使用本次核实结果。
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
    final refreshed = await _awaitFreshSubscription(sessionGeneration).timeout(
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
          ? 'A billed request has not settled. This estimate excludes the '
                'Opus allowance.'
          : 'Subscription verification failed. This estimate excludes the '
                'Opus allowance.',
      'Subscription',
    );
    return false;
  }

  Future<bool> _awaitFreshSubscription(int sessionGeneration) async {
    await _awaitBillingSettled();
    final inflight = _inflightBalanceRefresh;
    if (inflight != null) {
      await inflight;
    }
    if (sessionGeneration != _balanceRefreshGeneration) return false;
    if (_isFreshForBilling) return true;
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

  // 请求发出前已是这个会话的令牌，校验期间回来的结果仍属于原会话
  bool _isCurrentAuthSession(AuthState expected) {
    final current = ref.read(authNotifierProvider);
    final session = _authSessionOf(current);
    if (!session.authenticated) return false;
    if (identical(current, expected)) return true;
    return expected.accountId != null && session == _authSessionOf(expected);
  }
}

/// 当前已知订阅的计费视图。
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
  String? _lastAccountId;
  int? _lastBalance;

  @override
  void build() {
    final accountId = ref.watch(
      authNotifierProvider.select((auth) => _authSessionOf(auth).accountId),
    );
    final currentBalance = ref.watch(anlasBalanceProvider);

    // 换账号时余额变化不是消耗，比较基准跟着换
    if (accountId == _lastAccountId &&
        _lastBalance != null &&
        currentBalance != null) {
      final cost = _lastBalance! - currentBalance;
      if (cost > 0) {
        // 延迟一点记录，避免刷新时的瞬时状态
        Future.microtask(() => _recordCost(cost));
      }
    }

    _lastAccountId = accountId;
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

/// 当前已知订阅是否具有 Opus 权益。
@riverpod
bool isOpusSubscription(Ref ref) =>
    ref.watch(subscriptionBillingViewProvider).isOpus;
