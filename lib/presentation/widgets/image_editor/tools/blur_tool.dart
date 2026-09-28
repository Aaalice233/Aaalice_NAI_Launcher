import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import 'tool_base.dart';

/// Blur 工具 - 真正的像素级高斯模糊
///
/// 绘制路径作为模糊蒙版，松开后对蒙版区域应用高斯模糊。
class BlurTool extends EditorTool {
  double _intensity = 0.5;
  double get intensity => _intensity;

  double _size = 30.0;
  double get size => _size;

  bool _isApplying = false;

  void setIntensity(double value) {
    _intensity = value.clamp(0.0, 1.0);
  }

  void setSize(double value) {
    _size = value.clamp(1.0, 200.0);
  }

  @override
  String get id => 'blur';

  @override
  String get name => 'Blur';

  @override
  IconData get icon => Icons.blur_on;

  @override
  bool get isPaintTool => true;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    state.startStroke(event.localPosition);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (state.isDrawing) {
      state.updateStroke(event.localPosition);
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (_isApplying) {
      state.endStroke();
      return;
    }
    if (state.isDrawing && state.currentStrokePoints.isNotEmpty) {
      final points = List<Offset>.from(state.currentStrokePoints);
      state.endStroke();
      _applyBlur(state, points);
    } else {
      state.endStroke();
    }
  }

  Future<void> _applyBlur(EditorState state, List<Offset> points) async {
    final activeLayer = state.layerManager.activeLayer;
    if (activeLayer == null || activeLayer.locked) return;
    _isApplying = true;

    try {
      final canvasSize = state.canvasSize;
      final w = canvasSize.width.toInt();
      final h = canvasSize.height.toInt();

      final original = await _renderLayerToImage(activeLayer, canvasSize, w, h);

      final sigma = _size * _intensity * 0.5;
      final blurred = await _createBlurredImage(original, sigma, w, h);

      final strokeMask = _buildStrokePath(points);

      final result = await _compositeBlur(
        original,
        blurred,
        strokeMask,
        w,
        h,
        canvasSize,
      );
      original.dispose();
      blurred.dispose();

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
          actionDescription: 'Blur',
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

  Future<ui.Image> _createBlurredImage(
    ui.Image source,
    double sigma,
    int w,
    int h,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImage(
      source,
      Offset.zero,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  Path _buildStrokePath(List<Offset> points) {
    final path = Path();
    for (final p in points) {
      path.addOval(Rect.fromCenter(center: p, width: _size, height: _size));
    }
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len = (Offset(dx, dy)).distance;
      if (len < 0.1) continue;
      final nx = -dy / len * _size / 2;
      final ny = dx / len * _size / 2;
      final rect = Path()
        ..moveTo(a.dx + nx, a.dy + ny)
        ..lineTo(b.dx + nx, b.dy + ny)
        ..lineTo(b.dx - nx, b.dy - ny)
        ..lineTo(a.dx - nx, a.dy - ny)
        ..close();
      path.addPath(rect, Offset.zero);
    }
    return path;
  }

  Future<ui.Image> _compositeBlur(
    ui.Image original,
    ui.Image blurred,
    Path mask,
    int w,
    int h,
    Size canvasSize,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImage(original, Offset.zero, Paint());
    c.save();
    c.clipPath(mask);
    c.drawImage(blurred, Offset.zero, Paint());
    c.restore();
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  @override
  double getCursorRadius(EditorState state) => _size / 2;

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
                context.l10n.editor_toolBlur,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                    context.l10n.editor_intensity,
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${(_intensity * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              Slider(
                value: _intensity,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => setState(() => setIntensity(v)),
              ),
            ],
          ),
        );
      },
    );
  }
}
