import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/anlas_calculator.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/inpaint_mask_utils.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/metadata/metadata_import_options.dart';
import '../../data/services/image_metadata_service.dart';
import '../providers/generation/image_workflow_controller.dart';
import '../providers/image_generation_provider.dart';
import '../providers/krita/krita_bridge_notifier.dart';
import '../providers/quality_preset_provider.dart';
import '../providers/subscription_provider.dart';
import '../screens/director_tools/director_tools_screen.dart';
import '../utils/metadata_import_applier.dart';
import '../utils/prompt_preset_import_utils.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/image_editor/image_editor_screen.dart';

typedef _ImageWorkflowRead = T Function<T>(ProviderListenable<T> provider);

class ImageWorkflowLauncher {
  const ImageWorkflowLauncher._();

  static void openImageToImage(WidgetRef ref, Uint8List imageBytes) {
    final workflowNotifier = ref.read(imageWorkflowControllerProvider.notifier);
    workflowNotifier.replaceSourceImage(imageBytes);
    workflowNotifier.enterBaseMode(clearMask: true);
    workflowNotifier.setPanelExpanded(true);
  }

  static Future<void> openEditor(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes, {
    required ImageEditorMode mode,
  }) async {
    await _openEditor(context, ref.read, imageBytes, mode: mode);
  }

  static Future<bool> openEditorFromRef(
    BuildContext context,
    Ref ref,
    Uint8List imageBytes, {
    required ImageEditorMode mode,
    bool Function()? isCurrent,
  }) => _openEditor(
    context,
    ref.read,
    imageBytes,
    mode: mode,
    isCurrent: isCurrent,
  );

  static Future<bool> _openEditor(
    BuildContext context,
    _ImageWorkflowRead read,
    Uint8List imageBytes, {
    required ImageEditorMode mode,
    bool Function()? isCurrent,
  }) async {
    final workflowNotifier = read(imageWorkflowControllerProvider.notifier);
    final workflow = read(imageWorkflowControllerProvider);

    if (mode == ImageEditorMode.edit) {
      workflowNotifier.enterBaseMode(clearMask: true);
    } else if (read(imageWorkflowControllerProvider).isEnhance) {
      workflowNotifier.enterBaseMode(clearMask: false);
    }

    final params = read(generationParamsNotifierProvider);
    final result = await ImageEditorScreen.show(
      context,
      initialImage: imageBytes,
      existingMask: mode == ImageEditorMode.inpaint ? params.maskImage : null,
      existingFocusRect: mode == ImageEditorMode.inpaint
          ? workflow.focusedSelectionRect
          : null,
      initialMinimumContextMegaPixels: mode == ImageEditorMode.inpaint
          ? workflow.minimumContextMegaPixels
          : 88.0,
      initialFocusedInpaintEnabled: mode == ImageEditorMode.inpaint
          ? workflow.focusedInpaintEnabled
          : false,
      focusedInpaintCostConfig: mode == ImageEditorMode.inpaint
          ? ImageEditorFocusedInpaintCostConfig(
              model: params.model,
              steps: params.steps,
              batchCount: params.nSamples,
              batchSize: read(imagesPerRequestProvider),
              smea: params.effectiveSmea,
              smeaDyn: params.effectiveSmeaDyn,
              strength: params.inpaintStrength,
              subscriptionTier:
                  read(subscriptionNotifierProvider).subscription?.isOpus ==
                      true
                  ? AnlasCalculator.opusTier
                  : 0,
              opusQuotaExhausted:
                  read(
                    subscriptionNotifierProvider,
                  ).subscription?.usage?.isNegative ??
                  false,
              extraPerSampleCost:
                  AnlasCalculator.resolvePreciseReferenceExtraCost(params),
            )
          : null,
      showMaskExport: mode == ImageEditorMode.inpaint,
      mode: mode,
      title: mode == ImageEditorMode.edit
          ? context.l10n.img2img_editImage
          : context.l10n.img2img_inpaint,
    );

    if (result == null ||
        !context.mounted ||
        (isCurrent != null && !isCurrent())) {
      return false;
    }

    AppLogger.d(
      'Editor returned: mode=$mode, hasImageChanges=${result.hasImageChanges}, '
          'hasMaskChanges=${result.hasMaskChanges}, '
          'modifiedBytes=${result.modifiedImage?.length ?? 0}, '
          'maskBytes=${result.maskImage?.length ?? 0}, '
          'hasOutpaintChanges=${result.hasOutpaintChanges}, '
          'outpaintSourceBytes=${result.outpaintSourceImage?.length ?? 0}, '
          'outpaintSourceWidth=${result.outpaintSourceWidth}, '
          'outpaintSourceHeight=${result.outpaintSourceHeight}, '
          'inpaintSourceBytes=${result.inpaintSourceImage?.length ?? 0}, '
          'inpaintSourceWidth=${result.inpaintSourceWidth}, '
          'inpaintSourceHeight=${result.inpaintSourceHeight}, '
          'sourceWasNormalized=${result.sourceWasNormalized}, '
          'outputWidth=${result.outputWidth}, '
          'outputHeight=${result.outputHeight}, '
          'compressionApplied=${result.compressionApplied}, '
          'focusRect=${result.focusAreaRect}, '
          'minContext=${result.minimumContextMegaPixels.toStringAsFixed(2)}, '
          'focusedEnabled=${result.focusedInpaintEnabled}',
      'ImageWorkflow',
    );

    if (mode == ImageEditorMode.edit) {
      if (result.hasImageChanges && result.modifiedImage != null) {
        workflowNotifier.replaceSourceImage(
          result.modifiedImage!,
          sourceWidth: result.outputWidth,
          sourceHeight: result.outputHeight,
          autoAdapt: !result.compressionApplied,
        );
        workflowNotifier.setPanelExpanded(true);
        AppToast.success(context, context.l10n.img2img_editApplied);
        return true;
      }
      return false;
    }

    final effectiveMask =
        result.maskImage != null &&
            InpaintMaskUtils.hasMaskedPixels(result.maskImage!)
        ? result.maskImage
        : null;
    workflowNotifier.applyInpaintEditorResult(
      sourceImage: result.hasOutpaintChanges
          ? result.outpaintSourceImage
          : result.inpaintSourceImage,
      sourceWidth: result.hasOutpaintChanges
          ? result.outpaintSourceWidth
          : result.inpaintSourceWidth,
      sourceHeight: result.hasOutpaintChanges
          ? result.outpaintSourceHeight
          : result.inpaintSourceHeight,
      maskImage: effectiveMask,
      focusedInpaintEnabled: result.focusedInpaintEnabled,
      focusedSelectionRect: result.focusAreaRect,
      minimumContextMegaPixels: result.minimumContextMegaPixels,
      forceDisableFocusedInpaint: result.hasOutpaintChanges,
      sourceIsOutpaint: result.hasOutpaintChanges,
      useExactSourceDimensions: result.compressionApplied,
    );
    if (effectiveMask != null) {
      AppToast.success(context, context.l10n.img2img_inpaintMaskReady);
    } else if (result.maskImage != null) {
      AppToast.warning(context, context.l10n.toast_noValidMaskIgnored);
    }
    return true;
  }

  static void openEnhance(WidgetRef ref, Uint8List imageBytes) =>
      _openEnhance(ref.read, imageBytes);

  static void openEnhanceFromRef(Ref ref, Uint8List imageBytes) =>
      _openEnhance(ref.read, imageBytes);

  static void _openEnhance(_ImageWorkflowRead read, Uint8List imageBytes) {
    final workflowNotifier = read(imageWorkflowControllerProvider.notifier);
    workflowNotifier.replaceSourceImage(imageBytes);
    workflowNotifier.enterEnhanceMode();
    workflowNotifier.setPanelExpanded(true);
  }

  static Future<void> openInpaint(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
  ) async {
    final workflowNotifier = ref.read(imageWorkflowControllerProvider.notifier);
    workflowNotifier.replaceSourceImage(imageBytes);
    workflowNotifier.setPanelExpanded(true);
    await openEditor(context, ref, imageBytes, mode: ImageEditorMode.inpaint);
  }

  /// 打开图生图「超分」子面板（内嵌，非弹窗）
  static void openUpscale(WidgetRef ref, Uint8List imageBytes) =>
      _openUpscale(ref.read, imageBytes);

  static void openUpscaleFromRef(Ref ref, Uint8List imageBytes) =>
      _openUpscale(ref.read, imageBytes);

  static void _openUpscale(_ImageWorkflowRead read, Uint8List imageBytes) {
    final workflowNotifier = read(imageWorkflowControllerProvider.notifier);
    workflowNotifier.replaceSourceImage(imageBytes);
    workflowNotifier.enterUpscaleMode();
    workflowNotifier.setPanelExpanded(true);
  }

  static Future<void> openDirectorTools(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
  ) async {
    await _openDirectorTools(context, ref.read, imageBytes);
  }

  static Future<bool> openDirectorToolsFromRef(
    BuildContext context,
    Ref ref,
    Uint8List imageBytes, {
    bool Function()? isCurrent,
  }) => _openDirectorTools(context, ref.read, imageBytes, isCurrent: isCurrent);

  static Future<bool> _openDirectorTools(
    BuildContext context,
    _ImageWorkflowRead read,
    Uint8List imageBytes, {
    bool Function()? isCurrent,
  }) async {
    final result = await DirectorToolsScreen.show(
      context,
      sourceImage: imageBytes,
    );
    if (result != null &&
        context.mounted &&
        (isCurrent == null || isCurrent())) {
      final workflowNotifier = read(imageWorkflowControllerProvider.notifier);
      workflowNotifier.replaceSourceImage(result);
      workflowNotifier.setPanelExpanded(true);
      AppToast.success(context, context.l10n.img2img_directorApplied);
      return true;
    }
    return false;
  }

  /// Prepares variation source and settings without starting generation.
  static Future<void> prepareVariations(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
  ) => _prepareVariations(context, ref.read, imageBytes);

  static Future<void> prepareVariationsFromRef(
    BuildContext context,
    Ref ref,
    Uint8List imageBytes, {
    bool Function()? isCurrent,
  }) => _prepareVariations(context, ref.read, imageBytes, isCurrent: isCurrent);

  static Future<void> _prepareVariations(
    BuildContext context,
    _ImageWorkflowRead read,
    Uint8List imageBytes, {
    bool Function()? isCurrent,
  }) async {
    final workflowNotifier = read(imageWorkflowControllerProvider.notifier);
    final paramsNotifier = read(generationParamsNotifierProvider.notifier);
    void prepareSource() {
      workflowNotifier.replaceSourceImage(imageBytes);
      workflowNotifier.enterBaseMode(clearMask: true);
      workflowNotifier.setPanelExpanded(true);
    }

    // Existing UI callers expect the source panel to update immediately. Agent
    // callers defer every mutation until the stable resource is still current.
    if (isCurrent == null) prepareSource();
    final metadata = await ImageMetadataService().getMetadataFromBytes(
      imageBytes,
    );
    if (!context.mounted || (isCurrent != null && !isCurrent())) return;
    if (isCurrent != null) prepareSource();

    if (metadata != null && metadata.hasData) {
      _applyVariationMetadata(
        metadata,
        read,
        paramsNotifier,
        fallbackModel: read(generationParamsNotifierProvider).model,
      );
    } else {
      paramsNotifier.randomizeSeed();
      paramsNotifier.updateStrength(0.45);
      paramsNotifier.updateNoise(0.0);
    }
  }

  static Future<void> generateVariations(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
  ) async {
    await prepareVariations(context, ref, imageBytes);
    if (!context.mounted) return;
    if (PlatformCapabilities.current.supportsKritaBridge &&
        ref.read(kritaBridgeNotifierProvider).isBridgeGenerating) {
      AppToast.warning(context, context.l10n.toast_kritaBusy);
      return;
    }
    final cooldownState = ref.read(generationCooldownProvider);
    if (cooldownState.isActive) {
      AppToast.info(
        context,
        context.l10n.generation_cooldownRemaining(
          cooldownState.remainingSeconds,
        ),
      );
      return;
    }
    AppToast.info(context, context.l10n.img2img_variationsStarted);

    final currentParams = ref.read(generationParamsNotifierProvider);
    ref.read(imageGenerationNotifierProvider.notifier).generate(currentParams);
  }

  static void _applyVariationMetadata(
    NaiImageMetadata metadata,
    _ImageWorkflowRead read,
    GenerationParamsNotifier notifier, {
    required String fallbackModel,
  }) {
    MetadataImportApplier.applyPromptAndGenerationParams(
      metadata: metadata,
      options: MetadataImportOptions.all(),
      currentModel: fallbackModel,
      target: MetadataImportTarget(
        updatePrompt: notifier.updatePrompt,
        updateNegativePrompt: notifier.updateNegativePrompt,
        updateSeed: notifier.updateSeed,
        updateSteps: notifier.updateSteps,
        updateScale: notifier.updateScale,
        updateSize: notifier.updateSize,
        updateSampler: notifier.updateSampler,
        // 导入要还原图片自带的参数，模型切换不能再套用新模型的默认值
        updateModel: (value) =>
            notifier.updateModel(value, followDefaults: false),
        updateSmea: notifier.updateSmea,
        updateSmeaDyn: notifier.updateSmeaDyn,
        updateVarietyPlus: notifier.updateVarietyPlus,
        updateNoiseSchedule: notifier.updateNoiseSchedule,
        updateCfgRescale: notifier.updateCfgRescale,
        updateQualityToggle: (value) {
          notifier.updateQualityToggle(value);
          applyImportedQualityToggle(read, value);
        },
        updateQualityTier: (value) {
          read(qualityPresetNotifierProvider.notifier).setNaiTier(value);
        },
        updateUcPreset: (value) {
          notifier.updateUcPreset(value);
          applyImportedUcPreset(read, value);
        },
        updateTransparentBackground: notifier.updateTransparentBackground,
      ),
    );

    notifier.randomizeSeed();
    notifier.updateStrength(metadata.strength ?? 0.45);
    notifier.updateNoise(metadata.noise ?? 0.0);
  }
}
