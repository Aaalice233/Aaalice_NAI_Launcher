import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/cost_estimate_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

class _MockUserInfoApi extends Mock implements NAIUserInfoApiService {}

// 登录校验时带回的订阅，只说明登录那一刻的配额，不算刚刷新过
class HydratedOpusAuth extends AuthNotifier {
  HydratedOpusAuth([Map<String, dynamic>? subscriptionInfo])
    : subscriptionInfo =
          subscriptionInfo ?? billingSubscriptionJson(quotaExhausted: false);

  final Map<String, dynamic> subscriptionInfo;

  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    accountId: 'billing-account',
    subscriptionInfo: subscriptionInfo,
  );
}

class SwitchableOpusAuth extends HydratedOpusAuth {
  void switchToOtherAccount() => state = AuthState(
    status: AuthStatus.authenticated,
    accountId: 'other-account',
    subscriptionInfo: billingSubscriptionJson(quotaExhausted: true),
  );
}

class AuthenticatedBillingAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    accountId: 'billing-account',
  );

  void updateSessionMetadata() =>
      state = state.copyWith(displayName: 'Updated');
}

class _ManualClock {
  DateTime now = DateTime(2026, 11, 5, 12);

  DateTime call() => now;
}

/// 订阅新鲜度测试共用的夹具：Hive 临时目录、订阅接口 mock 与可拨动的时钟。
class SubscriptionBillingHarness {
  SubscriptionBillingHarness._();

  /// 在 `main` 顶层调用，登记 Hive 与每个用例的初始化。
  factory SubscriptionBillingHarness.register() {
    final harness = SubscriptionBillingHarness._();
    late Directory hiveTempDir;

    TestWidgetsFlutterBinding.ensureInitialized();

    setUpAll(() async {
      hiveTempDir = await Directory.systemTemp.createTemp(
        'nai_launcher_billing_freshness_hive_',
      );
      Hive.init(hiveTempDir.path);
      await Hive.openBox(StorageKeys.settingsBox);
      await Hive.openBox(StorageKeys.historyBox);
    });

    tearDownAll(() async {
      await Hive.close();
      if (await hiveTempDir.exists()) {
        await hiveTempDir.delete(recursive: true);
      }
    });

    setUp(() async {
      await Hive.box(StorageKeys.settingsBox).clear();
      await Hive.box(StorageKeys.historyBox).clear();
      harness._api = _MockUserInfoApi();
      harness._clock = _ManualClock();
    });

    return harness;
  }

  late _MockUserInfoApi _api;
  late _ManualClock _clock;

  DateTime get now => _clock.now;
  set now(DateTime value) => _clock.now = value;

  void answerSubscription(FutureOr<Map<String, dynamic>> Function() answer) {
    when(
      () => _api.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => answer());
  }

  void failSubscription(DioExceptionType type) {
    when(
      () => _api.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/user/subscription'),
        type: type,
      ),
    );
  }

  int requestCount() => verify(
    () => _api.getUserSubscription(
      receiveTimeout: any(named: 'receiveTimeout'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).callCount;

  void expectNoRequest() => verifyNever(
    () => _api.getUserSubscription(
      receiveTimeout: any(named: 'receiveTimeout'),
      cancelToken: any(named: 'cancelToken'),
    ),
  );

  /// [freeV5Request] 会写 Hive，FakeAsync 里的用例必须传 false。
  ProviderContainer createContainer(
    AuthNotifier Function() auth, {
    bool freeV5Request = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(auth),
        naiUserInfoApiServiceProvider.overrideWithValue(_api),
        subscriptionBillingClockProvider.overrideWithValue(_clock.call),
      ],
    );
    addTearDown(container.dispose);
    container.listen(subscriptionNotifierProvider, (_, __) {});
    if (!freeV5Request) return container;
    container
        .read(generationParamsNotifierProvider.notifier)
        .updateModel(
          ImageModels.animeDiffusionV5Full,
          persist: false,
          followDefaults: false,
        );
    final params = container.read(generationParamsNotifierProvider.notifier);
    params.updateSize(832, 1216);
    params.updateSteps(28);
    return container;
  }

  Future<ProviderContainer> loadedContainer() async {
    answerSubscription(() => billingSubscriptionJson(quotaExhausted: false));
    final container = createContainer(AuthenticatedBillingAuth.new);
    await container
        .read(subscriptionNotifierProvider.notifier)
        .fetchSubscription();
    expect(container.read(estimatedCostProvider), 0);
    return container;
  }
}

Map<String, dynamic> billingSubscriptionJson({required bool quotaExhausted}) =>
    {
      'tier': 3,
      'active': true,
      'trainingStepsLeft': {
        'fixedTrainingStepsLeft': 1000,
        'purchasedTrainingSteps': 0,
      },
      'usage': {
        'percent': quotaExhausted ? 0 : 40,
        'isNegative': quotaExhausted,
        'timeUntilNextPercent': 6048,
      },
    };
