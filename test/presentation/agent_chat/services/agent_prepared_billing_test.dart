import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/data/services/inpaint_draft_file_repository.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_prepared_anlas_estimator.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_anlas_estimator.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_upscale_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/manual_inpaint_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/presentation/providers/subscription_billing.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import '../../../helpers/stale_opus_subscription.dart';

final _refProvider = Provider<Ref>((ref) => ref);

const _freeV5Request = ImageParams(
  prompt: 'quota',
  model: ImageModels.animeDiffusionV5Full,
  width: 832,
  height: 1216,
  steps: 28,
);

const _opusWithQuota = SubscriptionBillingView(
  isOpus: true,
  opusQuotaExhausted: false,
);

const _opusQuotaExhausted = SubscriptionBillingView(
  isOpus: true,
  opusQuotaExhausted: true,
);

class _MockUserInfoApi extends Mock implements NAIUserInfoApiService {}

// 登录校验时带回的订阅只说明登录那一刻的配额，放行前必须重新取一次
class _HydratedOpusAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    accountId: 'prepared-billing',
    subscriptionInfo: _opusWithQuotaJson,
  );
}

const _opusWithQuotaJson = <String, dynamic>{
  'tier': 3,
  'active': true,
  'trainingStepsLeft': {
    'fixedTrainingStepsLeft': 1000,
    'purchasedTrainingSteps': 0,
  },
  'usage': {'percent': 40, 'isNegative': false, 'timeUntilNextPercent': 6048},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'nai_agent_prepared_billing_',
    );
    addTearDown(() => supportDirectory.delete(recursive: true));
  });

  Future<int?> estimate(
    ProviderContainer container,
    String toolName,
    Map<String, dynamic> args, {
    GenerationPreparationRuntime? generationRuntime,
    InpaintDraftFileRepository? repository,
    required Future<SubscriptionBillingView> Function() freshBilling,
  }) {
    final ref = container.read(_refProvider);
    return estimatePreparedAnlas(
      toolName,
      args,
      generationRuntime: generationRuntime ?? GenerationPreparationRuntime(),
      queueRuntime: QueueControlRuntime(),
      manualInpaintToolbox: ManualInpaintToolbox(
        ref,
        supportDirectory: supportDirectory,
        repository: repository,
      ),
      imageUpscaleToolbox: ImageUpscaleToolbox(ref),
      freshBilling: freshBilling,
    );
  }

  GenerationPreparationRuntime runtimeWith(GenerationPreparation preparation) =>
      GenerationPreparationRuntime()..add(preparation);

  GenerationPreparation freePreparation({
    GenerationPreparationKind kind = GenerationPreparationKind.generate,
    int count = 1,
  }) => GenerationPreparation(
    kind: kind,
    baseParams: _freeV5Request,
    params: _freeV5Request,
    batchSize: 1,
    count: count,
    autoStart: true,
    estimatedAnlas: 0,
    billing: _opusWithQuota,
    arguments: const {'prompt': 'quota'},
  );

  test('a queued task repriced after the quota ran out charges every '
      'request', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final preparation = freePreparation(
      kind: GenerationPreparationKind.queue,
      count: 3,
    );

    final repriced = await estimate(
      container,
      'queue_image_task',
      {'preparation_id': preparation.id},
      generationRuntime: runtimeWith(preparation),
      freshBilling: () async => _opusQuotaExhausted,
    );

    final single = GenerationAnlasEstimator.estimateWithBilling(
      _freeV5Request,
      requestCount: 1,
      batchSize: 1,
      billing: _opusQuotaExhausted,
    );
    expect(single, greaterThan(0));
    expect(repriced, single * 3);
  });

  group('manual inpaint draft approval', () {
    Future<(int?, StaleOpusSubscription)> estimateDraft(
      StaleOpusRefreshOutcome outcome,
    ) async {
      final subscription = StaleOpusSubscription(outcome);
      final container = ProviderContainer(
        overrides: [
          subscriptionNotifierProvider.overrideWith(() => subscription),
        ],
      );
      addTearDown(container.dispose);
      final repository = InpaintDraftFileRepository(
        rootDirectory: Directory('${supportDirectory.path}/drafts'),
      );
      final draft = await repository.prepare(
        sourceBytes: Uint8List.fromList(
          img.encodePng(img.Image(width: 8, height: 8)),
        ),
        parameterSnapshot: {..._freeV5Request.toJson(), '_agentBatchSize': 1},
        estimatedAnlas: 0,
      );

      final estimated = await estimate(
        container,
        'submit_manual_inpaint_draft',
        {'draft_id': draft.id},
        repository: repository,
        freshBilling: () async => _opusWithQuota,
      );
      return (estimated, subscription);
    }

    test('refreshes stale data first; an exhausted quota is charged', () async {
      final (estimated, subscription) = await estimateDraft(
        StaleOpusRefreshOutcome.quotaExhausted,
      );

      expect(subscription.billingChecks, 1);
      expect(estimated, greaterThan(0));
    });

    test('a failed refresh is charged instead of assumed free', () async {
      final (estimated, _) = await estimateDraft(
        StaleOpusRefreshOutcome.failed,
      );

      expect(estimated, greaterThan(0));
    });

    test('verified data keeps the free estimate', () async {
      final (estimated, subscription) = await estimateDraft(
        StaleOpusRefreshOutcome.stillFresh,
      );

      expect(subscription.billingChecks, 1);
      expect(estimated, 0);
    });
  });

  test('the subscription notifier refreshes a login-time subscription before '
      'approving a free preparation', () async {
    final api = _MockUserInfoApi();
    when(
      () => api.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => {
        ..._opusWithQuotaJson,
        'usage': {
          'percent': 0,
          'isNegative': true,
          'timeUntilNextPercent': 6048,
        },
      },
    );
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_HydratedOpusAuth.new),
        naiUserInfoApiServiceProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.listen(subscriptionNotifierProvider, (_, __) {});
    final preparation = freePreparation();

    final estimated = await estimate(
      container,
      'submit_generation',
      {'preparation_id': preparation.id},
      generationRuntime: runtimeWith(preparation),
      freshBilling: () => container
          .read(subscriptionNotifierProvider.notifier)
          .freshBillingView(),
    );

    verify(
      () => api.getUserSubscription(
        receiveTimeout: any(named: 'receiveTimeout'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    expect(estimated, greaterThan(0));
  });
}
