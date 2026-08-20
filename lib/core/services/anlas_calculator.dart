import 'dart:math' as math;

import '../../data/models/image/image_params.dart';
import '../constants/model_capabilities.dart';

/// Anlas 消耗计算器
///
/// 当前 V3/V4 基础计费公式与 NovelAI 网页端一致；Vibe 与 Precise
/// Reference 附加费遵循官方功能文档。服务端计费仍是最终依据。
class AnlasCalculator {
  AnlasCalculator._();

  static const int opusTier = 3;
  static const int invalidCost = -3;
  static const int maximumPerSampleCost = 140;
  static const int novelAiUpscaleOpusFreeMaxInputPixels = 640 * 640;

  static const double _areaCoefficient = 2.951823174884865e-6;
  static const double _stepAreaCoefficient = 5.753298233447344e-7;
  static const int _vibeCost = 2;
  static const int _preciseReferenceCost = 5;

  static bool _usesPreciseReferences(ImageParams params) {
    return params.capabilities.supportsPreciseReference &&
        params.hasPreciseReferences;
  }

  static bool usesVibeReferences(ImageParams params) {
    return params.capabilities.supportsVibeTransfer &&
        params.hasVibeReferencesV4 &&
        params.action != ImageGenerationAction.infill &&
        !_usesPreciseReferences(params);
  }

  static int resolvePreciseReferenceExtraCost(ImageParams params) {
    if (!_usesPreciseReferences(params)) {
      return 0;
    }
    return params.preciseReferenceCount * _preciseReferenceCost;
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

  /// 计算预估 Anlas 消耗
  ///
  /// [params] 图像生成参数
  /// [isOpus] 是否 Opus 订阅
  static int calculate(ImageParams params, {bool isOpus = false}) {
    return calculateRequestCost(
      width: params.width,
      height: params.height,
      steps: params.steps,
      batchCount: params.nSamples,
      batchSize: 1,
      smea: params.effectiveSmea,
      smeaDyn: params.effectiveSmeaDyn,
      model: params.model,
      subscriptionTier: isOpus ? opusTier : 0,
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

  static int calculateRequestCost({
    required int width,
    required int height,
    required int steps,
    required int batchCount,
    required int batchSize,
    required bool smea,
    required bool smeaDyn,
    required String model,
    int subscriptionTier = 0,
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
        subscriptionTier: isFirstImageInRequest ? subscriptionTier : 0,
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
  /// 640×640 时免费；超过服务端支持的 1MP 输入范围时返回 [invalidCost]。
  static int calculateNovelAiUpscaleCost({
    required int inputWidth,
    required int inputHeight,
    required int scale,
    int subscriptionTier = 0,
  }) {
    if (inputWidth <= 0 || inputHeight <= 0 || scale <= 0) {
      return invalidCost;
    }

    final inputPixels = inputWidth * inputHeight;
    if (subscriptionTier >= opusTier &&
        inputPixels <= novelAiUpscaleOpusFreeMaxInputPixels) {
      return 0;
    }

    if (inputPixels <= 512 * 512) return 1;
    if (inputPixels <= 640 * 640) return 2;
    if (inputPixels <= 512 * 1024) return 3;
    if (inputPixels <= 768 * 1024) return 5;
    if (inputPixels <= 1024 * 1024) return 7;
    return invalidCost;
  }

  /// 根据具体参数值计算 Anlas 消耗
  static int calculateFromValues({
    required int width,
    required int height,
    required int steps,
    required int nSamples,
    required bool smea,
    required bool smeaDyn,
    required String model,
    bool isOpus = false,
    int subscriptionTier = 0,
    double strength = 1.0,
  }) {
    final pixels = width * height;

    // 计算每张图的基础消耗
    double perSample;

    if (ModelCapabilityRegistry.of(model).anlasFormula == AnlasFormula.modern) {
      // 网页端只对面积与步数部分取整，随后连乘 SMEA 倍率与重绘强度，最后统一取整。
      final baseCost =
          (_areaCoefficient * pixels + _stepAreaCoefficient * pixels * steps)
              .ceil();
      final smeaFactor = !smea ? 1.0 : (!smeaDyn ? 1.2 : 1.4);
      perSample = baseCost * smeaFactor;
    } else {
      // 旧模型沿用已有的指数估算；本次计费更新只替换当前现代模型路径，
      // 避免用现代模型公式回算旧版请求。
      perSample =
          (15.266497014243718 *
                  math.exp(pixels / 1024 / 1024 * 0.6326248927474729) -
              15.225164493059737) *
          steps /
          28;
    }

    // 应用 img2img 强度系数
    final int cost = math.max((perSample * strength).ceil(), 2);
    if (cost > maximumPerSampleCost) return invalidCost;

    // Opus 免费条件检查
    final opusDiscount =
        _isOpusFree(
          isOpus: isOpus || subscriptionTier >= opusTier,
          steps: steps,
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
    return isOpus && steps <= 28 && resolution <= 1024 * 1024;
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

    if (isOpus && pixels <= 1048576) {
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
