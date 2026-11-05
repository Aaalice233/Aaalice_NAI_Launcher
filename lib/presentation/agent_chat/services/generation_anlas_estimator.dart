import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/anlas_calculator.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/cost_estimate_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/subscription_billing.dart';
import '../../providers/subscription_provider.dart';

class GenerationAnlasEstimator {
  GenerationAnlasEstimator(this._ref);

  final Ref _ref;

  int get currentBatchSize => _ref.read(imagesPerRequestProvider);

  /// 订阅数据过期时先刷新；用于放行与审批判断的估价都从这里取订阅视图。
  Future<SubscriptionBillingView> freshBilling() =>
      _ref.read(subscriptionNotifierProvider.notifier).freshBillingView();

  /// [billing] 必须来自 [freshBilling]，不能拿未经刷新的订阅视图判定免费。
  int estimate(
    ImageParams params, {
    required int requestCount,
    int? batchSize,
    required SubscriptionBillingView billing,
  }) => estimateWithBilling(
    params,
    requestCount: requestCount,
    batchSize: batchSize ?? currentBatchSize,
    billing: billing,
  );

  Future<int> estimateFresh(
    ImageParams params, {
    required int requestCount,
    int? batchSize,
  }) async {
    final billing = await freshBilling();
    return estimate(
      params,
      requestCount: requestCount,
      batchSize: batchSize,
      billing: billing,
    );
  }

  static int estimateWithBilling(
    ImageParams params, {
    required int requestCount,
    required int batchSize,
    required SubscriptionBillingView billing,
  }) {
    final billingSize = resolveGenerationBillingSize(
      width: params.width,
      height: params.height,
      maxEnhance: params.effectiveUpscaledEnhance,
    );
    return AnlasCalculator.calculateRequestCost(
      width: billingSize.width,
      height: billingSize.height,
      steps: params.steps,
      batchCount: params.nSamples * requestCount,
      batchSize: batchSize,
      smea: params.effectiveSmea,
      smeaDyn: params.effectiveSmeaDyn,
      model: params.model,
      subscriptionTier: billing.subscriptionTier,
      opusQuotaExhausted: billing.opusQuotaExhausted,
      strength: switch (params.action) {
        ImageGenerationAction.img2img => params.strength,
        ImageGenerationAction.infill => params.inpaintStrength,
        ImageGenerationAction.generate => 1.0,
      },
      extraPerSampleCost: AnlasCalculator.resolvePreciseReferenceExtraCost(
        params,
      ),
      extraPerRequestCost: AnlasCalculator.resolveVibeReferenceExtraCost(
        params,
      ),
      oneTimeCost: AnlasCalculator.resolveVibeEncodingCost(params),
    );
  }
}
