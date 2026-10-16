import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/services/anlas_calculator.dart';
import '../../core/utils/focused_inpaint_utils.dart';
import '../../data/models/image/image_params.dart';
import 'image_generation_provider.dart';
import 'generation/image_workflow_controller.dart';
import 'subscription_provider.dart';

part 'cost_estimate_provider.g.dart';

class _GenerationCostInput {
  const _GenerationCostInput({
    required this.width,
    required this.height,
    required this.strength,
  });

  final int width;
  final int height;
  final double strength;
}

/// Resolves the dimensions used by both Anlas and Opus quota calculations.
({int width, int height}) resolveGenerationBillingSize({
  required int width,
  required int height,
  required bool maxEnhance,
}) {
  if (!maxEnhance) {
    return (width: width, height: height);
  }
  return E2eUpscale.resolveMaxEnhanceTargetSize(width, height);
}

/// 蒙版外接矩形首次在后台计算、还没有可沿用的结果时返回 null。
_GenerationCostInput? _resolveGenerationCostInput(
  ImageParams params,
  ImageWorkflowState workflow,
  AsyncValue<FocusedInpaintGeometry?> focusedMaskGeometry,
) {
  if (workflow.focusedInpaintEnabled && params.isInpainting) {
    final sourceWidth =
        workflow.sourceImageWidth ?? workflow.sourceWidth ?? params.width;
    final sourceHeight =
        workflow.sourceImageHeight ?? workflow.sourceHeight ?? params.height;
    final contextCrop = workflow.focusedContextCrop;
    final focusedSelectionRect = workflow.focusedSelectionRect;
    final FocusedInpaintGeometry? focusedGeometry;
    if (contextCrop != null) {
      focusedGeometry = FocusedInpaintUtils.resolveGeometryForCrop(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        crop: contextCrop,
      );
    } else if (focusedSelectionRect != null) {
      focusedGeometry = FocusedInpaintUtils.resolveGeometryForSelection(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        selectionRect: focusedSelectionRect,
        minContextMegaPixels: workflow.minimumContextMegaPixels,
      );
    } else if (focusedMaskGeometry.hasValue || focusedMaskGeometry.hasError) {
      focusedGeometry = focusedMaskGeometry.requireValue;
    } else {
      return null;
    }
    if (focusedGeometry != null) {
      return _GenerationCostInput(
        width: focusedGeometry.requestWidth,
        height: focusedGeometry.requestHeight,
        strength: params.inpaintStrength,
      );
    }
  }

  // 增强 max 档：请求携带原图尺寸，但服务端按放大到 3.14MP 的面积计费。
  final billingSize = resolveGenerationBillingSize(
    width: params.width,
    height: params.height,
    maxEnhance: params.effectiveUpscaledEnhance,
  );

  return _GenerationCostInput(
    width: billingSize.width,
    height: billingSize.height,
    strength: switch (params.action) {
      ImageGenerationAction.img2img => params.strength,
      ImageGenerationAction.infill => params.inpaintStrength,
      ImageGenerationAction.generate => 1.0,
    },
  );
}

/// 当前蒙版的外接矩形，在后台 isolate 解码计算，只随蒙版字节变化重算；
/// 费用预估与图生图预览的聚焦框共用这一次计算。
@riverpod
Future<FocusedInpaintMaskExtent?> focusedInpaintMaskExtent(Ref ref) async {
  final maskImage = ref.watch(
    generationParamsNotifierProvider.select((params) => params.maskImage),
  );
  if (maskImage == null) {
    return null;
  }
  return FocusedInpaintUtils.resolveMaskExtentAsync(maskImage);
}

/// 聚焦重绘"仅蒙版"场景下的请求几何（轻量路径）。
///
/// 只求蒙版外接矩形，不做完整 prepareRequest 的裁剪/缩放/PNG 编码；
/// 调整上下文参数只重算几何，不重新解码蒙版。外接矩形重算期间返回
/// 带上一次几何的 [AsyncLoading]，首次计算尚无结果时不带值。
@riverpod
AsyncValue<FocusedInpaintGeometry?> focusedInpaintMaskRequestSize(Ref ref) {
  final needsMaskSize = ref.watch(
    imageWorkflowControllerProvider.select(
      (workflow) => workflow.focusesOnMaskExtent,
    ),
  );
  final isInpainting = ref.watch(
    generationParamsNotifierProvider.select((params) => params.isInpainting),
  );
  if (!needsMaskSize || !isInpainting) {
    return const AsyncData(null);
  }

  final hasMask = ref.watch(
    generationParamsNotifierProvider.select(
      (params) => params.maskImage != null,
    ),
  );
  if (!hasMask) {
    return const AsyncData(null);
  }

  final minContextMegaPixels = ref.watch(
    imageWorkflowControllerProvider.select(
      (workflow) => workflow.minimumContextMegaPixels,
    ),
  );
  FocusedInpaintGeometry? resolve(FocusedInpaintMaskExtent? extent) =>
      extent == null
      ? null
      : FocusedInpaintUtils.resolveGeometryForMaskExtent(
          extent,
          minContextMegaPixels: minContextMegaPixels,
        );

  final extent = ref.watch(focusedInpaintMaskExtentProvider);
  if (extent.isLoading) {
    if (!extent.hasValue) {
      return const AsyncLoading();
    }
    return const AsyncLoading<FocusedInpaintGeometry?>().copyWithPrevious(
      AsyncData(resolve(extent.valueOrNull)),
      isRefresh: false,
    );
  }
  if (extent.hasError) {
    return AsyncError(extent.error!, extent.stackTrace!);
  }
  return AsyncData(resolve(extent.valueOrNull));
}

/// 蒙版外接矩形仍在后台计算时先等它落定，给出与同步计算一致的预估消耗。
///
/// 界面在计算期间只有上一次的结果或"计算中"，需要确切数值的确认流程走这里。
Future<int> readSettledEstimatedCost(ProviderContainer container) async {
  final maskGeometry = container.listen(
    focusedInpaintMaskRequestSizeProvider,
    (_, __) {},
  );
  try {
    while (maskGeometry.read().isLoading) {
      await container.read(focusedInpaintMaskExtentProvider.future);
    }
    final cost = container.read(estimatedCostProvider);
    return cost!;
  } finally {
    maskGeometry.close();
  }
}

/// 预估消耗 Provider
///
/// 根据当前参数实时计算预估的 Anlas 消耗；聚焦重绘的蒙版外接矩形首次
/// 在后台计算、还没有可沿用的结果时为 null（计算中）
///
/// 计费逻辑：
/// - nSamples（批次数量）：应用内循环，每次是独立请求，每次都可享受 Opus 免费
/// - imagesPerRequest（批次大小）：单次请求生成多张，只有第一张免费
@riverpod
int? estimatedCost(Ref ref) {
  final params = ref.watch(generationParamsNotifierProvider);
  final workflow = ref.watch(imageWorkflowControllerProvider);
  final imagesPerRequest = ref.watch(imagesPerRequestProvider);
  final subscription = ref.watch(
    subscriptionNotifierProvider.select((state) => state.subscription),
  );
  final subscriptionTier = subscription?.isOpus == true
      ? AnlasCalculator.opusTier
      : 0;
  // V5 的 Opus 免费额度是随时间回充的配额池，透支后按正常价扣 Anlas。
  final opusQuotaExhausted = subscription?.usage?.isNegative ?? false;

  if (workflow.isUpscale) {
    if (workflow.upscale.backend != UpscaleBackend.novelai) {
      return 0;
    }

    final inputWidth = workflow.sourceWidth ?? params.width;
    final inputHeight = workflow.sourceHeight ?? params.height;
    return AnlasCalculator.calculateNovelAiUpscaleCost(
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      scale: 2,
      subscriptionTier: subscriptionTier,
    );
  }

  final batchCount = params.nSamples;
  final batchSize = imagesPerRequest;
  if (batchCount <= 0 || batchSize <= 0) {
    return 0;
  }

  final requestInput = _resolveGenerationCostInput(
    params,
    workflow,
    ref.watch(focusedInpaintMaskRequestSizeProvider),
  );
  if (requestInput == null) {
    return null;
  }
  return AnlasCalculator.calculateRequestCost(
    width: requestInput.width,
    height: requestInput.height,
    steps: params.steps,
    batchCount: batchCount,
    batchSize: batchSize,
    smea: params.effectiveSmea,
    smeaDyn: params.effectiveSmeaDyn,
    model: params.model,
    subscriptionTier: subscriptionTier,
    opusQuotaExhausted: opusQuotaExhausted,
    strength: requestInput.strength,
    extraPerSampleCost: AnlasCalculator.resolvePreciseReferenceExtraCost(
      params,
    ),
    extraPerRequestCost: AnlasCalculator.resolveVibeReferenceExtraCost(params),
    oneTimeCost: AnlasCalculator.resolveVibeEncodingCost(params),
  );
}

/// 是否免费生成 Provider
///
/// 只有总消耗为 0 时才是免费
@riverpod
bool isFreeGeneration(Ref ref) {
  final cost = ref.watch(estimatedCostProvider);
  return cost == 0;
}

/// 余额是否不足 Provider
@riverpod
bool isBalanceInsufficient(Ref ref) {
  final balance = ref.watch(anlasBalanceProvider);
  final cost = ref.watch(estimatedCostProvider);

  // 余额未加载或消耗仍在计算时不显示警告
  if (balance == null || cost == null) return false;
  return balance < cost;
}
