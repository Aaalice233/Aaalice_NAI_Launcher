import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import 'tool_base.dart';

class FillTool extends EditorTool {
  int _tolerance = 32;
  int get tolerance => _tolerance;

  void setTolerance(int value) {
    _tolerance = value.clamp(0, 255);
  }

  @override
  String get id => 'fill';

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
    _performFill(state, event.localPosition);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {}

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {}

  Future<void> _performFill(EditorState state, Offset tapPosition) async {
    final canvasSize = state.canvasSize;
    final width = canvasSize.width.toInt();
    final height = canvasSize.height.toInt();
    final startX = tapPosition.dx.round().clamp(0, width - 1);
    final startY = tapPosition.dy.round().clamp(0, height - 1);
    final fillColor = state.foregroundColor;

    final activeLayer = state.layerManager.activeLayer;
    if (activeLayer == null || activeLayer.locked) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    state.layerManager.renderAll(canvas, canvasSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) return;
    final pixels = byteData.buffer.asUint8List();

    final targetIdx = (startY * width + startX) * 4;
    if (targetIdx + 3 >= pixels.length) return;

    final targetR = pixels[targetIdx];
    final targetG = pixels[targetIdx + 1];
    final targetB = pixels[targetIdx + 2];
    final targetA = pixels[targetIdx + 3];

    final fillR = (fillColor.r * 255.0).round().clamp(0, 255);
    final fillG = (fillColor.g * 255.0).round().clamp(0, 255);
    final fillB = (fillColor.b * 255.0).round().clamp(0, 255);
    final fillA = (fillColor.a * 255.0).round().clamp(0, 255);

    if (targetR == fillR &&
        targetG == fillG &&
        targetB == fillB &&
        targetA == fillA) {
      return;
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
      fillPoints.add(Offset(px.toDouble(), py.toDouble()));

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

        if (dr <= _tolerance &&
            dg <= _tolerance &&
            db <= _tolerance &&
            da <= _tolerance) {
          stack.add(nIdx);
        }
      }
    }

    if (fillPoints.isEmpty) return;

    final stroke = StrokeData(
      points: fillPoints,
      size: 1,
      color: fillColor,
      opacity: fillColor.a,
      hardness: 1.0,
      isEraser: false,
    );

    state.historyManager.execute(
      AddStrokeAction(layerId: activeLayer.id, stroke: stroke),
      state,
    );
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
                context.l10n.editor_toolFill,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    context.l10n.editor_tolerance,
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text('$_tolerance', style: theme.textTheme.bodySmall),
                ],
              ),
              Slider(
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
        );
      },
    );
  }
}
