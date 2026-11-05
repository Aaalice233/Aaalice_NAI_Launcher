import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_billing_freshness.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import 'subscription_billing_harness.dart';

void main() {
  final harness = SubscriptionBillingHarness.register();

  ProviderContainer loadedInFakeAsync(FakeAsync async) {
    harness.answerSubscription(
      () => billingSubscriptionJson(quotaExhausted: false),
    );
    final container = harness.createContainer(
      AuthenticatedBillingAuth.new,
      freeV5Request: false,
    );
    async.flushMicrotasks();
    expect(harness.requestCount(), 1);
    return container;
  }

  void rebuildForSameAccount(ProviderContainer container) {
    (container.read(authNotifierProvider.notifier) as AuthenticatedBillingAuth)
        .updateSessionMetadata();
  }

  test('fresh data is used without another request', () async {
    final container = await harness.loadedContainer();
    harness.now = harness.now.add(SubscriptionBillingFreshness.window);

    expect(await readSettledEstimatedCost(container), 0);

    expect(harness.requestCount(), 1);
  });

  test('concurrent billing checks on stale data share one refresh', () async {
    final container = await harness.loadedContainer();
    expect(harness.requestCount(), 1);
    harness.now = harness.now.add(
      SubscriptionBillingFreshness.window + const Duration(seconds: 1),
    );
    final response = Completer<Map<String, dynamic>>();
    harness.answerSubscription(() => response.future);
    final notifier = container.read(subscriptionNotifierProvider.notifier);

    final checks = [
      notifier.ensureFreshForBilling(),
      notifier.ensureFreshForBilling(),
      readSettledEstimatedCost(container),
    ];
    await Future<void>.delayed(Duration.zero);
    response.complete(billingSubscriptionJson(quotaExhausted: true));
    final results = await Future.wait(checks);

    expect(results.take(2), [true, true]);
    expect(results.last, greaterThan(0));
    expect(harness.requestCount(), 1);
  });

  test('a billed request ending makes fresh data stale until its charge '
      'settles', () async {
    final container = await harness.loadedContainer();
    final notifier = container.read(subscriptionNotifierProvider.notifier);
    harness.answerSubscription(
      () => billingSubscriptionJson(quotaExhausted: true),
    );

    CriticalNetworkActivityCoordinator.instance
        .acquire(CriticalNetworkActivityType.imageGeneration)
        .release();
    final cost = await readSettledEstimatedCost(container);

    expect(cost, greaterThan(0));
    expect(harness.requestCount(), 2);
    expect(notifier.billingView.opusQuotaExhausted, isTrue);
    expect(notifier.billingView.isOpus, isTrue);
  });

  test('a billing check during a billed request refreshes only after the '
      'charge settles', () {
    fakeAsync((async) {
      final container = loadedInFakeAsync(async);
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      final lease = CriticalNetworkActivityCoordinator.instance.acquire(
        CriticalNetworkActivityType.imageGeneration,
      );

      bool? fresh;
      notifier.ensureFreshForBilling().then((value) => fresh = value);
      async.elapse(const Duration(milliseconds: 20));
      harness.answerSubscription(
        () => billingSubscriptionJson(quotaExhausted: true),
      );
      lease.release();
      async.elapse(
        SubscriptionNotifier.postBillingRefreshDelay -
            const Duration(milliseconds: 1),
      );
      expect(fresh, isNull);
      harness.expectNoRequest();

      async.elapse(const Duration(milliseconds: 2));

      expect(fresh, isTrue);
      expect(
        harness.requestCount(),
        1,
        reason: 'one refresh after the charge settled',
      );
      expect(notifier.billingView.opusQuotaExhausted, isTrue);
      expect(notifier.billingView.isOpus, isTrue);
    });
  });

  test('a refresh answered before the charge settles is not trusted to judge '
      'free', () {
    fakeAsync((async) {
      final container = loadedInFakeAsync(async);
      final notifier = container.read(subscriptionNotifierProvider.notifier);

      // 生成请求已结束，生成页还没来得及登记扣点后刷新
      CriticalNetworkActivityCoordinator.instance
          .acquire(CriticalNetworkActivityType.imageGeneration)
          .release();
      notifier.refreshBalance();
      async.flushMicrotasks();
      expect(harness.requestCount(), 1);
      harness.answerSubscription(
        () => billingSubscriptionJson(quotaExhausted: true),
      );

      bool? fresh;
      notifier.ensureFreshForBilling().then((value) => fresh = value);
      async.flushMicrotasks();
      expect(fresh, isNull);

      async.elapse(SubscriptionNotifier.postBillingRefreshDelay);

      expect(fresh, isTrue);
      expect(harness.requestCount(), 1);
      expect(notifier.billingView.opusQuotaExhausted, isTrue);
      expect(notifier.billingView.isOpus, isTrue);
    });
  });

  test('a same-account auth update does not end the settle window early', () {
    fakeAsync((async) {
      final container = loadedInFakeAsync(async);
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      CriticalNetworkActivityCoordinator.instance
          .acquire(CriticalNetworkActivityType.imageGeneration)
          .release();

      rebuildForSameAccount(container);
      container.read(subscriptionNotifierProvider);
      notifier.refreshBalance();
      async.flushMicrotasks();
      expect(harness.requestCount(), 1);
      harness.answerSubscription(
        () => billingSubscriptionJson(quotaExhausted: true),
      );

      bool? fresh;
      notifier.ensureFreshForBilling().then((value) => fresh = value);
      async.flushMicrotasks();
      expect(fresh, isNull);

      async.elapse(SubscriptionNotifier.postBillingRefreshDelay);

      expect(fresh, isTrue);
      expect(harness.requestCount(), 1);
      expect(notifier.billingView.opusQuotaExhausted, isTrue);
    });
  });

  test('a billed request ending while the notifier rebuilds still opens the '
      'settle window', () {
    fakeAsync((async) {
      final container = loadedInFakeAsync(async);
      final notifier = container.read(subscriptionNotifierProvider.notifier);
      final lease = CriticalNetworkActivityCoordinator.instance.acquire(
        CriticalNetworkActivityType.imageGeneration,
      );

      rebuildForSameAccount(container);
      lease.release();
      container.read(subscriptionNotifierProvider);
      notifier.refreshBalance();
      async.flushMicrotasks();
      expect(harness.requestCount(), 1);
      harness.answerSubscription(
        () => billingSubscriptionJson(quotaExhausted: true),
      );

      bool? fresh;
      notifier.ensureFreshForBilling().then((value) => fresh = value);
      async.flushMicrotasks();
      expect(fresh, isNull);

      async.elapse(SubscriptionNotifier.postBillingRefreshDelay);

      expect(fresh, isTrue);
      expect(harness.requestCount(), 1);
      expect(notifier.billingView.opusQuotaExhausted, isTrue);
    });
  });
}
