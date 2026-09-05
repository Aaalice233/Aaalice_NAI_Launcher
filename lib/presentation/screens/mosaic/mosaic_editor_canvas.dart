import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/mosaic/mosaic_render_service.dart';
import '../../../data/models/mosaic/mosaic_settings.dart';

class MosaicEditorCanvas extends StatefulWidget {
  const MosaicEditorCanvas({
    super.key,
    required this.source,
    required this.processed,
    required this.settings,
    required this.regions,
    required this.selectedId,
    required this.drawShape,
    required this.selectionColor,
    required this.backgroundColor,
    required this.onSelected,
    required this.onBeginRegionTransform,
    required this.onRegionChanged,
    required this.onRegionCreated,
    required this.onFocusRequested,
  });

  final ui.Image source;
  final ui.Image? processed;
  final MosaicSettings settings;
  final List<MosaicRegion> regions;
  final String? selectedId;
  final MosaicShape drawShape;
  final Color selectionColor;
  final Color backgroundColor;
  final ValueChanged<String?> onSelected;
  final VoidCallback onBeginRegionTransform;
  final ValueChanged<MosaicRegion> onRegionChanged;
  final void Function(
    MosaicShape shape,
    Rect normalizedRect,
    List<MosaicPoint> points,
  )
  onRegionCreated;
  final VoidCallback onFocusRequested;

  @override
  State<MosaicEditorCanvas> createState() => _MosaicEditorCanvasState();
}

enum _DragMode {
  none,
  move,
  resizeTopLeft,
  resizeTopRight,
  resizeBottomLeft,
  resizeBottomRight,
  draw,
  brush,
}

class _MosaicEditorCanvasState extends State<MosaicEditorCanvas> {
  _DragMode _dragMode = _DragMode.none;
  MosaicRegion? _startRegion;
  Offset? _startPoint;
  Rect? _draftRect;
  List<MosaicPoint> _brushPoints = const <MosaicPoint>[];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(
          math.max(1.0, constraints.maxWidth),
          math.max(1.0, constraints.maxHeight),
        );
        final imageRect = imageRectFor(viewport, widget.source);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            final selected = _selectedRegion();
            // Resolve handles before pan recognition moves beyond their bounds.
            _dragMode =
                selected != null &&
                    !selected.locked &&
                    selected.shape != MosaicShape.brush
                ? _hitHandle(details.localPosition, imageRect, selected)
                : _DragMode.none;
          },
          onTapDown: (_) => widget.onFocusRequested(),
          onTapUp: (details) {
            final selected = _selectedRegion();
            if (selected != null &&
                !selected.locked &&
                selected.shape != MosaicShape.brush &&
                _hitHandle(details.localPosition, imageRect, selected) !=
                    _DragMode.none) {
              return;
            }
            if (!imageRect.contains(details.localPosition)) {
              widget.onSelected(null);
              return;
            }
            widget.onSelected(
              _hitRegion(details.localPosition, imageRect, widget.regions)?.id,
            );
          },
          onPanStart: (details) => _startGesture(details, imageRect),
          onPanUpdate: (details) => _updateGesture(details, imageRect),
          onPanEnd: (_) => _finishGesture(),
          onPanCancel: _cancelGesture,
          child: CustomPaint(
            painter: _MosaicCanvasPainter(
              source: widget.source,
              processed: widget.processed,
              settings: widget.settings,
              regions: widget.regions,
              selectedId: widget.selectedId,
              draftRect: _draftRect,
              brushPoints: _brushPoints,
              drawShape: widget.drawShape,
              selectionColor: widget.selectionColor,
              backgroundColor: widget.backgroundColor,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _startGesture(DragStartDetails details, Rect imageRect) {
    widget.onFocusRequested();
    final point = _normalize(details.localPosition, imageRect);
    final selected = _selectedRegion();
    if (selected != null &&
        selected.shape != MosaicShape.brush &&
        !selected.locked) {
      final handle = _dragMode;
      if (handle != _DragMode.none) {
        _dragMode = handle;
        _startPoint = point;
        _startRegion = selected;
        widget.onBeginRegionTransform();
        return;
      }
    }

    if (!imageRect.contains(details.localPosition)) return;
    final hit = _hitRegion(details.localPosition, imageRect, widget.regions);
    if (hit != null) {
      widget.onSelected(hit.id);
      if (!hit.locked) {
        _dragMode = _DragMode.move;
        _startPoint = point;
        _startRegion = hit;
        widget.onBeginRegionTransform();
      }
      return;
    }

    widget.onSelected(null);
    _startPoint = point;
    if (widget.drawShape == MosaicShape.brush) {
      _dragMode = _DragMode.brush;
      _brushPoints = <MosaicPoint>[MosaicPoint(point.dx, point.dy)];
    } else {
      _dragMode = _DragMode.draw;
      _draftRect = Rect.fromLTWH(point.dx, point.dy, 0, 0);
    }
    setState(() {});
  }

  void _updateGesture(DragUpdateDetails details, Rect imageRect) {
    final startPoint = _startPoint;
    if (_dragMode == _DragMode.none || startPoint == null) return;
    final point = _normalize(details.localPosition, imageRect);

    if (_dragMode == _DragMode.draw) {
      setState(() => _draftRect = _rectFromPoints(startPoint, point));
      return;
    }
    if (_dragMode == _DragMode.brush) {
      final next = MosaicPoint(point.dx, point.dy);
      final previous = _brushPoints.last;
      final dx = next.x - previous.x;
      final dy = next.y - previous.y;
      if (math.sqrt(dx * dx + dy * dy) >= 0.002) {
        setState(() => _brushPoints = <MosaicPoint>[..._brushPoints, next]);
      }
      return;
    }

    final region = _startRegion;
    if (region == null) return;
    if (_dragMode == _DragMode.move) {
      widget.onRegionChanged(
        _translateRegion(
          region,
          point.dx - startPoint.dx,
          point.dy - startPoint.dy,
        ),
      );
      return;
    }
    widget.onRegionChanged(_resizeRegion(region, point, _dragMode));
  }

  void _finishGesture() {
    final mode = _dragMode;
    final draft = _draftRect;
    final points = _brushPoints;
    if (mode == _DragMode.draw &&
        draft != null &&
        draft.width >= 0.01 &&
        draft.height >= 0.01) {
      widget.onRegionCreated(widget.drawShape, draft, const <MosaicPoint>[]);
    } else if (mode == _DragMode.brush && points.isNotEmpty) {
      widget.onRegionCreated(
        MosaicShape.brush,
        brushBounds(points, widget.settings.brushSizeRatio),
        points,
      );
    }
    _cancelGesture();
  }

  void _cancelGesture() {
    if (!mounted) return;
    setState(() {
      _dragMode = _DragMode.none;
      _startRegion = null;
      _startPoint = null;
      _draftRect = null;
      _brushPoints = const <MosaicPoint>[];
    });
  }

  MosaicRegion? _selectedRegion() {
    final selectedId = widget.selectedId;
    if (selectedId == null) return null;
    for (final region in widget.regions) {
      if (region.id == selectedId) return region;
    }
    return null;
  }

  static Rect imageRectFor(Size viewport, ui.Image source) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(source.width.toDouble(), source.height.toDouble()),
      viewport,
    );
    return Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & viewport,
    );
  }

  static Offset _normalize(Offset point, Rect imageRect) => Offset(
    ((point.dx - imageRect.left) / imageRect.width).clamp(0.0, 1.0).toDouble(),
    ((point.dy - imageRect.top) / imageRect.height).clamp(0.0, 1.0).toDouble(),
  );

  static Rect _rectFromPoints(Offset a, Offset b) => Rect.fromLTRB(
    math.min(a.dx, b.dx),
    math.min(a.dy, b.dy),
    math.max(a.dx, b.dx),
    math.max(a.dy, b.dy),
  );

  static Rect brushBounds(List<MosaicPoint> points, double sizeRatio) {
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

  MosaicRegion? _hitRegion(
    Offset position,
    Rect imageRect,
    List<MosaicRegion> regions,
  ) {
    final normalized = _normalize(position, imageRect);
    for (final region in regions.reversed) {
      if (region.shape == MosaicShape.brush) {
        final radiusPixels =
            math.min(imageRect.width, imageRect.height) *
                region.brushSizeRatio /
                2 +
            8;
        for (final point in region.points) {
          final pixel = Offset(
            imageRect.left + point.x * imageRect.width,
            imageRect.top + point.y * imageRect.height,
          );
          if ((pixel - position).distance <= radiusPixels) return region;
        }
        continue;
      }
      final rect = Rect.fromLTWH(
        region.left,
        region.top,
        region.width,
        region.height,
      );
      if (!rect.contains(normalized)) continue;
      if (region.shape == MosaicShape.ellipse) {
        final dx = (normalized.dx - rect.center.dx) / (rect.width / 2);
        final dy = (normalized.dy - rect.center.dy) / (rect.height / 2);
        if (dx * dx + dy * dy > 1) continue;
      }
      return region;
    }
    return null;
  }

  _DragMode _hitHandle(Offset position, Rect imageRect, MosaicRegion region) {
    final rect = Rect.fromLTWH(
      imageRect.left + region.left * imageRect.width,
      imageRect.top + region.top * imageRect.height,
      region.width * imageRect.width,
      region.height * imageRect.height,
    );
    const radius = 14.0;
    if ((position - rect.topLeft).distance <= radius) {
      return _DragMode.resizeTopLeft;
    }
    if ((position - rect.topRight).distance <= radius) {
      return _DragMode.resizeTopRight;
    }
    if ((position - rect.bottomLeft).distance <= radius) {
      return _DragMode.resizeBottomLeft;
    }
    if ((position - rect.bottomRight).distance <= radius) {
      return _DragMode.resizeBottomRight;
    }
    return _DragMode.none;
  }

  MosaicRegion _translateRegion(MosaicRegion region, double dx, double dy) {
    if (region.shape == MosaicShape.brush && region.points.isNotEmpty) {
      var minX = region.points.first.x;
      var maxX = region.points.first.x;
      var minY = region.points.first.y;
      var maxY = region.points.first.y;
      for (final point in region.points.skip(1)) {
        minX = math.min(minX, point.x);
        maxX = math.max(maxX, point.x);
        minY = math.min(minY, point.y);
        maxY = math.max(maxY, point.y);
      }
      // Edge-spanning strokes already extend beyond the canvas by their radius.
      // Constrain their centers without creating an inverted clamp interval.
      final safeDx = dx.clamp(-minX, 1 - maxX).toDouble();
      final safeDy = dy.clamp(-minY, 1 - maxY).toDouble();
      final translated = [
        for (final point in region.points)
          MosaicPoint(point.x + safeDx, point.y + safeDy),
      ];
      final bounds = brushBounds(translated, region.brushSizeRatio);
      return region.copyWith(
        left: bounds.left,
        top: bounds.top,
        width: bounds.width,
        height: bounds.height,
        points: translated,
      );
    }
    return region
        .copyWith(
          left: (region.left + dx).clamp(0.0, 1.0 - region.width).toDouble(),
          top: (region.top + dy).clamp(0.0, 1.0 - region.height).toDouble(),
        )
        .normalized();
  }

  static MosaicRegion _resizeRegion(
    MosaicRegion region,
    Offset point,
    _DragMode mode,
  ) {
    var left = region.left;
    var top = region.top;
    var right = region.left + region.width;
    var bottom = region.top + region.height;
    if (mode == _DragMode.resizeTopLeft) {
      left = point.dx;
      top = point.dy;
    } else if (mode == _DragMode.resizeTopRight) {
      right = point.dx;
      top = point.dy;
    } else if (mode == _DragMode.resizeBottomLeft) {
      left = point.dx;
      bottom = point.dy;
    } else if (mode == _DragMode.resizeBottomRight) {
      right = point.dx;
      bottom = point.dy;
    } else {
      return region;
    }

    const minimum = 0.015;
    if (right - left < minimum) {
      if (mode == _DragMode.resizeTopLeft ||
          mode == _DragMode.resizeBottomLeft) {
        left = right - minimum;
      } else {
        right = left + minimum;
      }
    }
    if (bottom - top < minimum) {
      if (mode == _DragMode.resizeTopLeft || mode == _DragMode.resizeTopRight) {
        top = bottom - minimum;
      } else {
        bottom = top + minimum;
      }
    }

    left = left.clamp(0.0, 1.0).toDouble();
    top = top.clamp(0.0, 1.0).toDouble();
    right = right.clamp(0.0, 1.0).toDouble();
    bottom = bottom.clamp(0.0, 1.0).toDouble();
    if (right - left < minimum) {
      if (left + minimum <= 1) {
        right = left + minimum;
      } else {
        left = right - minimum;
      }
    }
    if (bottom - top < minimum) {
      if (top + minimum <= 1) {
        bottom = top + minimum;
      } else {
        top = bottom - minimum;
      }
    }
    return region.copyWith(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
    );
  }
}

class _MosaicCanvasPainter extends CustomPainter {
  const _MosaicCanvasPainter({
    required this.source,
    required this.processed,
    required this.settings,
    required this.regions,
    required this.selectedId,
    required this.draftRect,
    required this.brushPoints,
    required this.drawShape,
    required this.selectionColor,
    required this.backgroundColor,
  });

  final ui.Image source;
  final ui.Image? processed;
  final MosaicSettings settings;
  final List<MosaicRegion> regions;
  final String? selectedId;
  final Rect? draftRect;
  final List<MosaicPoint> brushPoints;
  final MosaicShape drawShape;
  final Color selectionColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final imageRect = _MosaicEditorCanvasState.imageRectFor(size, source);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      imageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    canvas.save();
    canvas.clipRect(imageRect);
    canvas.translate(imageRect.left, imageRect.top);
    final localSize = imageRect.size;
    final localBounds = Offset.zero & localSize;
    final mask = MosaicRenderService.buildMaskPath(
      size: localSize,
      settings: settings,
      regions: regions,
    );
    canvas.save();
    canvas.clipPath(mask, doAntiAlias: true);
    final alpha = (settings.opacity * 255).round().clamp(0, 255).toInt();
    if (settings.effect == MosaicEffect.solid) {
      canvas.drawRect(
        localBounds,
        Paint()..color = Color(settings.fillColorArgb).withAlpha(alpha),
      );
    } else if (processed != null) {
      canvas.drawImageRect(
        processed!,
        Rect.fromLTWH(
          0,
          0,
          processed!.width.toDouble(),
          processed!.height.toDouble(),
        ),
        localBounds,
        Paint()
          ..color = Color.fromARGB(alpha, 255, 255, 255)
          ..filterQuality = settings.effect == MosaicEffect.pixelate
              ? FilterQuality.none
              : FilterQuality.medium,
      );
    }
    canvas.restore();

    for (var index = 0; index < regions.length; index++) {
      _paintRegionGuide(canvas, localSize, regions[index], index + 1);
    }
    if (draftRect != null) {
      _paintDraftShape(canvas, localSize, draftRect!);
    }
    if (brushPoints.isNotEmpty) {
      _paintBrushDraft(canvas, localSize, brushPoints);
    }
    canvas.restore();
  }

  void _paintRegionGuide(
    Canvas canvas,
    Size size,
    MosaicRegion region,
    int number,
  ) {
    final selected = region.id == selectedId;
    final guideColor = selected
        ? selectionColor
        : region.enabled
        ? Colors.white.withValues(alpha: 0.78)
        : Colors.grey.withValues(alpha: 0.78);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.4 : 1.3
      ..color = guideColor;

    if (region.shape == MosaicShape.brush) {
      if (region.points.isNotEmpty) {
        final path = Path()
          ..moveTo(
            region.points.first.x * size.width,
            region.points.first.y * size.height,
          );
        for (final point in region.points.skip(1)) {
          path.lineTo(point.x * size.width, point.y * size.height);
        }
        canvas.drawPath(
          path,
          paint
            ..strokeWidth = selected ? 3.2 : 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    } else {
      final rect = Rect.fromLTWH(
        region.left * size.width,
        region.top * size.height,
        region.width * size.width,
        region.height * size.height,
      );
      if (region.shape == MosaicShape.ellipse) {
        canvas.drawOval(rect, paint);
      } else {
        final radius = region.coversFullImage
            ? 0.0
            : math.min(rect.width, rect.height) * settings.cornerRadiusRatio;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          paint,
        );
      }
      if (selected && !region.locked) _paintHandles(canvas, rect);
    }

    if (settings.showRegionLabels) {
      final anchor =
          region.shape == MosaicShape.brush && region.points.isNotEmpty
          ? Offset(
              region.points.first.x * size.width,
              region.points.first.y * size.height,
            )
          : Offset(region.left * size.width, region.top * size.height);
      _paintLabel(canvas, anchor, number, region.locked, guideColor);
    }
  }

  void _paintHandles(Canvas canvas, Rect rect) {
    for (final point in <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(point, 5, Paint()..color = selectionColor);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    Offset anchor,
    int number,
    bool locked,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: locked ? '$number L' : '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
      anchor.dx + 4,
      anchor.dy + 4,
      textPainter.width + 10,
      textPainter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.9),
    );
    textPainter.paint(canvas, Offset(rect.left + 5, rect.top + 3));
  }

  void _paintDraftShape(Canvas canvas, Size size, Rect normalized) {
    final rect = Rect.fromLTWH(
      normalized.left * size.width,
      normalized.top * size.height,
      normalized.width * size.width,
      normalized.height * size.height,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = selectionColor;
    if (drawShape == MosaicShape.ellipse) {
      canvas.drawOval(rect, paint);
    } else {
      final radius =
          math.min(rect.width, rect.height) * settings.cornerRadiusRatio;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }
    canvas.drawRect(
      rect,
      Paint()..color = selectionColor.withValues(alpha: 0.12),
    );
  }

  void _paintBrushDraft(Canvas canvas, Size size, List<MosaicPoint> points) {
    final path = Path()
      ..moveTo(points.first.x * size.width, points.first.y * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            math.min(size.width, size.height) * settings.brushSizeRatio
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = selectionColor.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _MosaicCanvasPainter oldDelegate) =>
      oldDelegate.source != source ||
      oldDelegate.processed != processed ||
      oldDelegate.settings != settings ||
      oldDelegate.regions != regions ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.draftRect != draftRect ||
      oldDelegate.brushPoints != brushPoints ||
      oldDelegate.drawShape != drawShape ||
      oldDelegate.selectionColor != selectionColor ||
      oldDelegate.backgroundColor != backgroundColor;
}
