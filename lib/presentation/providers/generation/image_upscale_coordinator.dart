import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/comfyui/seedvr2_support.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import '../comfyui/comfyui_provider.dart';
import '../image_generation_provider.dart';
import '../image_save_settings_provider.dart';
import 'image_workflow_controller.dart';
import 'novel_ai_upscale_task_provider.dart';

final imageUpscaleCoordinatorProvider = Provider(ImageUpscaleCoordinator.new);

enum ImageUpscaleKind {
  novelAi,
  regular,
  seedVr2Native,
  seedVr2Legacy,
  seedVr2Tiled,
  rtx;

  bool get isSeedVr2 =>
      this == seedVr2Native || this == seedVr2Legacy || this == seedVr2Tiled;
}

enum ImageUpscaleFailure {
  sourceMissing,
  engineUnavailable,
  regularModelUnavailable,
  seedVr2ModelUnavailable,
  nativeVaeUnavailable,
  sourceDecodeFailed,
  noResult,

  /// 同一后端已有放大在进行。
  busy,
  authenticationRequired,

  /// 请求已发出但失败，detail 携带服务端或连接错误。
  requestFailed,
}

sealed class ImageUpscaleResult {
  const ImageUpscaleResult();
}

final class ImageUpscaleSuccess extends ImageUpscaleResult {
  const ImageUpscaleSuccess({required this.kind, this.width, this.height});
  final ImageUpscaleKind kind;
  final int? width;
  final int? height;
}

final class ImageUpscaleRejected extends ImageUpscaleResult {
  const ImageUpscaleRejected(this.reason, {this.detail});
  final ImageUpscaleFailure reason;
  final String? detail;
}

/// 一次放大的输入：原图与这次使用的后端设置。
final class ImageUpscaleRequest {
  const ImageUpscaleRequest({required this.source, required this.settings});
  final Uint8List source;
  final UpscaleWorkflowSettings settings;
}

/// 后端产出的放大结果，由调用方决定如何登记。
final class ImageUpscaleOutput {
  const ImageUpscaleOutput({
    required this.bytes,
    required this.kind,
    this.width,
    this.height,
  });
  final Uint8List bytes;
  final ImageUpscaleKind kind;
  final int? width;
  final int? height;
}

typedef ImageUpscaleAdopter = Future<void> Function(ImageUpscaleOutput output);

/// Executes every upscale backend and returns a typed presentation result.
/// Provider values are snapshotted when a run starts; no Widget State is read.
base class ImageUpscaleCoordinator {
  ImageUpscaleCoordinator(this.ref);

  static const _logTag = 'Img2Img-Upscale';
  final Ref ref;

  /// 生成页入口：放大页面里的源图，并按页面参数与自动保存设置登记结果。
  Future<ImageUpscaleResult> runFromGenerationPage() async {
    final params = ref.read(generationParamsNotifierProvider);
    final source = params.sourceImage;
    if (source == null) {
      AppLogger.w('Start requested but source image is missing', _logTag);
      return const ImageUpscaleRejected(ImageUpscaleFailure.sourceMissing);
    }
    final settings = ref.read(imageWorkflowControllerProvider).upscale;
    AppLogger.i('Start requested: ${_sourceSummary(params, source)}', _logTag);
    return execute(
      ImageUpscaleRequest(source: source, settings: settings),
      adopt: (output) =>
          _adoptOnGenerationPage(output, params, source, settings),
    );
  }

  Future<ImageUpscaleResult> execute(
    ImageUpscaleRequest request, {
    required ImageUpscaleAdopter adopt,
  }) async {
    // 两个 ComfyUI provider 是 autoDispose，生成页未挂载时得自己订阅住整次执行。
    final keepAlive = [
      ref.listen(comfyUITaskProvider, (_, _) {}),
      ref.listen(comfyUISeedvr2ModelsProvider, (_, _) {}),
    ];
    try {
      final settings = request.settings;
      AppLogger.i('Execute: ${_settingsSummary(settings)}', _logTag);
      if (settings.backend == UpscaleBackend.novelai) {
        return await _runNovelAi(request.source, adopt);
      }
      return await switch (settings.comfyModule) {
        ComfyUpscaleModule.regular => _runRegular(request, adopt),
        ComfyUpscaleModule.seedvr2 => _runSeedVr2(request, adopt),
        ComfyUpscaleModule.rtx => _runRtx(request, adopt),
      };
    } finally {
      for (final subscription in keepAlive) {
        subscription.close();
      }
    }
  }

  Future<ImageUpscaleResult> _runNovelAi(
    Uint8List source,
    ImageUpscaleAdopter adopt,
  ) async {
    int? width;
    int? height;
    final outcome = await ref
        .read(novelAiUpscaleTaskProvider.notifier)
        .execute(
          sourceImage: source,
          adopt: (bytes) {
            final size = NaiResolutionAdapter.readImageSize(bytes);
            width = size?.$1;
            height = size?.$2;
            return adopt(
              ImageUpscaleOutput(
                bytes: bytes,
                kind: ImageUpscaleKind.novelAi,
                width: width,
                height: height,
              ),
            );
          },
        );
    return switch (outcome) {
      NovelAiUpscaleCompleted() => ImageUpscaleSuccess(
        kind: ImageUpscaleKind.novelAi,
        width: width,
        height: height,
      ),
      NovelAiUpscaleSkipped(reason: NovelAiUpscaleSkipReason.busy) =>
        const ImageUpscaleRejected(ImageUpscaleFailure.busy),
      NovelAiUpscaleSkipped(reason: NovelAiUpscaleSkipReason.unauthenticated) =>
        const ImageUpscaleRejected(ImageUpscaleFailure.authenticationRequired),
      NovelAiUpscaleFailed(:final message) => ImageUpscaleRejected(
        ImageUpscaleFailure.requestFailed,
        detail: message,
      ),
    };
  }

  Future<ImageUpscaleResult> _runSeedVr2(
    ImageUpscaleRequest request,
    ImageUpscaleAdopter adopt,
  ) async {
    final settings = request.settings;
    final source = request.source;
    final models = ref.read(comfyUISeedvr2ModelsProvider.notifier);
    final capabilities = models.capabilities;
    final backend = capabilities.resolveBackend(settings.seedvr2Engine);
    if (backend == null) {
      return const ImageUpscaleRejected(ImageUpscaleFailure.engineUnavailable);
    }
    final available = capabilities.modelsForBackend(backend);
    final model = available.isEmpty
        ? null
        : selectPreferredUpscaleModel(
            available,
            currentModel: settings.comfySeedvr2ModelForBackend(backend),
          );
    if (model == null) {
      return const ImageUpscaleRejected(
        ImageUpscaleFailure.seedVr2ModelUnavailable,
      );
    }
    final sourceSize = NaiResolutionAdapter.readImageSize(source);
    if (sourceSize == null) {
      return const ImageUpscaleRejected(ImageUpscaleFailure.sourceDecodeFailed);
    }
    final (sourceWidth, sourceHeight) = sourceSize;

    late final String templateId;
    late final Map<String, dynamic> values;
    late final ImageUpscaleKind kind;
    if (backend == ComfySeedvr2Backend.native) {
      final vae = capabilities.preferredNativeVae;
      if (vae == null) {
        return const ImageUpscaleRejected(
          ImageUpscaleFailure.nativeVaeUnavailable,
        );
      }
      kind = ImageUpscaleKind.seedVr2Native;
      templateId = comfySeedvr2NativeUpscaleTemplateId;
      values = {
        'scale': settings.comfyScale,
        'dit_model': model,
        'vae_model': vae,
        'vae_encode_tile_size': settings.seedvr2VaeTileSize,
        'vae_decode_tile_size': settings.seedvr2VaeTileSize,
        'seed': -1,
      };
    } else {
      final tiled = settings.seedvr2Tiled && capabilities.legacyTilingAvailable;
      kind = tiled
          ? ImageUpscaleKind.seedVr2Tiled
          : ImageUpscaleKind.seedVr2Legacy;
      final resolution = tiled
          ? calculateComfySeedvr2TiledTargetResolution(
              sourceWidth: sourceWidth,
              sourceHeight: sourceHeight,
              scale: settings.comfyScale,
            )
          : calculateComfySeedvr2TargetResolution(
              sourceWidth: sourceWidth,
              sourceHeight: sourceHeight,
              scale: settings.comfyScale,
            );
      templateId = tiled
          ? comfySeedvr2LegacyTiledUpscaleTemplateId
          : comfySeedvr2LegacyUpscaleTemplateId;
      values = {
        'target_resolution': resolution,
        'dit_model': model,
        'vae_encode_tile_size': settings.seedvr2VaeTileSize,
        'vae_decode_tile_size': settings.seedvr2VaeTileSize,
        'blocks_to_swap': settings.seedvr2BlocksToSwap,
        'swap_io_components': resolveSeedvr2SwapIoComponents(
          settings.seedvr2BlocksToSwap,
        ),
        if (tiled) ...{
          'tile_size': settings.seedvr2TileSize,
          'tile_upscale_resolution': math.max(
            64,
            math.min(
              8192,
              (settings.seedvr2TileSize * settings.comfyScale).round(),
            ),
          ),
        },
        'seed': -1,
      };
    }
    final results = await _execute(templateId, source, values);
    if (results == null || results.isEmpty) return _comfyNoResult();
    final bytes = results.last;
    final outputSize = NaiResolutionAdapter.readImageSize(bytes);
    final width = outputSize?.$1 ?? (sourceWidth * settings.comfyScale).round();
    final height =
        outputSize?.$2 ?? (sourceHeight * settings.comfyScale).round();
    await adopt(
      ImageUpscaleOutput(
        bytes: bytes,
        kind: kind,
        width: width,
        height: height,
      ),
    );
    return ImageUpscaleSuccess(kind: kind, width: width, height: height);
  }

  Future<ImageUpscaleResult> _runRegular(
    ImageUpscaleRequest request,
    ImageUpscaleAdopter adopt,
  ) async {
    final settings = request.settings;
    final source = request.source;
    final model = resolveComfyUpscaleModelForModule(
      ref.read(comfyUISeedvr2ModelsProvider),
      module: ComfyUpscaleModule.regular,
      currentModel: settings.comfyModel,
    );
    if (model == null) {
      return const ImageUpscaleRejected(
        ImageUpscaleFailure.regularModelUnavailable,
      );
    }
    final sourceSize = NaiResolutionAdapter.readImageSize(source);
    if (sourceSize == null) {
      return const ImageUpscaleRejected(ImageUpscaleFailure.sourceDecodeFailed);
    }
    final width = math.max(1, (sourceSize.$1 * settings.comfyScale).round());
    final height = math.max(1, (sourceSize.$2 * settings.comfyScale).round());
    final results = await _execute(comfyModelUpscaleTemplateId, source, {
      'upscale_model': model,
      'target_width': width,
      'target_height': height,
    });
    if (results == null || results.isEmpty) return _comfyNoResult();
    final bytes = results.last;
    final outputSize = NaiResolutionAdapter.readImageSize(bytes);
    final outputWidth = outputSize?.$1 ?? width;
    final outputHeight = outputSize?.$2 ?? height;
    await adopt(
      ImageUpscaleOutput(
        bytes: bytes,
        kind: ImageUpscaleKind.regular,
        width: outputWidth,
        height: outputHeight,
      ),
    );
    return ImageUpscaleSuccess(
      kind: ImageUpscaleKind.regular,
      width: outputWidth,
      height: outputHeight,
    );
  }

  Future<ImageUpscaleResult> _runRtx(
    ImageUpscaleRequest request,
    ImageUpscaleAdopter adopt,
  ) async {
    final source = request.source;
    final sourceSize = NaiResolutionAdapter.readImageSize(source);
    if (sourceSize == null) {
      return const ImageUpscaleRejected(ImageUpscaleFailure.sourceDecodeFailed);
    }
    final scale = request.settings.comfyScale;
    final results = await _execute(comfyRtxUpscaleTemplateId, source, {
      'rtx_scale': scale,
    });
    if (results == null || results.isEmpty) return _comfyNoResult();
    final bytes = results.last;
    final outputSize = NaiResolutionAdapter.readImageSize(bytes);
    final width =
        outputSize?.$1 ??
        math.max(8, ((sourceSize.$1 * scale) / 8).round() * 8);
    final height =
        outputSize?.$2 ??
        math.max(8, ((sourceSize.$2 * scale) / 8).round() * 8);
    await adopt(
      ImageUpscaleOutput(
        bytes: bytes,
        kind: ImageUpscaleKind.rtx,
        width: width,
        height: height,
      ),
    );
    return ImageUpscaleSuccess(
      kind: ImageUpscaleKind.rtx,
      width: width,
      height: height,
    );
  }

  Future<List<Uint8List>?> _execute(
    String templateId,
    Uint8List source,
    Map<String, dynamic> values,
  ) async {
    AppLogger.i('Execute upscale template=$templateId', _logTag);
    return ref
        .read(comfyUITaskProvider.notifier)
        .execute(
          templateId: templateId,
          inputImages: {'input_image': source},
          paramValues: values,
        );
  }

  /// 任务失败时错误码留在任务状态里，生成页靠它显示；这里一并带给其他调用方。
  ImageUpscaleRejected _comfyNoResult() {
    final task = ref.read(comfyUITaskProvider);
    final code = task.errorCode;
    return ImageUpscaleRejected(
      ImageUpscaleFailure.noResult,
      detail: code == null
          ? null
          : [code.name, task.errorDetails].whereType<String>().join(': '),
    );
  }

  Future<void> _adoptOnGenerationPage(
    ImageUpscaleOutput output,
    ImageParams params,
    Uint8List source,
    UpscaleWorkflowSettings settings,
  ) async {
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    // Persisting before startup restore completes would evict older records.
    await generation.ensureGenerationHistoryRestored();
    final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
    await generation.registerExternalImage(
      output.bytes,
      params: params,
      width: output.width,
      height: output.height,
      comparisonSourceImage: source,
      saveToLocal: saveSettings.autoSave,
      replaceCurrentDisplay: true,
      embedNaiMetadata: output.kind.isSeedVr2
          ? settings.seedvr2EmbedNaiMetadata
          : true,
    );
  }

  static String _sourceSummary(ImageParams params, Uint8List source) =>
      'sourceBytes=${source.length}, paramsSize=${params.width}x${params.height}, action=${params.action.name}, model=${params.model}';

  static String _settingsSummary(UpscaleWorkflowSettings upscale) =>
      'backend=${upscale.backend.name}, module=${upscale.comfyModule.name}, scale=${upscale.comfyScale}, comfyModel=${upscale.comfyModel}';
}
