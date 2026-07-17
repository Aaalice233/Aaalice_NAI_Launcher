import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/inpaint_mask_utils.dart';
import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/metadata/metadata_import_options.dart';
import '../../data/services/image_metadata_service.dart';
import '../providers/generation/image_workflow_controller.dart';
import '../providers/image_generation_provider.dart';
import '../providers/krita/krita_bridge_notifier.dart';
import '../providers/subscription_provider.dart';
import '../screens/director_tools/director_tools_screen.dart';
import '../utils/metadata_import_applier.dart';
import '../utils/prompt_preset_import_utils.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/image_editor/image_editor_screen.dart';

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
    final workflowNotifier = ref.read(imageWorkflowControllerProvider.notifier);
    final workflow = ref.read(imageWorkflowControllerProvider);

    if (mode == ImageEditorMode.edit) {
      workflowNotifier.enterBaseMode(clearMask: true);
    } else if (ref.read(imageWorkflowControllerProvider).isEnhance) {
      workflowNotifier.enterBaseMode(clearMask: false);
    }

    final params = ref.read(generationParamsNotifierProvider);
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
              batchSize: ref.read(imagesPerRequestProvider),
              smea: params.smea,
              smeaDyn: params.smeaDyn,
              subscriptionTier:
                  ref.read(subscriptionNotifierProvider).subscription?.tier ??
                  0,
              extraPerSampleCost: _resolvePreciseReferenceExtraCost(params),
            )
          : null,
      showMaskExport: mode == ImageEditorMode.inpaint,
      mode: mode,
      title: mode == ImageEditorMode.edit
          ? context.l10n.img2img_editImage
          : context.l10n.img2img_inpaint,
    );

    if (result == null || !context.mounted) {
      return;
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
      }
      return;
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
  }

  static void openEnhance(WidgetRef ref, Uint8List imageBytes) {
    final workflowNotifier = ref.read(imageWorkflowControllerProvider.notifier);
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
  static void openUpscale(WidgetRef ref, Uint8List imageBytes) {
    final workflowNotifier = ref.read(imageWorkflowControllerProvider.notifier);
    workflowNotifier.replaceSourceImage(imageBytes);
    workflowNotifier.enterUpscaleMode();
    workflowNotifier.setPanelExpanded(true);
  }

  static Future<void> openDirectorTools(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
  ) async {
    final result = await DirectorToolsScreen.show(
      context,
      sourceImage: imageBytes,
    );
    if (result != null && context.mounted) {
      final workflowNotifier = ref.read(
        imageWorkflowControllerProvider.notifier,
      );
      workflowNotifier.replaceSourceImage(result);
      workflowNotifier.setPanelExpanded(true);
      AppToast.success(context, context.l10n.img2img_directorApplied);
    }
  }

  static Future<void> generateVariations(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
  ) async {
    final workflowNotifier = ref.read(imageWorkflowControllerProvider.notifier);
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);

    workflowNotifier.replaceSourceImage(imageBytes);
    workflowNotifier.enterBaseMode(clearMask: true);
    workflowNotifier.setPanelExpanded(true);

    final metadata = await ImageMetadataService().getMetadataFromBytes(
      imageBytes,
    );
    if (!context.mounted) {
      return;
    }

    if (metadata != null && metadata.hasData) {
      _applyVariationMetadata(
        metadata,
        ref,
        paramsNotifier,
        fallbackModel: ref.read(generationParamsNotifierProvider).model,
      );
    } else {
      paramsNotifier.randomizeSeed();
      paramsNotifier.updateStrength(0.45);
      paramsNotifier.updateNoise(0.0);
    }

    if (!context.mounted) return;
    if (ref.read(kritaBridgeNotifierProvider).isBridgeGenerating) {
      AppToast.warning(context, context.l10n.toast_kritaBusy);
      return;
    }
    AppToast.info(context, context.l10n.img2img_variationsStarted);

    final currentParams = ref.read(generationParamsNotifierProvider);
    ref.read(imageGenerationNotifierProvider.notifier).generate(currentParams);
  }

  static int _resolvePreciseReferenceExtraCost(ImageParams params) {
    if (!params.model.contains('diffusion-4-5')) {
      return 0;
    }
    return params.preciseReferenceCount * 5;
  }

  static void _applyVariationMetadata(
    NaiImageMetadata metadata,
    WidgetRef ref,
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
        updateModel: notifier.updateModel,
        updateSmea: notifier.updateSmea,
        updateSmeaDyn: notifier.updateSmeaDyn,
        updateVarietyPlus: notifier.updateVarietyPlus,
        updateNoiseSchedule: notifier.updateNoiseSchedule,
        updateCfgRescale: notifier.updateCfgRescale,
        updateQualityToggle: (value) {
          notifier.updateQualityToggle(value);
          applyImportedQualityToggle(ref.read, value);
        },
        updateUcPreset: (value) {
          notifier.updateUcPreset(value);
          applyImportedUcPreset(ref.read, value);
        },
      ),
    );

    notifier.randomizeSeed();
    notifier.updateStrength(metadata.strength ?? 0.45);
    notifier.updateNoise(metadata.noise ?? 0.0);
  }
}
