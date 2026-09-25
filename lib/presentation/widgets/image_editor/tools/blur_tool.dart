import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import '../layers/layer_patch_baker.dart';
import 'tool_base.dart';
import 'tool_setting_rows.dart';

/// Blur 工具 - 真正的像素级高斯模糊
///
/// 绘制路径作为模糊蒙版，松开后对蒙版区域应用高斯模糊。
class BlurTool extends EditorTool {
  double _intensity = 0.5;
  double get intensity => _intensity;

  double _size = 30.0;
  double get size => _size;

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

  /// 模糊只处理画面像素，蒙版层上没有意义
  @override
  bool isAvailableIn(EditorState state) => !state.isMaskLayerActive;

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
    if (state.isDrawing && state.currentStrokePoints.isNotEmpty) {
      final points = List<Offset>.from(state.currentStrokePoints);
      state.endStroke();
      _applyBlur(state, points);
    } else {
      state.endStroke();
    }
  }

  void _applyBlur(EditorState state, List<Offset> points) {
    final layer = state.layerManager.activeLayer;
    if (layer == null || layer.locked) return;

    final frame = state.frame;
    final mask = _buildStrokePath(points);
    final dirty = mask.getBounds().intersect(frame);
    if (dirty.isEmpty) return;

    final sigma = _size * _intensity * 0.5;
    // 只取笔画周围覆盖高斯核半径的像素；贴着取景框的一侧仍按框边缘延展
    final source = _pixelAligned(
      dirty.inflate((sigma * 3).ceilToDouble() + 1).intersect(frame),
    );
    final sourcePixels = layer.renderToImageSync(source);
    final BakedLayerImage baked;
    try {
      baked = LayerPatchBaker.paintOver(
        layer,
        dirtyRect: dirty,
        extentLock: state.rolePolicy.extentLockFor(layer),
        paint: (canvas) {
          canvas.clipPath(mask);
          canvas.drawImage(
            sourcePixels,
            source.topLeft,
            Paint()
              ..imageFilter = ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.clamp,
              ),
          );
        },
      );
    } finally {
      sourcePixels.dispose();
    }

    state.historyManager.execute(
      ReplaceLayerImageAction.baked(
        layerId: layer.id,
        pixels: baked,
        actionDescription: 'Blur',
      ),
      state,
    );
  }

  static Rect _pixelAligned(Rect rect) => Rect.fromLTRB(
    rect.left.floorToDouble(),
    rect.top.floorToDouble(),
    rect.right.ceilToDouble(),
    rect.bottom.ceilToDouble(),
  );

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
      // 与 addOval 同为顺时针，否则非零环绕下与圆重叠处互相抵消成空洞
      final rect = Path()
        ..moveTo(a.dx - nx, a.dy - ny)
        ..lineTo(b.dx - nx, b.dy - ny)
        ..lineTo(b.dx + nx, b.dy + ny)
        ..lineTo(a.dx + nx, a.dy + ny)
        ..close();
      path.addPath(rect, Offset.zero);
    }
    return path;
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
              const SizedBox(height: 8),
              ToolSettingRows(
                rowPadding: const EdgeInsets.symmetric(vertical: 4),
                rows: [
                  ToolSettingRow.slider(
                    label: context.l10n.editor_size,
                    value: _size,
                    min: 1,
                    max: 200,
                    onChanged: (v) => setState(() => setSize(v)),
                  ),
                  ToolSettingRow.slider(
                    label: context.l10n.editor_intensity,
                    value: _intensity * 100,
                    min: 0,
                    max: 100,
                    suffix: '%',
                    onChanged: (v) => setState(() => setIntensity(v / 100)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
