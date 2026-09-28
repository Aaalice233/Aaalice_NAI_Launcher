import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import 'tool_base.dart';

/// Clone Stamp 工具 - 像素级仿制图章
///
/// Alt+Click 同步捕获画布快照并设置源点。
/// 绘制时实时显示克隆像素预览，松开后原子应用。
class CloneStampTool extends EditorTool {
  double _size = 20.0;
  double get size => _size;

  double _opacity = 1.0;
  double get opacity => _opacity;

  Offset? _sourcePoint;
  Offset? get sourcePoint => _sourcePoint;

  Offset? _sourceOffset;
  Offset? get sourceOffset => _sourceOffset;

  ui.Image? _canvasSnapshot;
  ui.Image? get canvasSnapshot => _canvasSnapshot;

  bool _isApplying = false;

  void setSize(double value) {
    _size = value.clamp(1.0, 200.0);
  }

  void setOpacity(double value) {
    _opacity = value.clamp(0.0, 1.0);
  }

  @override
  String get id => 'clone_stamp';

  @override
  String get name => 'Clone Stamp';

  @override
  IconData get icon => Icons.copy_all;

  @override
  bool get isPaintTool => true;

  @override
  bool get handlesAltKey => true;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    if (state.isAltPressed) {
      _setSourcePoint(event.localPosition, state);
      return;
    }

    if (_sourcePoint == null || _canvasSnapshot == null) return;

    _sourceOffset ??= event.localPosition - _sourcePoint!;
    state.startStroke(event.localPosition);
  }

  void _setSourcePoint(Offset position, EditorState state) {
    _sourcePoint = position;
    _sourceOffset = null;
    _captureSnapshotSync(state);
  }

  /// 同步捕获画布快照（保证 Alt+Click 后立即可用）
  void _captureSnapshotSync(EditorState state) {
    _canvasSnapshot?.dispose();
    _canvasSnapshot = null;

    final canvasSize = state.canvasSize;
    final w = canvasSize.width.toInt();
    final h = canvasSize.height.toInt();
    if (w <= 0 || h <= 0) return;

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    state.layerManager.renderAll(c, canvasSize);
    final pic = rec.endRecording();
    _canvasSnapshot = pic.toImageSync(w, h);
    pic.dispose();
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (state.isAltPressed) return;
    if (_sourcePoint == null || _sourceOffset == null) return;

    if (state.isDrawing) {
      state.updateStroke(event.localPosition);
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (state.isAltPressed) return;
    if (_isApplying) {
      state.endStroke();
      return;
    }

    if (state.isDrawing && state.currentStrokePoints.isNotEmpty) {
      final points = List<Offset>.from(state.currentStrokePoints);
      state.endStroke();
      _applyClone(state, points);
    } else {
      state.endStroke();
    }
  }

  Future<void> _applyClone(EditorState state, List<Offset> points) async {
    final activeLayer = state.layerManager.activeLayer;
    if (activeLayer == null || activeLayer.locked) return;
    if (_canvasSnapshot == null || _sourceOffset == null) return;
    _isApplying = true;

    try {
      final canvasSize = state.canvasSize;
      final w = canvasSize.width.toInt();
      final h = canvasSize.height.toInt();

      final layerImg = await _renderLayerToImage(activeLayer, canvasSize, w, h);

      final result = _compositeCloneSync(
        layerImg,
        _canvasSnapshot!,
        points,
        _sourceOffset!,
        w,
        h,
      );
      layerImg.dispose();

      final pngData = await result.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) {
        result.dispose();
        return;
      }

      state.historyManager.execute(
        ReplaceLayerImageAction(
          layerId: activeLayer.id,
          newImageBytes: pngData.buffer.asUint8List(),
          newImage: result,
          actionDescription: 'Clone Stamp',
        ),
        state,
      );
    } finally {
      _isApplying = false;
    }
  }

  Future<ui.Image> _renderLayerToImage(
    dynamic layer,
    Size canvasSize,
    int w,
    int h,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    (layer as dynamic).render(c, canvasSize);
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  /// 同步合成克隆结果
  ui.Image _compositeCloneSync(
    ui.Image layerImage,
    ui.Image snapshot,
    List<Offset> points,
    Offset offset,
    int w,
    int h,
  ) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    c.drawImage(layerImage, Offset.zero, Paint());

    final clonePaint = Paint()..color = Color.fromRGBO(255, 255, 255, _opacity);

    _drawClonePoints(c, snapshot, points, offset, clonePaint);

    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    return img;
  }

  /// 在画布上绘制克隆点（含插值，共用于实时预览和最终应用）
  void _drawClonePoints(
    Canvas c,
    ui.Image snapshot,
    List<Offset> points,
    Offset offset,
    Paint paint,
  ) {
    void drawAt(Offset pt) {
      c.save();
      c.clipPath(
        Path()
          ..addOval(Rect.fromCenter(center: pt, width: _size, height: _size)),
      );
      c.drawImage(snapshot, offset, paint);
      c.restore();
    }

    for (final pt in points) {
      drawAt(pt);
    }

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final dist = (b - a).distance;
      if (dist < 1) continue;
      final steps = (dist / (_size * 0.25)).ceil();
      for (int s = 1; s < steps; s++) {
        drawAt(Offset.lerp(a, b, s / steps)!);
      }
    }
  }

  /// 绘制实时克隆预览（由 LayerPainter 调用）
  void drawRealtimePreview(Canvas canvas, List<Offset> points) {
    if (_canvasSnapshot == null || _sourceOffset == null) return;

    final clonePaint = Paint()..color = Color.fromRGBO(255, 255, 255, _opacity);

    _drawClonePoints(
      canvas,
      _canvasSnapshot!,
      points,
      _sourceOffset!,
      clonePaint,
    );
  }

  @override
  void onDeactivateFast(EditorState state) {
    _sourcePoint = null;
    _sourceOffset = null;
    _canvasSnapshot?.dispose();
    _canvasSnapshot = null;
  }

  @override
  double getCursorRadius(EditorState state) => _size / 2;

  @override
  Widget? buildCursor(EditorState state, {Offset? screenCursorPosition}) {
    if (_sourcePoint == null || screenCursorPosition == null) return null;
    return const Icon(Icons.add, color: Colors.cyanAccent, size: 16);
  }

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.editor_toolCloneStamp,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.editor_sourcePoint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_sourcePoint != null) ...[
                const SizedBox(height: 4),
                Text(
                  '(${_sourcePoint!.dx.round()}, ${_sourcePoint!.dy.round()})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    context.l10n.editor_size,
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text('${_size.round()}', style: theme.textTheme.bodySmall),
                ],
              ),
              Slider(
                value: _size,
                min: 1,
                max: 200,
                onChanged: (v) => setState(() => setSize(v)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    context.l10n.editor_opacity,
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${(_opacity * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              Slider(
                value: _opacity,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => setState(() => setOpacity(v)),
              ),
            ],
          ),
        );
      },
    );
  }
}
