import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

int _resolvePreciseReferenceExtraCost(ImageParams params) {
  if (!params.model.contains('diffusion-4-5')) {
    return 0;
  }
  return params.preciseReferenceCount * 5;
}

_GenerationCostInput _resolveGenerationCostInput(
  ImageParams params,
  ImageWorkflowState workflow,
  FocusedInpaintGeometry? focusedMaskGeometry,
) {
  if (workflow.focusedInpaintEnabled && params.isInpainting) {
    final focusedSelectionRect = workflow.focusedSelectionRect;
    final focusedGeometry = focusedSelectionRect == null
        ? focusedMaskGeometry
        : FocusedInpaintUtils.resolveGeometryForSelection(
            sourceWidth:
                workflow.sourceImageWidth ??
                workflow.sourceWidth ??
                params.width,
            sourceHeight:
                workflow.sourceImageHeight ??
                workflow.sourceHeight ??
                params.height,
            selectionRect: focusedSelectionRect,
            minContextMegaPixels: workflow.minimumContextMegaPixels,
          );
    if (focusedGeometry != null) {
      return _GenerationCostInput(
        width: focusedGeometry.requestWidth,
        height: focusedGeometry.requestHeight,
        strength: 1.0,
      );
    }
  }

  return _GenerationCostInput(
    width: params.width,
    height: params.height,
    strength: params.action == ImageGenerationAction.img2img
        ? params.strength
        : 1.0,
  );
}

/// 聚焦重绘"仅蒙版"场景下的请求尺寸（轻量路径）。
///
/// 只解码蒙版求外接矩形，不做完整 prepareRequest 的裁剪/缩放/PNG 编码。
/// 依赖项用 select 收窄：蒙版引用与上下文参数不变时（例如只调整
/// steps/prompt），Riverpod 直接复用缓存结果，不会重复解码蒙版。
@riverpod
FocusedInpaintGeometry? focusedInpaintMaskRequestSize(Ref ref) {
  final needsMaskSize = ref.watch(
    imageWorkflowControllerProvider.select(
      (workflow) =>
          workflow.focusedInpaintEnabled &&
          workflow.focusedSelectionRect == null,
    ),
  );
  final isInpainting = ref.watch(
    generationParamsNotifierProvider.select((params) => params.isInpainting),
  );
  if (!needsMaskSize || !isInpainting) {
    return null;
  }

  final maskImage = ref.watch(
    generationParamsNotifierProvider.select((params) => params.maskImage),
  );
  if (maskImage == null) {
    return null;
  }

  final minContextMegaPixels = ref.watch(
    imageWorkflowControllerProvider.select(
      (workflow) => workflow.minimumContextMegaPixels,
    ),
  );
  return FocusedInpaintUtils.resolveGeometryForMask(
    maskImage: maskImage,
    minContextMegaPixels: minContextMegaPixels,
  );
}

/// 预估消耗 Provider
///
/// 根据当前参数实时计算预估的 Anlas 消耗
///
/// 计费逻辑：
/// - nSamples（批次数量）：应用内循环，每次是独立请求，每次都可享受 Opus 免费
/// - imagesPerRequest（批次大小）：单次请求生成多张，只有第一张免费
@riverpod
int estimatedCost(Ref ref) {
  final params = ref.watch(generationParamsNotifierProvider);
  final workflow = ref.watch(imageWorkflowControllerProvider);
  final imagesPerRequest = ref.watch(imagesPerRequestProvider);
  final subscription = ref.watch(
    subscriptionNotifierProvider.select((state) => state.subscription),
  );

  if (workflow.isUpscale) {
    if (workflow.upscale.backend == UpscaleBackend.comfyui) {
      return 0;
    }

    final inputWidth = workflow.sourceWidth ?? params.width;
    final inputHeight = workflow.sourceHeight ?? params.height;
    return AnlasCalculator.calculateNovelAiUpscaleCost(
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      scale: 4,
      subscriptionTier: subscription?.tier ?? 0,
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
  return AnlasCalculator.calculateRequestCost(
    width: requestInput.width,
    height: requestInput.height,
    steps: params.steps,
    batchCount: batchCount,
    batchSize: batchSize,
    smea: params.smea,
    smeaDyn: params.smeaDyn,
    model: params.model,
    subscriptionTier: subscription?.tier ?? 0,
    strength: requestInput.strength,
    extraPerSampleCost: _resolvePreciseReferenceExtraCost(params),
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

  if (balance == null) return false; // 未加载时不显示警告
  return balance < cost;
}
