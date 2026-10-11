import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import '../core/editor_tool_groups.dart';
import '../core/history_manager.dart';
import '../core/mask_paint_style.dart';
import 'tool_base.dart';
import 'tool_setting_rows.dart';

class FillTool extends EditorTool {
  int _tolerance = 32;
  int get tolerance => _tolerance;

  void setTolerance(int value) {
    _tolerance = value.clamp(0, 255);
  }

  @override
  String get id => 'fill';

  @override
  bool get followsLayerRole => true;

  @override
  String get name => 'Fill';

  @override
  IconData get icon => Icons.format_color_fill;

  @override
  LogicalKeyboardKey? get shortcutKey => LogicalKeyboardKey.keyG;

  @override
  bool get isPaintTool => true;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    final request = _FillRequest.capture(
      state,
      event.localPosition,
      _tolerance,
    );
    if (request == null) return;
    unawaited(state.pixelReadbacks.run(() => _fill(state, request)));
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {}

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {}

  static Future<void> _fill(EditorState state, _FillRequest request) async {
    final pixels = await _readCurrentPixels(state, request.region);
    if (pixels == null || state.isDisposed) return;
    final layer = state.layerManager.getLayerById(request.layerId);
    if (layer == null || layer.locked) return;

    final fillPoints = request.floodFill(pixels);
    if (fillPoints.isEmpty) return;

    final stroke = StrokeData(
      points: fillPoints,
      size: 1,
      color: request.color,
      opacity: request.opacity,
      hardness: 1.0,
      isEraser: false,
    );

    state.historyManager.execute(
      AddStrokeAction(layerId: layer.id, stroke: stroke),
      state,
    );
  }

  /// 回读期间画面被其他操作改过就重读，填充范围始终对应写回那一刻的画面
  static Future<Uint8List?> _readCurrentPixels(
    EditorState state,
    Rect region,
  ) async {
    while (!state.isDisposed) {
      final version = state.layerManager.snapshotVersion;
      final pixels = await _readPixels(state, region);
      if (pixels == null || version == state.layerManager.snapshotVersion) {
        return pixels;
      }
    }
    return null;
  }

  static Future<Uint8List?> _readPixels(EditorState state, Rect region) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-region.left, -region.top);
    state.layerManager.renderAll(canvas);
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(
        region.width.toInt(),
        region.height.toInt(),
      );
    } finally {
      picture.dispose();
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
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
                editorToolLabel(context, this, state.activeLayerRole),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ToolSettingRows(
                rowPadding: const EdgeInsets.symmetric(vertical: 4),
                rows: [
                  ToolSettingRow.slider(
                    label: context.l10n.editor_tolerance,
                    value: _tolerance.toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    onChanged: (v) {
                      setState(() => setTolerance(v.round()));
                    },
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

/// 按下那一刻的填充目标与参数；排队等待期间切换图层、颜色或容差不影响这一次
class _FillRequest {
  const _FillRequest({
    required this.layerId,
    required this.region,
    required this.startX,
    required this.startY,
    required this.color,
    required this.opacity,
    required this.tolerance,
  });

  static _FillRequest? capture(EditorState state, Offset tap, int tolerance) {
    final layer = state.layerManager.activeLayer;
    if (layer == null || layer.locked) return null;
    // 采样与填充都限定在按下时的取景框内，填充点再换回文档坐标
    final region = state.frame;
    final width = region.width.toInt();
    final height = region.height.toInt();
    if (width <= 0 || height <= 0) return null;
    final color = state.paintColor;
    return _FillRequest(
      layerId: layer.id,
      region: region,
      startX: (tap.dx - region.left).round().clamp(0, width - 1),
      startY: (tap.dy - region.top).round().clamp(0, height - 1),
      color: color,
      opacity: layer.isMask ? MaskPaintStyle.opacity : color.a,
      tolerance: tolerance,
    );
  }

  final String layerId;
  final Rect region;
  final int startX;
  final int startY;
  final Color color;
  final double opacity;
  final int tolerance;

  /// [pixels] 是 [region] 的 RGBA；返回与起点连通且颜色相近的像素的文档坐标
  List<Offset> floodFill(Uint8List pixels) {
    final width = region.width.toInt();
    final height = region.height.toInt();
    final targetIdx = (startY * width + startX) * 4;
    if (targetIdx + 3 >= pixels.length) return const [];

    final targetR = pixels[targetIdx];
    final targetG = pixels[targetIdx + 1];
    final targetB = pixels[targetIdx + 2];
    final targetA = pixels[targetIdx + 3];

    final fillR = (color.r * 255.0).round().clamp(0, 255);
    final fillG = (color.g * 255.0).round().clamp(0, 255);
    final fillB = (color.b * 255.0).round().clamp(0, 255);
    final fillA = (color.a * 255.0).round().clamp(0, 255);

    if (targetR == fillR &&
        targetG == fillG &&
        targetB == fillB &&
        targetA == fillA) {
      return const [];
    }

    final visited = Uint8List(width * height);
    final stack = <int>[];
    stack.add(startY * width + startX);
    visited[startY * width + startX] = 1;

    final fillPoints = <Offset>[];

    while (stack.isNotEmpty) {
      final idx = stack.removeLast();
      final px = idx % width;
      final py = idx ~/ width;
      fillPoints.add(Offset(px + region.left, py + region.top));

      for (final (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
        final nx = px + dx;
        final ny = py + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        final nIdx = ny * width + nx;
        if (visited[nIdx] == 1) continue;
        visited[nIdx] = 1;

        final pi = nIdx * 4;
        final dr = (pixels[pi] - targetR).abs();
        final dg = (pixels[pi + 1] - targetG).abs();
        final db = (pixels[pi + 2] - targetB).abs();
        final da = (pixels[pi + 3] - targetA).abs();

        if (dr <= tolerance &&
            dg <= tolerance &&
            db <= tolerance &&
            da <= tolerance) {
          stack.add(nIdx);
        }
      }
    }
    return fillPoints;
  }
}
