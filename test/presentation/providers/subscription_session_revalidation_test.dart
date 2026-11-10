import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/core/services/auth_error_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';
import 'package:nai_launcher/data/services/anlas_statistics_service.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

class _MockUserInfoApi extends Mock implements NAIUserInfoApiService {}

// 状态序列照搬 AuthNotifier：重新登录先从当前状态 copyWith 出 loading，失败时恢复原状态并附加错误
class _SessionAuthNotifier extends AuthNotifier {
  AuthState? _beforeRevalidation;

  @override
  AuthState build() => _account('account-a', balance: 100);

  void beginRevalidation() {
    _beforeRevalidation = state;
    state = state.copyWith(status: AuthStatus.loading);
  }

  void finishRevalidationAs(AuthState next) => state = next;

  void restoreAfterFailedRevalidation() {
    state = _beforeRevalidation!.copyWith(
      errorCode: AuthErrorCode.networkError,
    );
  }

  void replaceSession(AuthState next) => state = next;

  void signOut() => state = const AuthState(status: AuthStatus.unauthenticated);
}

// 登录校验没有带回订阅信息，订阅要靠首次拉取
class _UnhydratedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.authenticated, accountId: 'account-a');
}

// 启动时的 loading 不带账号，自动登录成功后才进入已登录
class _StartupAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.loading);

  void completeAutoLogin() => state = _account('account-a', balance: 100);
}

final class _RecordingAnlasStatistics extends AnlasStatisticsService {
  _RecordingAnlasStatistics(this.costs);

  final List<int> costs;

  @override
  Future<AnlasStatisticsService> build() async => this;

  @override
  Future<void> recordCost(int cost, {DateTime? date}) async => costs.add(cost);
}

AuthState _account(String id, {required int balance}) => AuthState(
  status: AuthStatus.authenticated,
  accountId: id,
  subscriptionInfo: _subscriptionJson(balance: balance),
);

Map<String, dynamic> _subscriptionJson({required int balance}) => {
  'tier': 3,
  'active': true,
  'trainingStepsLeft': {
    'fixedTrainingStepsLeft': balance,
    'purchasedTrainingSteps': 0,
  },
};

void main() {
  const refreshInterval = Duration(seconds: 30);
  const gateSettle = Duration(milliseconds: 250);
  const billingDelay = Duration(milliseconds: 10);

  late _MockUserInfoApi api;
  late int requestCount;
  late int nextBalance;
  late List<int> costs;
  late List<int?> balances;
  late ProviderContainer container;
  late _SessionAuthNotifier auth;

  setUp(() {
    api = _MockUserInfoApi();
    requestCount = 0;
    nextBalance = 90;
    costs = [];
    balances = [];
    when(
      () => api.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      requestCount += 1;
      return _subscriptionJson(balance: nextBalance);
    });
  });

  Future<void> start(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_SessionAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(api),
        anlasStatisticsServiceProvider.overrideWith(
          () => _RecordingAnlasStatistics(costs),
        ),
      ],
    );
    container.listen(anlasBalanceWatcherProvider, (_, __) {});
    container.listen<int?>(
      anlasBalanceProvider,
      (_, next) => balances.add(next),
      fireImmediately: true,
    );
    auth =
        container.read(authNotifierProvider.notifier) as _SessionAuthNotifier;
    await tester.pump(Duration.zero);
  }

  // 计时器检查早于 tearDown，容器必须在用例体内释放
  void testSession(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await start(tester);
        await body(tester);
      } finally {
        container.dispose();
      }
    });
  }

  int? balance() => container.read(subscriptionNotifierProvider).balance;

  Future<void> settle(WidgetTester tester) async {
    container.read(anlasBalanceWatcherProvider);
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  }

  Future<void> change(WidgetTester tester, void Function() update) async {
    update();
    await settle(tester);
  }

  Future<void> waitOneRefreshInterval(WidgetTester tester) async {
    await tester.pump(refreshInterval);
    await tester.pump(gateSettle);
    await settle(tester);
  }

  // 登录时带回的快照是 100，之后真实刷新到 90，这 10 点是真实消耗；此后的余额记录从这里开始
  Future<void> refreshToRealBalance(WidgetTester tester) async {
    await waitOneRefreshInterval(tester);
    expect(requestCount, 1);
    expect(balance(), 90);
    expect(costs, [10]);
    balances.clear();
  }

  testSession('switching from A to B keeps A balance during validation and '
      'records no fake cost', (tester) async {
    await refreshToRealBalance(tester);

    await change(tester, auth.beginRevalidation);
    expect(balance(), 90);

    await change(
      tester,
      () => auth.finishRevalidationAs(_account('account-b', balance: 500)),
    );
    expect(balance(), 500);
    expect(balances.where((value) => value == null), isEmpty);
    expect(balances, isNot(contains(100)), reason: 'no stale A snapshot');
    expect(costs, [10]);

    nextBalance = 480;
    await waitOneRefreshInterval(tester);
    expect(requestCount, 2);
    await waitOneRefreshInterval(tester);
    expect(requestCount, 3);
    expect(costs, [10, 20]);
  });

  testSession('a failed validation keeps A refreshing without a stale '
      'snapshot or a double-counted cost', (tester) async {
    await refreshToRealBalance(tester);

    container
        .read(subscriptionNotifierProvider.notifier)
        .schedulePostBillingRefresh(delay: billingDelay);
    await change(tester, auth.beginRevalidation);
    await tester.pump(billingDelay);
    await waitOneRefreshInterval(tester);
    expect(requestCount, 1, reason: 'no request while validating');
    expect(balance(), 90);

    nextBalance = 85;
    await change(tester, auth.restoreAfterFailedRevalidation);
    expect(requestCount, 2, reason: 'the deferred refresh runs once');
    expect(balance(), 85);
    expect(balances, isNot(contains(100)), reason: 'no stale A snapshot');
    expect(balances.where((value) => value == null), isEmpty);
    expect(costs, [10, 5]);

    await waitOneRefreshInterval(tester);
    expect(requestCount, 3, reason: 'the cadence continues without backoff');
  });

  testSession('a post-billing refresh scheduled during validation runs '
      'after the session is restored', (tester) async {
    await change(tester, auth.beginRevalidation);
    container
        .read(subscriptionNotifierProvider.notifier)
        .schedulePostBillingRefresh(delay: billingDelay);
    await tester.pump(billingDelay);
    expect(requestCount, 0);

    await change(tester, auth.restoreAfterFailedRevalidation);
    expect(requestCount, 1);
    expect(balance(), 90);
  });

  testSession('replacing A with a lower C balance directly records no fake '
      'cost', (tester) async {
    await change(
      tester,
      () => auth.replaceSession(_account('account-c', balance: 40)),
    );

    expect(balance(), 40);
    expect(costs, isEmpty);
  });

  testSession('signing out still clears the balance and stops refreshing', (
    tester,
  ) async {
    container
        .read(subscriptionNotifierProvider.notifier)
        .schedulePostBillingRefresh(delay: billingDelay);
    await change(tester, auth.signOut);

    expect(balance(), isNull);
    await tester.pump(const Duration(minutes: 5));
    expect(requestCount, 0);
    expect(costs, isEmpty);
  });

  testSession('a validation that ends in sign-out drops the deferred '
      'refresh', (tester) async {
    await change(tester, auth.beginRevalidation);
    await waitOneRefreshInterval(tester);
    await change(tester, auth.signOut);

    await tester.pump(const Duration(minutes: 5));
    expect(requestCount, 0);
    expect(balance(), isNull);
  });

  testSession('a periodic tick and a post-billing refresh deferred together '
      'by a critical request keep the cadence', (tester) async {
    final lease = CriticalNetworkActivityCoordinator.instance.acquire(
      CriticalNetworkActivityType.imageGeneration,
    );
    addTearDown(lease.release);
    container
        .read(subscriptionNotifierProvider.notifier)
        .schedulePostBillingRefresh(delay: billingDelay);
    await waitOneRefreshInterval(tester);
    expect(requestCount, 0);

    lease.release();
    await settle(tester);
    expect(requestCount, 1);
    await waitOneRefreshInterval(tester);
    expect(requestCount, 2);
  });

  testWidgets('a first fetch deferred together with a post-billing refresh '
      'still starts the refresh cadence', (tester) async {
    final lease = CriticalNetworkActivityCoordinator.instance.acquire(
      CriticalNetworkActivityType.imageGeneration,
    );
    addTearDown(lease.release);
    final unhydrated = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UnhydratedAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(api),
      ],
    );
    try {
      unhydrated.listen(subscriptionNotifierProvider, (_, __) {});
      await tester.pump(Duration.zero);
      unhydrated
          .read(subscriptionNotifierProvider.notifier)
          .schedulePostBillingRefresh(delay: billingDelay);
      await tester.pump(billingDelay);
      expect(requestCount, 0);

      lease.release();
      await tester.pump(Duration.zero);
      expect(requestCount, 1);
      expect(unhydrated.read(subscriptionNotifierProvider).balance, 90);

      await tester.pump(refreshInterval);
      await tester.pump(gateSettle);
      expect(requestCount, 2);
    } finally {
      unhydrated.dispose();
    }
  });

  testWidgets('startup loading is not a session and the auto-login that '
      'follows starts one refresh cadence', (tester) async {
    final startup = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_StartupAuthNotifier.new),
        naiUserInfoApiServiceProvider.overrideWithValue(api),
      ],
    );
    try {
      startup.listen(subscriptionNotifierProvider, (_, __) {});
      await tester.pump(Duration.zero);
      expect(startup.read(subscriptionNotifierProvider).balance, isNull);

      (startup.read(authNotifierProvider.notifier) as _StartupAuthNotifier)
          .completeAutoLogin();
      startup.read(subscriptionNotifierProvider);
      await tester.pump(Duration.zero);
      expect(startup.read(subscriptionNotifierProvider).balance, 100);

      await tester.pump(refreshInterval);
      await tester.pump(gateSettle);
      expect(requestCount, 1);
      await tester.pump(refreshInterval);
      await tester.pump(gateSettle);
      expect(requestCount, 2);
    } finally {
      startup.dispose();
    }
  });

  group('AuthState.isRevalidatingSession', () {
    test('only a loading state copied from a signed-in session counts', () {
      final signedIn = _account('account-a', balance: 1);
      expect(
        signedIn.copyWith(status: AuthStatus.loading).isRevalidatingSession,
        isTrue,
      );
      expect(signedIn.isRevalidatingSession, isFalse);
      expect(
        const AuthState(status: AuthStatus.loading).isRevalidatingSession,
        isFalse,
        reason: 'startup and auto-login retry start from a bare loading',
      );
      expect(
        const AuthState(
          status: AuthStatus.error,
        ).copyWith(status: AuthStatus.loading).isRevalidatingSession,
        isFalse,
      );
    });
  });
}
