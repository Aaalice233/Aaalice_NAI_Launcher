import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/inpaint_mask_utils.dart';
import '../../../../core/utils/inpaint_outpaint_utils.dart';
import '../core/editor_state.dart';
import '../export/image_exporter_new.dart';
import '../image_editor_controller.dart';
import '../layers/layer.dart';
import 'editor_frame_commands.dart';
import 'frame_geometry.dart';
import 'frame_history_actions.dart';

enum FrameResizeOutcome {
  applied,
  unchanged,

  /// 超出扩图上限，或会让框脱离原图、拼合后的画布超限
  rejected,
}

/// 重绘编辑器的取景框：框只描述送出区域，永远不平移图层内容。
class EditorFrameController extends ChangeNotifier
    implements EditorFrameCommands {
  EditorFrameController({required this.session, required this.editorState}) {
    editorState.frameNotifier.addListener(notifyListeners);
    editorState.layerManager.addListener(notifyListeners);
  }

  final ImageEditorController session;
  final EditorState editorState;

  Rect? _originalSourceRect;
  bool _isCropping = false;
  bool _disposed = false;
  bool _supportsPasteBack = false;
  EditorRequestEstimate? _requestEstimate;

  bool get isAttached => _originalSourceRect != null;

  bool get isCommitting => _isCropping || session.isOutpaintCommitPending;

  @override
  bool get isCroppingToFrame => _isCropping;

  @override
  bool get supportsPasteBack => _supportsPasteBack;

  /// 由会话调用方决定：只有能把结果贴回整张画布的调用方才开启
  set supportsPasteBack(bool value) {
    if (_supportsPasteBack == value) return;
    _supportsPasteBack = value;
    notifyListeners();
  }

  @override
  EditorRequestEstimate? get requestEstimate => _requestEstimate;

  /// 工作区在取景框或压缩档位变化后推送
  void updateRequestEstimate(EditorRequestEstimate? estimate) {
    if (_requestEstimate == estimate) return;
    _requestEstimate = estimate;
    notifyListeners();
  }

  /// 不裁切时生成结果要贴回的整张画布；框外没有原图内容时为 null
  Rect? get pasteBackCanvas {
    final source = sourceRect;
    if (!_supportsPasteBack || !hasOutpaintChanges || source == null) {
      return null;
    }
    final frame = editorState.frame;
    final canvas = EditorFrameGeometry.outputCanvas(
      frame: frame,
      sourceRect: source,
    );
    return canvas == frame ? null : canvas;
  }

  /// 重绘模式载入原图后调用，此后取景框可以离开原点
  void attachSource(Rect sourceRect) {
    _originalSourceRect = sourceRect;
    editorState.allowsDetachedFrame = true;
    notifyListeners();
  }

  /// 重新打开时恢复上次的取景框（文档坐标），不进撤销栈
  void restoreFrame(Rect frame) {
    final source = sourceRect;
    if (!isAttached || source == null) return;
    editorState.setFrame(
      EditorFrameGeometry.restore(frame, sourceRect: source),
    );
  }

  Layer? get _sourceLayer {
    final id = session.sourceLayerId;
    return id == null ? null : editorState.layerManager.getLayerById(id);
  }

  @override
  Rect? get sourceRect {
    final layer = _sourceLayer;
    final image = layer?.baseImage;
    if (layer == null || image == null) return null;
    return Rect.fromLTWH(
      layer.baseImageOffset.dx,
      layer.baseImageOffset.dy,
      image.width.toDouble(),
      image.height.toDouble(),
    );
  }

  /// 源相对坐标的取景框，供现有扩图物化与蒙版矩形计算复用
  OutpaintVirtualFrame? get virtualFrame {
    final source = sourceRect;
    if (!isAttached || source == null) return null;
    return EditorFrameGeometry.virtualFrame(
      frame: editorState.frame,
      sourceRect: source,
    );
  }

  /// 送出区域与打开时的原图不同：框被移动或缩放过，或原图被裁切过
  bool get hasOutpaintChanges {
    final original = _originalSourceRect;
    if (original == null) return false;
    return editorState.frame != original || sourceRect != original;
  }

  /// 取景框局部坐标下需要生成的空白区域
  List<Rect> get outpaintMaskRects => outpaintMaskRectsFor(editorState.frame);

  /// 任意候选框（如平移预览）局部坐标下的空白区域
  List<Rect> outpaintMaskRectsFor(Rect frame) {
    final source = sourceRect;
    if (!isAttached || source == null) return const [];
    return EditorFrameGeometry.virtualFrame(
      frame: frame,
      sourceRect: source,
    ).outpaintMaskRects;
  }

  bool get _canEdit => isAttached && !isCommitting;

  bool get _viewAllowsFrameEditing {
    final controller = editorState.canvasController;
    return controller.rotation == 0 && !controller.isMirroredHorizontally;
  }

  @override
  bool get canMoveFrame =>
      _canEdit && _viewAllowsFrameEditing && sourceRect != null;

  @override
  Rect resolveMove(Rect startFrame, Offset delta) {
    final source = sourceRect;
    if (source == null) return startFrame;
    return EditorFrameGeometry.move(startFrame, delta, sourceRect: source);
  }

  @override
  void commitMove(Rect from, Rect to) {
    if (!canMoveFrame || from == to) return;
    _commitFrame(from, to, 'Move Frame');
  }

  /// 缩放预览与提交共用的约束：与原图保持重叠、拼接后的整张画布不超上限
  bool isFrameAllowed(Rect candidate) {
    final source = sourceRect;
    return source != null &&
        EditorFrameGeometry.isFrameAllowed(candidate, sourceRect: source);
  }

  /// 边缘拖拽、Shift Edges 与画布尺寸对话框共用的缩放入口
  FrameResizeOutcome applyFrameDelta(
    OutpaintFrameDelta delta, {
    required OutpaintHorizontalSnapTarget horizontalSnapTarget,
    required OutpaintVerticalSnapTarget verticalSnapTarget,
  }) {
    if (!_canEdit) return FrameResizeOutcome.unchanged;
    final current = editorState.frame;
    final next = EditorFrameGeometry.resize(
      current,
      delta,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
    if (next == current) return FrameResizeOutcome.unchanged;
    if (next == null || !isFrameAllowed(next)) {
      return FrameResizeOutcome.rejected;
    }
    _commitFrame(current, next, 'Resize Frame');
    return FrameResizeOutcome.applied;
  }

  @override
  bool get canResetFrame {
    final source = sourceRect;
    return _canEdit &&
        source != null &&
        editorState.frame != EditorFrameGeometry.fitToSource(source);
  }

  @override
  void resetFrame() {
    final source = sourceRect;
    if (!canResetFrame || source == null) return;
    _commitFrame(
      editorState.frame,
      EditorFrameGeometry.fitToSource(source),
      'Reset Frame',
    );
  }

  @override
  bool get canCropToFrame {
    if (!_canEdit) return false;
    final frame = editorState.frame;
    final source = sourceRect;
    // 框与原图不相交时裁切会丢掉整张原图
    if (source == null || !source.overlaps(frame)) return false;
    return editorState.layerManager.layers.any(
      (layer) =>
          layer.hasContent &&
          EditorFrameGeometry.exceedsFrame(layer.contentBounds, frame),
    );
  }

  @override
  Future<void> cropToFrame() async {
    if (!canCropToFrame) return;
    _isCropping = true;
    notifyListeners();

    final epoch = session.beginOperation();
    final documentVersion = editorState.layerManager.snapshotVersion;
    final frame = editorState.frame;
    CropToFrameAction? action;
    try {
      action = await _prepareCrop(frame);
      // 准备期间文档或取景框被其他操作改动过，结果已不对应当前内容
      if (!session.accepts(epoch) ||
          editorState.layerManager.snapshotVersion != documentVersion ||
          editorState.frame != frame) {
        return;
      }
      editorState.historyManager.execute(action, editorState);
      action = null;
    } finally {
      action?.dispose();
      _isCropping = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _commitFrame(Rect from, Rect to, String description) {
    editorState.historyManager.execute(
      FrameChangeAction(from: from, to: to, actionDescription: description),
      editorState,
    );
  }

  Future<CropToFrameAction> _prepareCrop(Rect frame) async {
    final changes = <CropToFrameLayerChange>[];
    try {
      for (final layer in editorState.layerManager.layers) {
        if (!layer.hasContent ||
            !EditorFrameGeometry.exceedsFrame(layer.contentBounds, frame)) {
          continue;
        }
        final after = layer.id == session.sourceLayerId
            ? await _cropSourceContent(layer, frame)
            : await _bakeMaskContent(layer, frame);
        changes.add(
          CropToFrameLayerChange(
            layerId: layer.id,
            before: layer.captureContent(),
            after: after,
          ),
        );
      }
    } catch (_) {
      for (final change in changes) {
        change.dispose();
      }
      rethrow;
    }
    return CropToFrameAction(changes: changes);
  }

  Future<LayerContentSnapshot> _cropSourceContent(
    Layer layer,
    Rect frame,
  ) async {
    final bytes = layer.baseImageBytes;
    final source = sourceRect;
    if (bytes == null || source == null) {
      throw StateError('Unable to read current source image.');
    }
    final kept = source.intersect(frame);
    final cropped = await session.processingService.materializeOutpaint(
      sourceImage: bytes,
      frame: EditorFrameGeometry.virtualFrame(frame: kept, sourceRect: source),
    );
    final image = await session.processingService.decode(cropped.sourceImage);
    return LayerContentSnapshot(
      baseImage: image,
      baseImageBytes: cropped.sourceImage,
      baseImageOffset: kept.topLeft,
      strokes: layer.strokes,
    );
  }

  /// 蒙版图层按框局部光栅化成框尺寸的叠加图，框外部分随之丢弃
  Future<LayerContentSnapshot> _bakeMaskContent(Layer layer, Rect frame) async {
    final raster = await ImageExporterNew.exportLayerMaskRaster(layer, frame);
    if (!raster.mask.contains(1)) {
      return const LayerContentSnapshot.empty();
    }
    final bytes = await InpaintMaskUtils.encodeEditorOverlayFromBinaryMaskAsync(
      raster.mask,
      width: raster.width,
      height: raster.height,
    );
    final image = await session.processingService.decode(bytes);
    return LayerContentSnapshot(
      baseImage: image,
      baseImageBytes: bytes,
      baseImageOffset: frame.topLeft,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    editorState.frameNotifier.removeListener(notifyListeners);
    editorState.layerManager.removeListener(notifyListeners);
    super.dispose();
  }
}
