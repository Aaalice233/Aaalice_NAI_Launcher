import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/models/image/image_params.dart';
import '../constants/api_constants.dart';
import '../constants/model_capabilities.dart';
import '../network/request_builders/precise_reference_limit_exception.dart';
import '../network/request_builders/precise_reference_send_filter.dart';

/// Anlas 消耗计算器
///
/// 当前 V3/V4 基础计费公式与 NovelAI 网页端一致；Vibe 与 Precise
/// Reference 附加费遵循官方功能文档。服务端计费仍是最终依据。
class AnlasCalculator {
  AnlasCalculator._();

  /// Opus 基础免费额度覆盖的最大像素面积。
  static const int opusFreeMaxPixels = 1024 * 1024;
  static const int invalidCost = -3;
  static const int maximumPerSampleCost = 140;
  static const int novelAiUpscaleOpusFreeMaxInputPixels = 640 * 640;

  /// 网页端云端超分计费分档覆盖的最大输入面积，更大的原图无法估价。
  static const int novelAiUpscaleMaxInputPixels = 3145728;

  /// 当前 NovelAI 网页端的云端超分输入面积计费分档。
  static const List<(int maxInputPixels, int cost)> _novelAiUpscaleCostTiers = [
    (1048576, 1),
    (1747627, 2),
    (2446678, 3),
    (novelAiUpscaleMaxInputPixels, 4),
  ];

  static const double _areaCoefficient = 2.951823174884865e-6;
  static const double _stepAreaCoefficient = 5.753298233447344e-7;
  static const int _vibeCost = 2;
  static const int _preciseReferenceCost = 5;

  static bool usesVibeReferences(ImageParams params) {
    return params.capabilities.supportsVibeTransfer &&
        params.hasVibeReferencesV4 &&
        params.action != ImageGenerationAction.infill &&
        resolveSendablePreciseReferences(params).isEmpty;
  }

  static int resolvePreciseReferenceExtraCost(ImageParams params) {
    final count = resolveSendablePreciseReferences(params).length;
    if (count > PreciseReferenceLimitException.maxReferences) return 0;
    return count * _preciseReferenceCost;
  }

  /// 尚未编码的启用 Vibe 每个只在生成前收取一次编码费。
  static int resolveVibeEncodingCost(ImageParams params) {
    if (!usesVibeReferences(params) ||
        !params.capabilities.supportsEncodedVibeTransfer) {
      return 0;
    }

    final uncachedCount = params.enabledVibeReferencesV4.where((reference) {
      return reference.needsEncodingForModel(params.model);
    }).length;
    return uncachedCount * _vibeCost;
  }

  /// 单次请求使用超过四个 Vibe 时，每个额外 Vibe 收取 2 Anlas。
  static int resolveVibeReferenceExtraCost(ImageParams params) {
    if (!usesVibeReferences(params) ||
        !params.capabilities.supportsEncodedVibeTransfer) {
      return 0;
    }

    final extraReferenceCount = math.max(
      params.enabledVibeReferencesV4.length - 4,
      0,
    );
    return extraReferenceCount * _vibeCost;
  }

  /// 参数到 Anlas 费用的唯一入口。
  ///
  /// [requestSize] 是调用方已经确定的请求几何（如聚焦重绘的裁切尺寸），按原样
  /// 计费；不传时按 [params] 的尺寸计费，增强 max 档按 [billingSize] 换算。
  /// [batchCount] 是独立请求数，默认取 `params.nSamples`；[batchSize] 是单次
  /// 请求的张数。[isOpus] 与 [opusQuotaExhausted] 是订阅档位与 V5 配额池是否透支。
  static int calculate(
    ImageParams params, {
    ({int width, int height})? requestSize,
    int? batchCount,
    int batchSize = 1,
    bool isOpus = false,
    bool opusQuotaExhausted = false,
  }) {
    final size = requestSize ?? billingSize(params);
    return calculateRequestCost(
      width: size.width,
      height: size.height,
      steps: params.steps,
      batchCount: batchCount ?? params.nSamples,
      batchSize: batchSize,
      smea: params.effectiveSmea,
      smeaDyn: params.effectiveSmeaDyn,
      model: params.model,
      isOpus: isOpus,
      opusQuotaExhausted: opusQuotaExhausted,
      strength: switch (params.action) {
        ImageGenerationAction.img2img => params.strength,
        ImageGenerationAction.infill => params.inpaintStrength,
        ImageGenerationAction.generate => 1.0,
      },
      extraPerSampleCost: resolvePreciseReferenceExtraCost(params),
      extraPerRequestCost: resolveVibeReferenceExtraCost(params),
      oneTimeCost: resolveVibeEncodingCost(params),
    );
  }

  /// Anlas 与 Opus 配额共用的计费尺寸。
  static ({int width, int height}) billingSize(ImageParams params) =>
      resolveBillingSize(
        width: params.width,
        height: params.height,
        maxEnhance: params.effectiveUpscaledEnhance,
      );

  /// 增强 max 档请求携带原图尺寸，服务端却按放大到 3.14MP 的面积计费。
  static ({int width, int height}) resolveBillingSize({
    required int width,
    required int height,
    required bool maxEnhance,
  }) {
    if (!maxEnhance) return (width: width, height: height);
    return E2eUpscale.resolveMaxEnhanceTargetSize(width, height);
  }

  @visibleForTesting
  static int calculateRequestCost({
    required int width,
    required int height,
    required int steps,
    required int batchCount,
    required int batchSize,
    required bool smea,
    required bool smeaDyn,
    required String model,
    bool isOpus = false,
    bool opusQuotaExhausted = false,
    double strength = 1.0,
    int extraPerSampleCost = 0,
    int extraPerRequestCost = 0,
    int oneTimeCost = 0,
  }) {
    if (batchCount <= 0 || batchSize <= 0) {
      return 0;
    }

    var singleRequestCost = 0;
    for (var index = 0; index < batchSize; index++) {
      final isFirstImageInRequest = index == 0;
      final sampleCost = calculateFromValues(
        width: width,
        height: height,
        steps: steps,
        nSamples: 1,
        smea: smea,
        smeaDyn: smeaDyn,
        model: model,
        isOpus: isFirstImageInRequest && isOpus,
        opusQuotaExhausted: opusQuotaExhausted,
        strength: strength,
      );
      if (sampleCost == invalidCost) return invalidCost;
      singleRequestCost += sampleCost;
      singleRequestCost += math.max(extraPerSampleCost, 0);
    }
    singleRequestCost += math.max(extraPerRequestCost, 0);

    return singleRequestCost * batchCount + math.max(oneTimeCost, 0);
  }

  /// 计算 NovelAI 云端超分消耗。
  ///
  /// 当前网页端按输入面积分档计费，放大倍数不参与价格计算。Opus 用户输入不超过
  /// 640×640 时免费；超过当前网页端最高 3MP 分档时返回 [invalidCost]。
  static int calculateNovelAiUpscaleCost({
    required int inputWidth,
    required int inputHeight,
    required int scale,
    bool isOpus = false,
  }) {
    if (inputWidth <= 0 || inputHeight <= 0 || scale <= 0) {
      return invalidCost;
    }

    final inputPixels = inputWidth * inputHeight;
    if (isOpus && inputPixels <= novelAiUpscaleOpusFreeMaxInputPixels) {
      return 0;
    }

    for (final (maxInputPixels, cost) in _novelAiUpscaleCostTiers) {
      if (inputPixels <= maxInputPixels) return cost;
    }
    return invalidCost;
  }

  /// 根据具体参数值计算 Anlas 消耗
  @visibleForTesting
  static int calculateFromValues({
    required int width,
    required int height,
    required int steps,
    required int nSamples,
    required bool smea,
    required bool smeaDyn,
    required String model,
    bool isOpus = false,
    bool opusQuotaExhausted = false,
    double strength = 1.0,
  }) {
    final pixels = width * height;
    final capabilities = ModelCapabilityRegistry.of(model);
    // 调用方传的是界面步数，固定步数的模型按实际发送的步数计价与判定免费。
    final effectiveSteps = capabilities.fixedSettings?.steps ?? steps;

    // 计算每张图的基础消耗
    double perSample;

    if (capabilities.anlasFormula == AnlasFormula.modern) {
      // 网页端只对面积与步数部分取整，随后连乘 SMEA 倍率、模型倍率与重绘
      // 强度，最后统一取整。V5 的模型倍率是 1.5。
      final stepCost =
          _stepAreaCoefficient *
          pixels *
          effectiveSteps *
          capabilities.stepCostFactor;
      final baseCost = (_areaCoefficient * pixels + stepCost).ceil();
      final smeaFactor = !smea ? 1.0 : (!smeaDyn ? 1.2 : 1.4);
      perSample = baseCost * smeaFactor * capabilities.anlasMultiplier;
    } else {
      // 旧模型沿用已有的指数估算；本次计费更新只替换当前现代模型路径，
      // 避免用现代模型公式回算旧版请求。
      perSample =
          (15.266497014243718 *
                  math.exp(pixels / 1024 / 1024 * 0.6326248927474729) -
              15.225164493059737) *
          effectiveSteps /
          28;
    }

    // 应用 img2img 强度系数
    final int cost = math.max((perSample * strength).ceil(), 2);
    if (cost > maximumPerSampleCost) return invalidCost;

    // Opus 免费条件检查；V5 的免费额度受配额池限制，透支后不再抵扣。
    final quotaBlocked = capabilities.hasOpusUsageLimit && opusQuotaExhausted;
    final opusDiscount =
        !quotaBlocked &&
            _isOpusFree(
              isOpus: isOpus,
              steps: effectiveSteps,
              resolution: pixels,
            )
        ? 1
        : 0;

    // 最终消耗 = 单张成本 × (样本数 - Opus 折扣)
    final totalCost = cost * math.max(nSamples - opusDiscount, 0);

    return totalCost.toInt();
  }

  /// 检查是否满足 Opus 免费条件
  ///
  /// 精准参考不会取消符合条件的 Opus 基础免费额度，其附加费在请求成本中独立叠加。
  static bool _isOpusFree({
    required bool isOpus,
    required int steps,
    required int resolution,
  }) {
    return isOpus && steps <= 28 && resolution <= opusFreeMaxPixels;
  }

  /// 检查当前参数是否满足 Opus 免费条件
  static bool isOpusFreeGeneration(ImageParams params, {required bool isOpus}) {
    return calculate(params, isOpus: isOpus) == 0;
  }

  /// 计算导演工具（augment-image）的 Anlas 消耗
  ///
  /// 参考 NAI SDK `_cost.py` 的 `calculate_dimension_cost` 公式:
  ///   `ceil(2.951823174884865e-6 * pixels + 5.753298233447344e-7 * pixels * 28)`
  ///
  /// [isBgRemoval] 背景移除工具使用 `cost * 3 + 5` 的特殊定价。
  /// [isOpus] Opus 用户在分辨率 <= 1024×1024 时免费（背景移除除外）。
  static int calculateAugmentCost({
    required int width,
    required int height,
    bool isBgRemoval = false,
    bool isOpus = false,
  }) {
    int pixels = width * height;
    if (pixels < 65536) pixels = 65536;

    const steps = 28;
    final cost = math.max(
      (_areaCoefficient * pixels + _stepAreaCoefficient * pixels * steps)
          .ceil(),
      2,
    );

    if (isBgRemoval) {
      return cost * 3 + 5;
    }

    if (isOpus && pixels <= opusFreeMaxPixels) {
      return 0;
    }

    return cost;
  }

  /// 获取分辨率等级描述
  static String getResolutionTier(int width, int height) {
    final pixels = width * height;
    if (pixels <= 512 * 768) return 'Small';
    if (pixels <= 1024 * 1024) return 'Normal';
    if (pixels <= 1536 * 1536) return 'Large';
    return 'Wallpaper';
  }
}
