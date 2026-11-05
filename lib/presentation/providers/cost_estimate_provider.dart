import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/anlas_calculator.dart';
import '../../core/utils/focused_inpaint_utils.dart';
import '../../data/models/image/image_params.dart';
import 'image_generation_provider.dart';
import 'generation/image_workflow_controller.dart';
import 'subscription_billing.dart';
import 'subscription_provider.dart';

part 'cost_estimate_provider.g.dart';

typedef GenerationPageRequest = (ImageParams, ImageWorkflowState, int);

GenerationPageRequest readGenerationPageRequest(ProviderContainer container) =>
    (
      container.read(generationParamsNotifierProvider).copyWith(),
      container.read(imageWorkflowControllerProvider),
      container.read(imagesPerRequestProvider),
    );

/// 估价用的请求几何；[size] 为 null 时按参数本身的尺寸计费。
class _RequestGeometry {
  const _RequestGeometry(this.size);

  static const unfocused = _RequestGeometry(null);

  final ({int width, int height})? size;
}

/// 蒙版外接矩形首次在后台计算、还没有可沿用的结果时返回 null。
_RequestGeometry? _resolveRequestGeometry(
  ImageParams params,
  ImageWorkflowState workflow,
  AsyncValue<FocusedInpaintGeometry?> Function() readFocusedMaskGeometry,
) {
  if (!workflow.focusedInpaintEnabled || !params.isInpainting) {
    return _RequestGeometry.unfocused;
  }
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
  } else {
    final maskGeometry = readFocusedMaskGeometry();
    if (maskGeometry.hasError) {
      focusedGeometry = maskGeometry.requireValue;
    } else if (maskGeometry.isLoading) {
      focusedGeometry = maskGeometry.value;
      if (focusedGeometry == null) return null;
    } else {
      focusedGeometry = maskGeometry.requireValue;
    }
  }
  if (focusedGeometry == null) return _RequestGeometry.unfocused;
  return _RequestGeometry((
    width: focusedGeometry.requestWidth,
    height: focusedGeometry.requestHeight,
  ));
}

/// 界面实时估价与确认前的落定估价共用这一份计算，只差订阅视图从哪里来。
int? _estimateCost({
  required ImageParams params,
  required ImageWorkflowState workflow,
  required AsyncValue<FocusedInpaintGeometry?> Function()
  readFocusedMaskGeometry,
  required int batchSize,
  required SubscriptionBillingView billing,
}) {
  if (workflow.isUpscale) {
    if (workflow.upscale.backend != UpscaleBackend.novelai) {
      return 0;
    }
    return AnlasCalculator.calculateNovelAiUpscaleCost(
      inputWidth: workflow.sourceWidth ?? params.width,
      inputHeight: workflow.sourceHeight ?? params.height,
      scale: 2,
      isOpus: billing.isOpus,
    );
  }

  if (params.nSamples <= 0 || batchSize <= 0) {
    return 0;
  }
  final geometry = _resolveRequestGeometry(
    params,
    workflow,
    readFocusedMaskGeometry,
  );
  if (geometry == null) {
    return null;
  }
  return AnlasCalculator.calculate(
    params,
    requestSize: geometry.size,
    batchSize: batchSize,
    isOpus: billing.isOpus,
    opusQuotaExhausted: billing.opusQuotaExhausted,
  );
}

final _maskExtentByImageProvider = FutureProvider.autoDispose.family(
  (_, Uint8List mask) => FocusedInpaintUtils.resolveMaskExtentAsync(mask),
);

/// 当前蒙版的外接矩形，在后台 isolate 解码计算，只随蒙版字节变化重算；
/// 费用预估与图生图预览的聚焦框共用这一次计算。
@riverpod
FutureOr<FocusedInpaintMaskExtent?> focusedInpaintMaskExtent(Ref ref) {
  final maskImage = ref.watch(
    generationParamsNotifierProvider.select((params) => params.maskImage),
  );
  if (maskImage == null) {
    return null;
  }
  return ref.watch(_maskExtentByImageProvider(maskImage)).requireValue;
}

/// 聚焦重绘"仅蒙版"场景下的请求几何（轻量路径）。
///
/// 只求蒙版外接矩形，不做完整 prepareRequest 的裁剪/缩放/PNG 编码；
/// 调整上下文参数只重算几何，不重新解码蒙版。外接矩形重算期间返回
/// 带上一次几何的 [AsyncLoading]，首次计算尚无结果时不带值。
@riverpod
FutureOr<FocusedInpaintGeometry?> focusedInpaintMaskRequestSize(Ref ref) {
  final needsMaskSize = ref.watch(
    imageWorkflowControllerProvider.select(
      (workflow) => workflow.focusesOnMaskExtent,
    ),
  );
  final isInpainting = ref.watch(
    generationParamsNotifierProvider.select((params) => params.isInpainting),
  );
  if (!needsMaskSize || !isInpainting) {
    return null;
  }

  final hasMask = ref.watch(
    generationParamsNotifierProvider.select(
      (params) => params.maskImage != null,
    ),
  );
  if (!hasMask) {
    return null;
  }

  final minContextMegaPixels = ref.watch(
    imageWorkflowControllerProvider.select(
      (workflow) => workflow.minimumContextMegaPixels,
    ),
  );
  final extent = ref
      .watch(focusedInpaintMaskExtentProvider)
      .unwrapPrevious()
      .requireValue;
  return _geometryForExtent(extent, minContextMegaPixels);
}

FocusedInpaintGeometry? _geometryForExtent(
  FocusedInpaintMaskExtent? extent,
  double padding,
) => extent == null
    ? null
    : FocusedInpaintUtils.resolveGeometryForMaskExtent(
        extent,
        minContextMegaPixels: padding,
      );

/// 蒙版外接矩形仍在后台计算时先等它落定，给出与同步计算一致的预估消耗。
///
/// 界面在计算期间只有上一次的结果或"计算中"，需要确切数值的确认流程走这里；
/// 订阅数据过期时先刷新，刷新失败则按不免费计价。
Future<int> readSettledEstimatedCost(
  ProviderContainer container,
  GenerationPageRequest request,
) async {
  final billing = await container
      .read(subscriptionNotifierProvider.notifier)
      .freshBillingView();
  final (params, workflow, batchSize) = request;
  final extent = workflow.focusesOnMaskExtent && params.isInpainting
      ? await container.read(
          _maskExtentByImageProvider(params.maskImage!).future,
        )
      : null;
  return _estimateCost(
    params: params,
    workflow: workflow,
    readFocusedMaskGeometry: () => AsyncData(
      _geometryForExtent(extent, workflow.minimumContextMegaPixels),
    ),
    batchSize: batchSize,
    billing: billing,
  )!;
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
int? estimatedCost(Ref ref) => _estimateCost(
  params: ref.watch(generationParamsNotifierProvider),
  workflow: ref.watch(imageWorkflowControllerProvider),
  readFocusedMaskGeometry: () =>
      ref.watch(focusedInpaintMaskRequestSizeProvider),
  batchSize: ref.watch(imagesPerRequestProvider),
  billing: ref.watch(subscriptionBillingViewProvider),
);

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
