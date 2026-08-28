import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/contiguous_region_selector.dart';
import '../../../../core/utils/editor_compression_utils.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/services/efficient_vit_sam_service.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import '../export/image_exporter_new.dart';
import '../image_editor_controller.dart';
import '../image_editor_types.dart';
import '../layers/layer.dart';

@immutable
class MagicWandSnapshot {
  const MagicWandSnapshot({this.processing = false, this.progress});
  final bool processing;
  final EfficientVitSamProgress? progress;
}

class MagicWandController extends ChangeNotifier {
  MagicWandController({
    required this.session,
    required this.editorState,
    required this.config,
    required this.addMaskLayer,
  });

  final ImageEditorController session;
  final EditorState editorState;
  final ImageEditorSessionConfig config;
  final Layer Function(String name) addMaskLayer;
  MagicWandSnapshot _snapshot = const MagicWandSnapshot();
  bool _disposed = false;

  MagicWandSnapshot get snapshot => _snapshot;

  Future<void> apply(
    BuildContext context,
    Offset point, {
    required MagicWandSelectionMode mode,
    required int tolerance,
    required bool invert,
  }) async {
    if (_disposed || _snapshot.processing) return;
    final width = editorState.canvasSize.width.round();
    final height = editorState.canvasSize.height.round();
    final x = point.dx.floor();
    final y = point.dy.floor();
    if (width <= 0 ||
        height <= 0 ||
        x < 0 ||
        x >= width ||
        y < 0 ||
        y >= height) {
      return;
    }

    final target = config.mode == ImageEditorMode.inpaint
        ? _sourceLayer()
        : _editTarget();
    if (target == null) {
      AppToast.warning(context, context.l10n.editor_magicWandNoSource);
      return;
    }
    _update(const MagicWandSnapshot(processing: true));
    final epoch = session.beginOperation();
    try {
      final source = await _renderSource(target);
      if (!session.accepts(epoch)) return;
      final selection = await _select(
        source: source,
        mode: mode,
        x: x,
        y: y,
        tolerance: tolerance,
        invert: invert,
      );
      if (!context.mounted || !session.accepts(epoch)) return;
      if (selection.width != width ||
          selection.height != height ||
          selection.mask.length != width * height) {
        throw StateError('Magic Wand returned an invalid selection mask.');
      }
      if (config.mode == ImageEditorMode.inpaint) {
        await _applyMask(context, selection, width, height, epoch);
      } else {
        await _applyErase(
          context,
          target,
          source,
          selection,
          width,
          height,
          epoch,
        );
      }
      if (!context.mounted || !session.accepts(epoch)) return;
      editorState.layerManager.invalidateSnapshot();
      editorState.notifyRenderChange();
      editorState.requestUiUpdate();
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.editor_magicWandFailed(error));
      }
    } finally {
      if (!_disposed) _update(const MagicWandSnapshot());
    }
  }

  Layer? _editTarget() {
    final source = _sourceLayer();
    if (source != null && !source.locked) return source;
    final active = editorState.layerManager.activeLayer;
    if (active != null && !active.locked && active.hasContent) return active;
    for (final layer in editorState.layerManager.layers) {
      if (layer.visible && !layer.locked && layer.hasContent) return layer;
    }
    return null;
  }

  Layer? _sourceLayer() {
    final id = session.sourceLayerId;
    if (id == null) return null;
    final layer = editorState.layerManager.getLayerById(id);
    return layer?.hasContent == true ? layer : null;
  }

  Future<EditorRawRgbaImage> _renderSource(Layer layer) async {
    final width = editorState.canvasSize.width.round();
    final height = editorState.canvasSize.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (layer.baseImage != null && layer.strokes.isEmpty) {
      canvas.drawImage(layer.baseImage!, layer.baseImageOffset, Paint());
    } else {
      layer.render(canvas, editorState.canvasSize);
    }
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw StateError('Failed to read Magic Wand source pixels.');
      }
      return EditorRawRgbaImage(
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: width,
        height: height,
      );
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  Future<ContiguousRegionSelection> _select({
    required EditorRawRgbaImage source,
    required MagicWandSelectionMode mode,
    required int x,
    required int y,
    required int tolerance,
    required bool invert,
  }) {
    if (mode == MagicWandSelectionMode.colorArea) {
      return ContiguousRegionSelector.selectRgbaAsync(
        rgba: source.bytes,
        width: source.width,
        height: source.height,
        startX: x,
        startY: y,
        tolerance: tolerance,
        invert: invert,
      );
    }
    final selector = config.debugOptions.efficientVitSamSelector;
    if (selector != null) {
      return selector(
        rgba: source.bytes,
        width: source.width,
        height: source.height,
        startX: x,
        startY: y,
        invert: invert,
        onProgress: _onProgress,
      );
    }
    return session.processingService.selectMagicWand(
      source: source,
      startX: x,
      startY: y,
      invert: invert,
      onProgress: _onProgress,
    );
  }

  Future<void> _applyMask(
    BuildContext context,
    ContiguousRegionSelection selection,
    int width,
    int height,
    int epoch,
  ) async {
    final mask = await _existingMask(width, height);
    if (!context.mounted || !session.accepts(epoch)) return;
    var changed = 0;
    for (var i = 0; i < mask.length; i++) {
      if (selection.mask[i] == 1 && mask[i] == 0) {
        mask[i] = 1;
        changed++;
      }
    }
    if (changed == 0) {
      AppToast.info(context, context.l10n.editor_magicWandNothingChanged);
      return;
    }
    final bytes = await InpaintMaskUtils.encodeEditorOverlayFromBinaryMaskAsync(
      mask,
      width: width,
      height: height,
    );
    final image = await session.processingService.decode(bytes);
    if (!context.mounted || !session.accepts(epoch)) {
      image.dispose();
      return;
    }
    final target = resolveMagicWandMaskTarget(
      context.l10n.editor_maskLayerName,
    );
    editorState.historyManager.execute(
      ReplaceLayerImageAction(
        layerId: target.id,
        newImageBytes: bytes,
        newImage: image,
        actionDescription: 'Apply Magic Wand Mask',
      ),
      editorState,
    );
    editorState.layerManager.setActiveLayer(target.id);
  }

  @visibleForTesting
  Layer resolveMagicWandMaskTarget(String maskLayerName) {
    final activeLayer = editorState.layerManager.activeLayer;
    if (activeLayer != null &&
        activeLayer.id != session.sourceLayerId &&
        !activeLayer.locked) {
      return activeLayer;
    }

    for (final layer in editorState.layerManager.layers) {
      if (layer.id != session.sourceLayerId && !layer.locked) {
        return layer;
      }
    }

    return addMaskLayer(maskLayerName);
  }

  Future<void> _applyErase(
    BuildContext context,
    Layer target,
    EditorRawRgbaImage source,
    ContiguousRegionSelection selection,
    int width,
    int height,
    int epoch,
  ) async {
    final edited = Uint8List.fromList(source.bytes);
    var changed = 0;
    for (var i = 0; i < selection.mask.length; i++) {
      if (selection.mask[i] == 1 && edited[i * 4 + 3] != 0) {
        edited[i * 4 + 3] = 0;
        changed++;
      }
    }
    if (changed == 0) {
      AppToast.info(context, context.l10n.editor_magicWandNothingChanged);
      return;
    }
    final bytes = await session.processingService.encodeRgba(
      EditorRawRgbaImage(bytes: edited, width: width, height: height),
      width: width,
      height: height,
    );
    final image = await session.processingService.decode(bytes);
    if (!context.mounted || !session.accepts(epoch)) {
      image.dispose();
      return;
    }
    editorState.historyManager.execute(
      ReplaceLayerImageAction(
        layerId: target.id,
        newImageBytes: bytes,
        newImage: image,
        actionDescription: 'Erase Magic Wand Region',
      ),
      editorState,
    );
    editorState.layerManager.setActiveLayer(target.id);
    session.hasTransparentCutout = true;
  }

  Future<Uint8List> _existingMask(int width, int height) async {
    final excluded = {
      if (session.sourceLayerId != null) session.sourceLayerId!,
    };
    final raster = await ImageExporterNew.tryExportHardEdgeMaskRasterFromLayers(
      editorState.layerManager,
      editorState.canvasSize,
      excludedBaseImageLayerIds: excluded,
    );
    if (raster != null &&
        raster.width == width &&
        raster.height == height &&
        raster.mask.length == width * height) {
      return Uint8List.fromList(raster.mask);
    }
    final encoded = await ImageExporterNew.exportMaskFromLayers(
      editorState.layerManager,
      editorState.canvasSize,
      excludedBaseImageLayerIds: excluded,
      forceHardEdges: true,
      preferCpuHardEdgeExport: true,
    );
    final decoded = InpaintMaskUtils.decodeBinaryMask(encoded);
    if (decoded == null || decoded.width != width || decoded.height != height) {
      throw StateError('Failed to read the current inpaint mask.');
    }
    return Uint8List.fromList(decoded.mask);
  }

  void _onProgress(EfficientVitSamProgress progress) =>
      _update(MagicWandSnapshot(processing: true, progress: progress));

  void _update(MagicWandSnapshot value) {
    if (_disposed) return;
    _snapshot = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
