import 'image_workflow_models.dart';

String defaultComfyUpscaleModelForModule(ComfyUpscaleModule module) {
  return switch (module) {
    ComfyUpscaleModule.seedvr2 => UpscaleWorkflowSettings.defaultComfyModel,
    ComfyUpscaleModule.regular => '',
    ComfyUpscaleModule.rtx => '',
  };
}

const String comfySeedvr2NativeUpscaleTemplateId =
    'builtin_seedvr2_native_upscale';
const String comfySeedvr2LegacyUpscaleTemplateId = 'builtin_seedvr2_upscale';
const String comfySeedvr2LegacyTiledUpscaleTemplateId =
    'builtin_seedvr2_tiled_upscale';
const String comfyModelUpscaleTemplateId = 'builtin_comfy_model_upscale';
const String comfyRtxUpscaleTemplateId = 'builtin_rtx_upscale';

bool isComfySeedvr2UpscaleModel(String model) {
  return model.trim().toLowerCase().contains('seedvr2');
}

bool isLegacySeedvr2ModelName(String model) {
  final normalized = model.trim().toLowerCase();
  return normalized.contains('seedvr2_ema_') ||
      normalized.endsWith('.gguf') ||
      normalized.contains('_q4');
}

List<String> filterComfyUpscaleModelsForModule(
  Iterable<String> availableModels, {
  required ComfyUpscaleModule module,
}) {
  final normalizedModels = availableModels
      .map((model) => model.trim())
      .where((model) => model.isNotEmpty)
      .toList(growable: false);

  return switch (module) {
    ComfyUpscaleModule.seedvr2 =>
      normalizedModels
          .where(isComfySeedvr2UpscaleModel)
          .toList(growable: false),
    ComfyUpscaleModule.regular =>
      normalizedModels
          .where((model) => !isComfySeedvr2UpscaleModel(model))
          .toList(growable: false),
    ComfyUpscaleModule.rtx => const [],
  };
}

String? resolveComfyUpscaleModelForModule(
  Iterable<String> availableModels, {
  required ComfyUpscaleModule module,
  required String currentModel,
}) {
  if (module == ComfyUpscaleModule.rtx) return null;

  final modelsForModule = filterComfyUpscaleModelsForModule(
    availableModels,
    module: module,
  );
  if (modelsForModule.isNotEmpty) {
    return selectPreferredUpscaleModel(
      modelsForModule,
      currentModel: currentModel,
    );
  }

  final trimmedCurrent = currentModel.trim();
  if (trimmedCurrent.isEmpty) return null;
  final currentIsSeedvr2 = isComfySeedvr2UpscaleModel(trimmedCurrent);
  return switch (module) {
    ComfyUpscaleModule.seedvr2 when currentIsSeedvr2 => trimmedCurrent,
    ComfyUpscaleModule.regular when !currentIsSeedvr2 => trimmedCurrent,
    _ => null,
  };
}

int calculateComfySeedvr2TargetResolution({
  required int sourceWidth,
  required int sourceHeight,
  required double scale,
}) {
  final shortestSide = sourceWidth < sourceHeight ? sourceWidth : sourceHeight;
  final safeShortestSide = shortestSide < 1 ? 1 : shortestSide;
  final safeScale = scale
      .clamp(UpscaleWorkflowSettings.minScale, UpscaleWorkflowSettings.maxScale)
      .toDouble();
  final resolution = (safeShortestSide * safeScale).round();
  return resolution.clamp(1, 16384).toInt();
}

int calculateComfySeedvr2TiledTargetResolution({
  required int sourceWidth,
  required int sourceHeight,
  required double scale,
}) {
  final longestSide = sourceWidth > sourceHeight ? sourceWidth : sourceHeight;
  final safeLongestSide = longestSide < 16 ? 16 : longestSide;
  final safeScale = scale
      .clamp(UpscaleWorkflowSettings.minScale, UpscaleWorkflowSettings.maxScale)
      .toDouble();
  final resolution = (safeLongestSide * safeScale).round();
  return resolution.clamp(16, 16384).toInt();
}

String selectPreferredUpscaleModel(
  Iterable<String> availableModels, {
  String? currentModel,
}) {
  final normalizedModels = availableModels
      .map((model) => model.trim())
      .where((model) => model.isNotEmpty)
      .toList(growable: false);
  if (normalizedModels.isEmpty) {
    return currentModel?.trim().isNotEmpty == true
        ? currentModel!.trim()
        : UpscaleWorkflowSettings.defaultComfyModel;
  }

  final normalizedCurrent = currentModel?.trim();
  if (normalizedCurrent != null &&
      normalizedModels.contains(normalizedCurrent)) {
    return normalizedCurrent;
  }

  const preferences = [
    ['3b', 'int8'],
    ['3b', 'fp8'],
    ['3b', 'q4'],
    ['7b', 'int8'],
    ['7b', 'fp8'],
    ['7b', 'fp16'],
  ];
  for (final preference in preferences) {
    for (final model in normalizedModels) {
      final lower = model.toLowerCase();
      if (preference.every(lower.contains)) return model;
    }
  }

  return normalizedModels.first;
}

bool shouldAutoPersistResolvedUpscaleModel({
  required bool isComfyBackend,
  required bool hasFetchedFromServer,
  required Iterable<String> availableModels,
  required String currentModel,
  required String resolvedModel,
}) {
  if (!isComfyBackend || !hasFetchedFromServer) return false;
  if (availableModels.isEmpty) return false;
  return resolvedModel != currentModel;
}

/// 决定 SeedVR2 是否把 DiT 的输入输出组件（embedding 与归一化层）也卸载到
/// CPU 内存。
///
/// 上游把这个开关描述为「在 blocks_to_swap 之上进一步压低显存」的手段，默认
/// 关闭，只在显存确实吃紧时才建议打开；它同样要求 offload_device 已设置。
/// 启动器此前把它固定为 true，导致用户即使把 [blocksToSwap] 调到 0，仍有一部分
/// 权重留在内存里、每次前向都要经 PCIe 往返。
///
/// [blocksToSwap] 为用户在界面上设定的层数，范围见
/// [UpscaleWorkflowSettings.minSeedvr2BlocksToSwap] 与
/// [UpscaleWorkflowSettings.maxSeedvr2BlocksToSwap]。
bool resolveSeedvr2SwapIoComponents(int blocksToSwap) {
  return blocksToSwap >= seedvr2SwapIoComponentsThreshold;
}

/// [resolveSeedvr2SwapIoComponents] 启用输入输出组件卸载的层数阈值。
///
/// 取值落在默认档（[UpscaleWorkflowSettings.defaultSeedvr2BlocksToSwap]）与
/// 上游给 8GB 显存的推荐档（32）之间：停在中低档位说明显存尚有余量，不值得
/// 为有限的显存收益换来每次前向都要付的 PCIe 往返；用户主动调到该档位以上，
/// 才说明显存确实吃紧、需要这个额外手段。
const int seedvr2SwapIoComponentsThreshold = 24;
