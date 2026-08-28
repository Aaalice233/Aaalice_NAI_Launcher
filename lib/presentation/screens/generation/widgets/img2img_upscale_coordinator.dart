import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../../core/comfyui/seedvr2_support.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/comfyui/comfyui_provider.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import '../../../providers/generation/novel_ai_upscale_task_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/image_save_settings_provider.dart';

final img2ImgUpscaleCoordinatorProvider = Provider(
  Img2ImgUpscaleCoordinator.new,
);

enum Img2ImgUpscaleKind {
  novelAi,
  regular,
  seedVr2Native,
  seedVr2Legacy,
  seedVr2Tiled,
  rtx,
}

enum Img2ImgUpscaleFailure {
  sourceMissing,
  engineUnavailable,
  regularModelUnavailable,
  seedVr2ModelUnavailable,
  nativeVaeUnavailable,
  sourceDecodeFailed,
  noResult,
}

sealed class Img2ImgUpscaleResult {
  const Img2ImgUpscaleResult();
}

final class Img2ImgUpscaleSuccess extends Img2ImgUpscaleResult {
  const Img2ImgUpscaleSuccess({required this.kind, this.width, this.height});
  final Img2ImgUpscaleKind kind;
  final int? width;
  final int? height;
}

final class Img2ImgUpscaleRejected extends Img2ImgUpscaleResult {
  const Img2ImgUpscaleRejected(this.reason);
  final Img2ImgUpscaleFailure reason;
}

/// Executes every upscale backend and returns a typed presentation result.
/// Provider values are snapshotted when [run] starts; no Widget State is read.
final class Img2ImgUpscaleCoordinator {
  Img2ImgUpscaleCoordinator(this.ref);

  static const _logTag = 'Img2Img-Upscale';
  final Ref ref;

  Future<Img2ImgUpscaleResult> run() async {
    final params = ref.read(generationParamsNotifierProvider);
    final source = params.sourceImage;
    if (source == null) {
      AppLogger.w('Start requested but source image is missing', _logTag);
      return const Img2ImgUpscaleRejected(Img2ImgUpscaleFailure.sourceMissing);
    }
    final workflow = ref.read(imageWorkflowControllerProvider);
    AppLogger.i(
      'Start requested: ${_sourceSummary(params, source)}; ${_workflowSummary(workflow)}',
      _logTag,
    );
    if (workflow.upscale.backend == UpscaleBackend.novelai) {
      await ref
          .read(novelAiUpscaleTaskProvider.notifier)
          .execute(params: params, sourceImage: source);
      return const Img2ImgUpscaleSuccess(kind: Img2ImgUpscaleKind.novelAi);
    }
    return switch (workflow.upscale.comfyModule) {
      ComfyUpscaleModule.regular => _runRegular(params, source, workflow),
      ComfyUpscaleModule.seedvr2 => _runSeedVr2(params, source, workflow),
      ComfyUpscaleModule.rtx => _runRtx(params, source, workflow),
    };
  }

  Future<Img2ImgUpscaleResult> _runSeedVr2(
    ImageParams params,
    Uint8List source,
    ImageWorkflowState workflow,
  ) async {
    final settings = workflow.upscale;
    final models = ref.read(comfyUISeedvr2ModelsProvider.notifier);
    final capabilities = models.capabilities;
    final backend = capabilities.resolveBackend(settings.seedvr2Engine);
    if (backend == null) {
      return const Img2ImgUpscaleRejected(
        Img2ImgUpscaleFailure.engineUnavailable,
      );
    }
    final available = capabilities.modelsForBackend(backend);
    final model = available.isEmpty
        ? null
        : selectPreferredUpscaleModel(
            available,
            currentModel: settings.comfySeedvr2ModelForBackend(backend),
          );
    if (model == null) {
      return const Img2ImgUpscaleRejected(
        Img2ImgUpscaleFailure.seedVr2ModelUnavailable,
      );
    }
    final decodedSource = img.decodeImage(source);
    if (decodedSource == null) {
      return const Img2ImgUpscaleRejected(
        Img2ImgUpscaleFailure.sourceDecodeFailed,
      );
    }

    late final String templateId;
    late final Map<String, dynamic> values;
    late final Img2ImgUpscaleKind kind;
    if (backend == ComfySeedvr2Backend.native) {
      final vae = capabilities.preferredNativeVae;
      if (vae == null) {
        return const Img2ImgUpscaleRejected(
          Img2ImgUpscaleFailure.nativeVaeUnavailable,
        );
      }
      kind = Img2ImgUpscaleKind.seedVr2Native;
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
          ? Img2ImgUpscaleKind.seedVr2Tiled
          : Img2ImgUpscaleKind.seedVr2Legacy;
      final resolution = tiled
          ? calculateComfySeedvr2TiledTargetResolution(
              sourceWidth: decodedSource.width,
              sourceHeight: decodedSource.height,
              scale: settings.comfyScale,
            )
          : calculateComfySeedvr2TargetResolution(
              sourceWidth: decodedSource.width,
              sourceHeight: decodedSource.height,
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
    if (results == null || results.isEmpty) {
      return const Img2ImgUpscaleRejected(Img2ImgUpscaleFailure.noResult);
    }
    final bytes = results.last;
    final decoded = img.decodeImage(bytes);
    final width =
        decoded?.width ?? (decodedSource.width * settings.comfyScale).round();
    final height =
        decoded?.height ?? (decodedSource.height * settings.comfyScale).round();
    await _register(
      bytes,
      params,
      width,
      height,
      embedNaiMetadata: settings.seedvr2EmbedNaiMetadata,
    );
    return Img2ImgUpscaleSuccess(kind: kind, width: width, height: height);
  }

  Future<Img2ImgUpscaleResult> _runRegular(
    ImageParams params,
    Uint8List source,
    ImageWorkflowState workflow,
  ) async {
    final model = resolveComfyUpscaleModelForModule(
      ref.read(comfyUISeedvr2ModelsProvider),
      module: ComfyUpscaleModule.regular,
      currentModel: workflow.upscale.comfyModel,
    );
    if (model == null) {
      return const Img2ImgUpscaleRejected(
        Img2ImgUpscaleFailure.regularModelUnavailable,
      );
    }
    final decodedSource = img.decodeImage(source);
    if (decodedSource == null) {
      return const Img2ImgUpscaleRejected(
        Img2ImgUpscaleFailure.sourceDecodeFailed,
      );
    }
    final width = math.max(
      1,
      (decodedSource.width * workflow.upscale.comfyScale).round(),
    );
    final height = math.max(
      1,
      (decodedSource.height * workflow.upscale.comfyScale).round(),
    );
    final results = await _execute(comfyModelUpscaleTemplateId, source, {
      'upscale_model': model,
      'target_width': width,
      'target_height': height,
    });
    if (results == null || results.isEmpty) {
      return const Img2ImgUpscaleRejected(Img2ImgUpscaleFailure.noResult);
    }
    final bytes = results.last;
    final decoded = img.decodeImage(bytes);
    final outputWidth = decoded?.width ?? width;
    final outputHeight = decoded?.height ?? height;
    await _register(bytes, params, outputWidth, outputHeight);
    return Img2ImgUpscaleSuccess(
      kind: Img2ImgUpscaleKind.regular,
      width: outputWidth,
      height: outputHeight,
    );
  }

  Future<Img2ImgUpscaleResult> _runRtx(
    ImageParams params,
    Uint8List source,
    ImageWorkflowState workflow,
  ) async {
    final decodedSource = img.decodeImage(source);
    if (decodedSource == null) {
      return const Img2ImgUpscaleRejected(
        Img2ImgUpscaleFailure.sourceDecodeFailed,
      );
    }
    final scale = workflow.upscale.comfyScale;
    final results = await _execute(comfyRtxUpscaleTemplateId, source, {
      'rtx_scale': scale,
    });
    if (results == null || results.isEmpty) {
      return const Img2ImgUpscaleRejected(Img2ImgUpscaleFailure.noResult);
    }
    final bytes = results.last;
    final decoded = img.decodeImage(bytes);
    final width =
        decoded?.width ??
        math.max(8, ((decodedSource.width * scale) / 8).round() * 8);
    final height =
        decoded?.height ??
        math.max(8, ((decodedSource.height * scale) / 8).round() * 8);
    await _register(bytes, params, width, height);
    return Img2ImgUpscaleSuccess(
      kind: Img2ImgUpscaleKind.rtx,
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

  Future<void> _register(
    Uint8List bytes,
    ImageParams params,
    int width,
    int height, {
    bool embedNaiMetadata = false,
  }) async {
    final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
    await ref
        .read(imageGenerationNotifierProvider.notifier)
        .registerExternalImage(
          bytes,
          params: params,
          width: width,
          height: height,
          saveToLocal: saveSettings.autoSave,
          replaceCurrentDisplay: true,
          embedNaiMetadata: embedNaiMetadata,
        );
  }

  static String _sourceSummary(ImageParams params, Uint8List source) =>
      'sourceBytes=${source.length}, paramsSize=${params.width}x${params.height}, action=${params.action.name}, model=${params.model}';

  static String _workflowSummary(ImageWorkflowState workflow) {
    final upscale = workflow.upscale;
    return 'backend=${upscale.backend.name}, module=${upscale.comfyModule.name}, scale=${upscale.comfyScale}, comfyModel=${upscale.comfyModel}';
  }
}
