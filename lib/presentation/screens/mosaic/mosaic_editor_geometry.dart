import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../data/models/mosaic/mosaic_settings.dart';

/// 马赛克编辑器撤销/重做栈快照。
class MosaicSnapshot {
  const MosaicSnapshot({
    required this.settings,
    required this.regions,
    required this.selectedId,
    required this.drawShape,
  });

  final MosaicSettings settings;
  final List<MosaicRegion> regions;
  final String? selectedId;
  final MosaicShape drawShape;
}

bool mosaicProcessedStyleChanged(MosaicSettings a, MosaicSettings b) =>
    a.effect != b.effect ||
    a.pixelSizeRatio != b.pixelSizeRatio ||
    a.blurSigmaRatio != b.blurSigmaRatio;

MosaicRegion createCenteredMosaicRegion({
  required String id,
  required MosaicSettings settings,
  MosaicShape? shape,
}) {
  final resolvedShape =
      shape ??
      (settings.defaultShape == MosaicShape.brush
          ? MosaicShape.roundedRectangle
          : settings.defaultShape);
  return MosaicRegion(
    id: id,
    left: 0.33,
    top: 0.39,
    width: 0.34,
    height: 0.18,
    shape: resolvedShape,
    brushSizeRatio: settings.brushSizeRatio,
  );
}

MosaicRegion createCenteredBrushMosaicRegion({
  required String id,
  required double brushSizeRatio,
}) {
  final points = <MosaicPoint>[
    const MosaicPoint(0.40, 0.50),
    const MosaicPoint(0.45, 0.48),
    const MosaicPoint(0.50, 0.52),
    const MosaicPoint(0.55, 0.48),
    const MosaicPoint(0.60, 0.50),
  ];
  final bounds = boundsForMosaicBrush(points, brushSizeRatio);
  return MosaicRegion(
    id: id,
    left: bounds.left,
    top: bounds.top,
    width: bounds.width,
    height: bounds.height,
    shape: MosaicShape.brush,
    points: points,
    brushSizeRatio: brushSizeRatio,
  );
}

MosaicRegion createFullImageMosaicRegion({
  required String id,
  required double brushSizeRatio,
}) {
  return MosaicRegion(
    id: id,
    left: 0,
    top: 0,
    width: 1,
    height: 1,
    shape: MosaicShape.roundedRectangle,
    brushSizeRatio: brushSizeRatio,
  );
}

MosaicRegion duplicateMosaicRegion({
  required MosaicRegion selected,
  required String id,
}) {
  if (selected.shape == MosaicShape.brush) {
    final points = <MosaicPoint>[
      for (final point in selected.points) point.translated(0.025, 0.025),
    ];
    final bounds = boundsForMosaicBrush(points, selected.brushSizeRatio);
    return selected.copyWith(
      id: id,
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
      points: points,
      locked: false,
    );
  }
  return selected.copyWith(
    id: id,
    left: (selected.left + 0.025).clamp(0.0, 1.0 - selected.width).toDouble(),
    top: (selected.top + 0.025).clamp(0.0, 1.0 - selected.height).toDouble(),
    locked: false,
  );
}

MosaicRegion changeMosaicRegionShape({
  required MosaicRegion selected,
  required MosaicShape shape,
  required double defaultBrushSizeRatio,
}) {
  var next = selected.copyWith(shape: shape);
  if (shape == MosaicShape.brush && selected.points.isEmpty) {
    final centerY = selected.top + selected.height / 2;
    final points = <MosaicPoint>[
      MosaicPoint(selected.left + selected.width * 0.15, centerY),
      MosaicPoint(selected.left + selected.width * 0.5, centerY),
      MosaicPoint(selected.left + selected.width * 0.85, centerY),
    ];
    final bounds = boundsForMosaicBrush(points, defaultBrushSizeRatio);
    next = next.copyWith(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
      points: points,
      brushSizeRatio: defaultBrushSizeRatio,
    );
  }
  return next;
}

MosaicRegion resizeMosaicBrushRegion({
  required MosaicRegion selected,
  required double brushSizeRatio,
}) {
  final bounds = boundsForMosaicBrush(selected.points, brushSizeRatio);
  return selected.copyWith(
    left: bounds.left,
    top: bounds.top,
    width: bounds.width,
    height: bounds.height,
    brushSizeRatio: brushSizeRatio,
  );
}

MosaicRegion? moveMosaicRegion({
  required MosaicRegion selected,
  required Offset delta,
}) {
  if (selected.shape == MosaicShape.brush) {
    if (selected.points.isEmpty) return null;
    var minX = selected.points.first.x;
    var maxX = selected.points.first.x;
    var minY = selected.points.first.y;
    var maxY = selected.points.first.y;
    for (final point in selected.points.skip(1)) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
    }
    final dx = delta.dx.clamp(-minX, 1 - maxX).toDouble();
    final dy = delta.dy.clamp(-minY, 1 - maxY).toDouble();
    final points = <MosaicPoint>[
      for (final point in selected.points)
        MosaicPoint(point.x + dx, point.y + dy),
    ];
    final bounds = boundsForMosaicBrush(points, selected.brushSizeRatio);
    return selected.copyWith(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
      points: points,
    );
  }
  return selected.copyWith(
    left: (selected.left + delta.dx)
        .clamp(0.0, 1.0 - selected.width)
        .toDouble(),
    top: (selected.top + delta.dy).clamp(0.0, 1.0 - selected.height).toDouble(),
  );
}

Rect boundsForMosaicBrush(List<MosaicPoint> points, double sizeRatio) {
  if (points.isEmpty) return Rect.zero;
  var left = points.first.x;
  var top = points.first.y;
  var right = points.first.x;
  var bottom = points.first.y;
  for (final point in points.skip(1)) {
    left = math.min(left, point.x);
    top = math.min(top, point.y);
    right = math.max(right, point.x);
    bottom = math.max(bottom, point.y);
  }
  final radius = sizeRatio / 2;
  return Rect.fromLTRB(
    (left - radius).clamp(0.0, 1.0).toDouble(),
    (top - radius).clamp(0.0, 1.0).toDouble(),
    (right + radius).clamp(0.0, 1.0).toDouble(),
    (bottom + radius).clamp(0.0, 1.0).toDouble(),
  );
}

String mosaicPercentText(double value) =>
    '${(value * 100).toStringAsFixed(0)}%';

KeyEventResult handleMosaicPreviewKeyEvent({
  required KeyEvent event,
  required bool saving,
  required VoidCallback onUndo,
  required VoidCallback onRedo,
  required VoidCallback onDuplicate,
  required VoidCallback onDelete,
  required ValueChanged<Offset> onMove,
}) {
  if (saving) return KeyEventResult.ignored;
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final key = event.logicalKey;
  final keyboard = HardwareKeyboard.instance;
  final command = keyboard.isControlPressed || keyboard.isMetaPressed;
  if (command && key == LogicalKeyboardKey.keyZ) {
    if (keyboard.isShiftPressed) {
      onRedo();
    } else {
      onUndo();
    }
    return KeyEventResult.handled;
  }
  if (command && key == LogicalKeyboardKey.keyY) {
    onRedo();
    return KeyEventResult.handled;
  }
  if (command && key == LogicalKeyboardKey.keyD) {
    onDuplicate();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
    onDelete();
    return KeyEventResult.handled;
  }
  var delta = Offset.zero;
  final step = keyboard.isShiftPressed ? 0.01 : 0.002;
  if (key == LogicalKeyboardKey.arrowLeft) delta = Offset(-step, 0);
  if (key == LogicalKeyboardKey.arrowRight) delta = Offset(step, 0);
  if (key == LogicalKeyboardKey.arrowUp) delta = Offset(0, -step);
  if (key == LogicalKeyboardKey.arrowDown) delta = Offset(0, step);
  if (delta == Offset.zero) return KeyEventResult.ignored;
  onMove(delta);
  return KeyEventResult.handled;
}
