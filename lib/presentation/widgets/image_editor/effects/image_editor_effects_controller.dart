import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import '../core/transform_geometry.dart';
import '../image_editor_controller.dart';
import '../layers/layer.dart';
import '../layers/layer_patch_baker.dart';
import 'editor_effects.dart';
import 'effects_preview_dialog.dart';

enum InPlaceEffectOutcome { applied, needsSelection, nothingToApply }

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
    final region = editorState.frame;
    final sourceBytes = await _readLayerPng(layer, region);
    if (!context.mounted) return;
    if (sourceBytes == null) {
      AppToast.error(context, context.l10n.editor_readCurrentLayerFailed);
      return;
    }
    final selection = await EffectsPreviewDialog.show(
      context,
      sourceBytes: sourceBytes,
      cropRect: _selectionCropRect(region),
      processingService: session.processingService,
      inPlacePreview: _inPlacePreview,
    );
    if (selection == null || !context.mounted) return;
    await _apply(context, selection, onChanged);
  }

  /// 旋转与翻转对应的变换；其余效果返回 null
  static TransformParams Function(TransformParams)? layerTransformFor(
    EditorEffectType type,
  ) {
    return switch (type) {
      EditorEffectType.rotateLeft => (params) => params.withRotation(
        params.rotation - math.pi / 2,
      ),
      EditorEffectType.rotateRight => (params) => params.withRotation(
        params.rotation + math.pi / 2,
      ),
      EditorEffectType.flipHorizontal => (params) => params.flipped(
        horizontal: true,
      ),
      EditorEffectType.flipVertical => (params) => params.flipped(
        horizontal: false,
      ),
      _ => null,
    };
  }

  /// 原位效果的预览与应用走同一套计算，取景框内看到的就是应用后的结果；
  /// 没有可处理的内容时返回 null
  @visibleForTesting
  Future<Uint8List?> inPlacePreviewFor(
    EditorEffectType type, {
    int maxDimension = 768,
  }) => _inPlacePreview(type, maxDimension: maxDimension);

  Future<Uint8List?> _inPlacePreview(
    EditorEffectType type, {
    int maxDimension = 768,
  }) async {
    final change = layerTransformFor(type);
    if (change != null) {
      final baked = editorState.layerTransformer.bakePreview(change);
      if (baked == null) return null;
      return _framePreview(baked, maxDimension);
    }
    if (type != EditorEffectType.cropToSelection) return null;
    final layer = activeLayerForApply;
    final keep = _cropKeepRect();
    if (layer == null || keep == null) return null;
    // 选区内没有像素时裁剪结果是空图层，预览同样为空
    return _framePreview(_cropped(layer, keep), maxDimension);
  }

  BakedLayerImage? _cropped(Layer layer, Rect keep) => LayerPatchBaker.cropTo(
    layer,
    keep,
    extentLock: editorState.rolePolicy.extentLockFor(layer),
  );

  /// 把烘焙结果在取景框里的部分缩到 [maxDimension] 以内并编码，接管 [baked] 的释放
  Future<Uint8List?> _framePreview(
    BakedLayerImage? baked,
    int maxDimension,
  ) async {
    ui.Picture? picture;
    ui.Image? image;
    try {
      final frame = editorState.frame;
      final scale = math.min(
        1.0,
        maxDimension / math.max(frame.width, frame.height),
      );
      final width = math.max(1, (frame.width * scale).round());
      final height = math.max(1, (frame.height * scale).round());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..scale(scale)
        ..translate(-frame.left, -frame.top);
      if (baked != null) {
        canvas.drawImage(
          baked.image,
          baked.offset,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      picture = recorder.endRecording();
      image = await picture.toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      picture?.dispose();
      baked?.dispose();
    }
  }

  /// 裁剪保留的区域：选区外接矩形落在取景框内的整像素部分，与预览一致
  Rect? _cropKeepRect() {
    final region = editorState.frame;
    final crop = _selectionCropRect(region);
    if (crop == null) return null;
    return Rect.fromLTWH(
      region.left + crop.x,
      region.top + crop.y,
      crop.width.toDouble(),
      crop.height.toDouble(),
    );
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
    if (editorEffectWorksInPlace(selection.type)) {
      final label = effectLabel(context, selection.type);
      switch (applyInPlace(selection.type)) {
        case InPlaceEffectOutcome.applied:
          onChanged();
          AppToast.success(context, context.l10n.editor_effectApplied(label));
        case InPlaceEffectOutcome.needsSelection:
          AppToast.warning(context, context.l10n.editor_cropNeedsSelection);
        case InPlaceEffectOutcome.nothingToApply:
          AppToast.warning(
            context,
            context.l10n.editor_selectUnlockedLayerWithContent,
          );
      }
      return;
    }
    final epoch = session.beginOperation();
    final region = editorState.frame;
    try {
      final sourceBytes = await _readLayerPng(layer, region);
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
          cropRect: _selectionCropRect(region),
        ),
      );
      if (!context.mounted || !session.accepts(epoch)) return;
      final image = await session.processingService.decode(result.bytes);
      if (!context.mounted || !session.accepts(epoch)) {
        image.dispose();
        return;
      }
      final BakedLayerImage baked;
      try {
        baked = LayerPatchBaker.replaceRegion(
          layer,
          patch: image,
          patchRect: region,
          extentLock: editorState.rolePolicy.extentLockFor(layer),
        );
      } finally {
        image.dispose();
      }
      editorState.historyManager.execute(
        ReplaceLayerImageAction.baked(
          layerId: layer.id,
          pixels: baked,
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

  /// 旋转、翻转与裁剪在图层上原位写回，一步撤销。
  /// 旋转与翻转一次性结束变换，移动工具上已有变换会话时叠加在它的结果之上；
  /// 裁剪只保留选区外接矩形内的像素，矩形内没有像素时图层清空，原图层则保持原图范围
  InPlaceEffectOutcome applyInPlace(EditorEffectType type) {
    assert(editorEffectWorksInPlace(type), '$type is not an in-place effect');
    final transform = layerTransformFor(type);
    if (transform != null) {
      final transformer = editorState.layerTransformer;
      final applied = transformer.update(transform);
      transformer.apply();
      if (!applied) return InPlaceEffectOutcome.nothingToApply;
    } else {
      final layer = activeLayerForApply;
      if (layer == null) return InPlaceEffectOutcome.nothingToApply;
      final keep = _cropKeepRect();
      if (keep == null) return InPlaceEffectOutcome.needsSelection;
      final baked = _cropped(layer, keep);
      editorState.historyManager.execute(
        baked == null
            ? ClearLayerAction(layerId: layer.id)
            : ReplaceLayerImageAction.baked(
                layerId: layer.id,
                pixels: baked,
                actionDescription: 'Crop to Selection',
              ),
        editorState,
      );
    }
    editorState.layerManager.invalidateSnapshot();
    return InPlaceEffectOutcome.applied;
  }

  Future<Uint8List?> _readLayerPng(Layer layer, Rect region) async {
    ui.Image? image;
    try {
      image = await layer.renderToImage(region);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
    }
  }

  /// 选区在 [region] 局部坐标中的外接矩形，与读出的图层图像对齐
  EditorEffectCropRect? _selectionCropRect(Rect region) {
    final selection = editorState.selectionPath;
    if (selection == null) return null;
    final bounds = selection
        .getBounds()
        .intersect(region)
        .shift(-region.topLeft);
    if (bounds.isEmpty) return null;
    final x = bounds.left.floor().clamp(0, region.width - 1);
    final y = bounds.top.floor().clamp(0, region.height - 1);
    final right = bounds.right.ceil().clamp(x + 1, region.width);
    final bottom = bounds.bottom.ceil().clamp(y + 1, region.height);
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
