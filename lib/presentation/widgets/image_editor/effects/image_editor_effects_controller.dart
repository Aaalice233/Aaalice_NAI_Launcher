import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import '../image_editor_controller.dart';
import '../layers/layer.dart';
import 'editor_effects.dart';
import 'effects_preview_dialog.dart';

class ImageEditorEffectsController {
  const ImageEditorEffectsController({
    required this.session,
    required this.editorState,
  });

  final ImageEditorController session;
  final EditorState editorState;

  @visibleForTesting
  Layer? get activeLayerForApply {
    final layer = editorState.layerManager.activeLayer;
    return layer == null || layer.locked || !layer.hasContent ? null : layer;
  }

  Future<void> showDialog(
    BuildContext context, {
    required VoidCallback onChanged,
  }) async {
    final layer = activeLayerForApply;
    if (layer == null) {
      AppToast.warning(
        context,
        context.l10n.editor_selectUnlockedLayerWithContent,
      );
      return;
    }
    final sourceBytes = await _readLayerPng(layer);
    if (!context.mounted) return;
    if (sourceBytes == null) {
      AppToast.error(context, context.l10n.editor_readCurrentLayerFailed);
      return;
    }
    final selection = await EffectsPreviewDialog.show(
      context,
      sourceBytes: sourceBytes,
      cropRect: _selectionCropRect(),
      processingService: session.processingService,
    );
    if (selection == null || !context.mounted) return;
    await _apply(context, selection, onChanged);
  }

  Future<void> _apply(
    BuildContext context,
    EditorEffectSelection selection,
    VoidCallback onChanged,
  ) async {
    final layer = activeLayerForApply;
    if (layer == null) {
      AppToast.warning(
        context,
        context.l10n.editor_selectUnlockedLayerWithContent,
      );
      return;
    }
    final epoch = session.beginOperation();
    try {
      final sourceBytes = await _readLayerPng(layer);
      if (!context.mounted || !session.accepts(epoch)) return;
      if (sourceBytes == null) {
        AppToast.error(context, context.l10n.editor_readCurrentLayerFailed);
        return;
      }
      final result = await session.processingService.applyEffect(
        EditorEffectJob(
          imageBytes: sourceBytes,
          effectType: selection.type,
          intensity: selection.intensity,
          cropRect: _selectionCropRect(),
        ),
      );
      if (!context.mounted || !session.accepts(epoch)) return;
      final image = await session.processingService.decode(result.bytes);
      if (!context.mounted || !session.accepts(epoch)) {
        image.dispose();
        return;
      }
      editorState.historyManager.execute(
        ReplaceLayerImageAction(
          layerId: layer.id,
          newImageBytes: result.bytes,
          newImage: image,
          actionDescription: effectLabel(context, selection.type),
        ),
        editorState,
      );
      editorState.layerManager.invalidateSnapshot();
      onChanged();
      AppToast.success(
        context,
        context.l10n.editor_effectApplied(effectLabel(context, selection.type)),
      );
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.editor_applyEffectFailed(error));
      }
    }
  }

  Future<Uint8List?> _readLayerPng(Layer layer) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    layer.render(canvas, editorState.canvasSize);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(
        editorState.canvasSize.width.toInt(),
        editorState.canvasSize.height.toInt(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  EditorEffectCropRect? _selectionCropRect() {
    final selection = editorState.selectionPath;
    if (selection == null) return null;
    final bounds = selection.getBounds().intersect(
      Offset.zero & editorState.canvasSize,
    );
    if (bounds.isEmpty) return null;
    final x = bounds.left.floor().clamp(0, editorState.canvasSize.width - 1);
    final y = bounds.top.floor().clamp(0, editorState.canvasSize.height - 1);
    final right = bounds.right.ceil().clamp(
      x + 1,
      editorState.canvasSize.width,
    );
    final bottom = bounds.bottom.ceil().clamp(
      y + 1,
      editorState.canvasSize.height,
    );
    return EditorEffectCropRect(
      x: x.toInt(),
      y: y.toInt(),
      width: (right - x).toInt(),
      height: (bottom - y).toInt(),
    );
  }
}

String effectLabel(
  BuildContext context,
  EditorEffectType type,
) => switch (type) {
  EditorEffectType.brightness => context.l10n.editor_effectBrightness,
  EditorEffectType.contrast => context.l10n.editor_effectContrast,
  EditorEffectType.saturation => context.l10n.editor_effectSaturation,
  EditorEffectType.temperature => context.l10n.editor_effectTemperature,
  EditorEffectType.gamma => context.l10n.editor_effectGamma,
  EditorEffectType.grayscale => context.l10n.editor_effectGrayscale,
  EditorEffectType.invert => context.l10n.editor_effectInvert,
  EditorEffectType.sepia => context.l10n.editor_effectSepia,
  EditorEffectType.denoise => context.l10n.editor_effectDenoise,
  EditorEffectType.blur => context.l10n.editor_effectBlur,
  EditorEffectType.sharpen => context.l10n.editor_effectSharpen,
  EditorEffectType.cropToSelection => context.l10n.editor_effectCropToSelection,
  EditorEffectType.rotateLeft => context.l10n.editor_effectRotateLeft,
  EditorEffectType.rotateRight => context.l10n.editor_effectRotateRight,
  EditorEffectType.flipHorizontal => context.l10n.editor_effectFlipHorizontal,
  EditorEffectType.flipVertical => context.l10n.editor_effectFlipVertical,
};
