import 'package:flutter/widgets.dart';

import '../../core/comfyui/workflow_template.dart';
import '../../core/utils/localization_extension.dart';

extension LocalizedWorkflowTemplate on WorkflowTemplate {
  String localizedName(BuildContext context) {
    if (!isBuiltin) return name;
    final l10n = context.l10n;
    return switch (id) {
      'builtin_seedvr2_upscale' => l10n.comfyWorkflow_seedvr2UpscaleName,
      'builtin_seedvr2_tiled_upscale' =>
        l10n.comfyWorkflow_seedvr2TiledUpscaleName,
      'builtin_comfy_model_upscale' => l10n.comfyWorkflow_modelUpscaleName,
      'builtin_rtx_upscale' => l10n.comfyWorkflow_rtxUpscaleName,
      _ => name,
    };
  }

  String localizedDescription(BuildContext context) {
    if (!isBuiltin) return description;
    final l10n = context.l10n;
    return switch (id) {
      'builtin_seedvr2_upscale' => l10n.comfyWorkflow_seedvr2UpscaleDescription,
      'builtin_seedvr2_tiled_upscale' =>
        l10n.comfyWorkflow_seedvr2TiledUpscaleDescription,
      'builtin_comfy_model_upscale' =>
        l10n.comfyWorkflow_modelUpscaleDescription,
      'builtin_rtx_upscale' => l10n.comfyWorkflow_rtxUpscaleDescription,
      _ => description,
    };
  }
}

extension LocalizedWorkflowCategory on WorkflowCategory {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      WorkflowCategory.enhance => l10n.settings_comfyUiCategoryEnhance,
      WorkflowCategory.img2img => l10n.settings_comfyUiCategoryImg2Img,
      WorkflowCategory.inpaint => l10n.settings_comfyUiCategoryInpaint,
      WorkflowCategory.txt2img => l10n.settings_comfyUiCategoryTxt2Img,
      WorkflowCategory.custom => l10n.settings_comfyUiCategoryCustom,
    };
  }
}

extension LocalizedWorkflowSlot on WorkflowSlot {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch ((id, field)) {
      ('input_image', _) => l10n.comfyWorkflowSlot_inputImage,
      ('target_resolution', 'resolution') =>
        l10n.comfyWorkflowSlot_targetShortSide,
      ('target_resolution', 'new_resolution') =>
        l10n.comfyWorkflowSlot_targetLongSide,
      ('dit_model', _) ||
      ('upscale_model', _) => l10n.comfyWorkflowSlot_upscaleModel,
      ('vae_encode_tile_size', _) => l10n.comfyWorkflowSlot_vaeEncodeTileSize,
      ('vae_decode_tile_size', _) => l10n.comfyWorkflowSlot_vaeDecodeTileSize,
      ('blocks_to_swap', _) => l10n.comfyWorkflowSlot_blocksToSwap,
      ('swap_io_components', _) => l10n.comfyWorkflowSlot_swapIoComponents,
      ('seed', _) => l10n.comfyWorkflowSlot_randomSeed,
      ('output_image', _) => l10n.comfyWorkflowSlot_outputImage,
      ('tile_size', 'tile_width') => l10n.comfyWorkflowSlot_tileWidth,
      ('tile_size', 'tile_height') => l10n.comfyWorkflowSlot_tileHeight,
      ('tile_upscale_resolution', _) =>
        l10n.comfyWorkflowSlot_tileUpscaleResolution,
      ('target_width', _) => l10n.comfyWorkflowSlot_targetWidth,
      ('target_height', _) => l10n.comfyWorkflowSlot_targetHeight,
      ('rtx_scale', _) => l10n.comfyWorkflowSlot_scale,
      _ => label,
    };
  }
}
