import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/utils/inpaint_outpaint_utils.dart';
import '../core/canvas_controller.dart';

typedef OutpaintEdgeDragPreviewChanged = void Function(OutpaintEdges edges);
typedef OutpaintEdgeDragCommitted =
    Future<void> Function(
      OutpaintEdges edges, {
      required OutpaintHorizontalSnapTarget horizontalSnapTarget,
      required OutpaintVerticalSnapTarget verticalSnapTarget,
    });
typedef OutpaintFrameResizeCommitted =
    Future<void> Function(
      OutpaintFrameDelta delta, {
      required OutpaintHorizontalSnapTarget horizontalSnapTarget,
      required OutpaintVerticalSnapTarget verticalSnapTarget,
    });

class OutpaintEdgeDragOverlay extends StatefulWidget {
  static const double edgeHitSlop = 48;
  static const double handleSize = 22;
  static const double cornerHandleSize = 24;

  final Size canvasSize;
  final CanvasController controller;
  final OutpaintEdgeDragPreviewChanged? onPreviewChanged;
  final OutpaintEdgeDragCommitted onCommitted;
  final OutpaintFrameResizeCommitted? onFrameResizeCommitted;
  final bool enabled;

  const OutpaintEdgeDragOverlay({
    super.key,
    required this.canvasSize,
    required this.controller,
    this.onPreviewChanged,
    required this.onCommitted,
    this.onFrameResizeCommitted,
    this.enabled = true,
  });

  static bool isResizeInteractionPoint({
    required Offset localPosition,
    required Size viewportSize,
    required Size canvasSize,
    required CanvasController controller,
  }) {
    if (controller.rotation != 0 || controller.isMirroredHorizontally) {
      return false;
    }

    final canvasRect = _screenCanvasRectFor(
      controller: controller,
      canvasSize: canvasSize,
    );
    // 手柄可能被 clamp 到视口边缘、落在边缘条之外，必须一并算作拖拽热区，
    // 否则画布会在手柄上开始一笔，和拖拽同时发生。
    return [
      ..._resizeZoneRects(canvasRect, viewportSize),
      ..._handleSpecsFor(canvasRect).map((spec) => spec.rect(viewportSize)),
    ].any((rect) => rect.contains(localPosition));
  }

  static List<_OutpaintHandleSpec> _handleSpecsFor(Rect canvasRect) {
    return [
      _OutpaintHandleSpec(
        _OutpaintDragHandle.left,
        Offset(canvasRect.left, canvasRect.center.dy),
      ),
      _OutpaintHandleSpec(
        _OutpaintDragHandle.right,
        Offset(canvasRect.right, canvasRect.center.dy),
      ),
      _OutpaintHandleSpec(
        _OutpaintDragHandle.top,
        Offset(canvasRect.center.dx, canvasRect.top),
      ),
      _OutpaintHandleSpec(
        _OutpaintDragHandle.bottom,
        Offset(canvasRect.center.dx, canvasRect.bottom),
      ),
      _OutpaintHandleSpec(
        _OutpaintDragHandle.topLeft,
        canvasRect.topLeft,
        isCorner: true,
      ),
      _OutpaintHandleSpec(
        _OutpaintDragHandle.topRight,
        canvasRect.topRight,
        isCorner: true,
      ),
      _OutpaintHandleSpec(
        _OutpaintDragHandle.bottomLeft,
        canvasRect.bottomLeft,
        isCorner: true,
      ),
      _OutpaintHandleSpec(
        _OutpaintDragHandle.bottomRight,
        canvasRect.bottomRight,
        isCorner: true,
      ),
    ];
  }

  static Offset _clampHandleCenter(
    Offset center,
    double size,
    Size viewportSize,
  ) {
    final halfSize = size / 2;
    final maxX = math.max(halfSize, viewportSize.width - halfSize);
    final maxY = math.max(halfSize, viewportSize.height - halfSize);
    return Offset(
      center.dx.clamp(halfSize, maxX).toDouble(),
      center.dy.clamp(halfSize, maxY).toDouble(),
    );
  }

  static Rect _screenCanvasRectFor({
    required CanvasController controller,
    required Size canvasSize,
  }) {
    final topLeft = controller.canvasToScreen(
      Offset.zero,
      canvasSize: canvasSize,
    );
    final bottomRight = controller.canvasToScreen(
      Offset(canvasSize.width, canvasSize.height),
      canvasSize: canvasSize,
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  static List<Rect> _resizeZoneRects(Rect canvasRect, Size viewportSize) {
    return [
      _clampZoneRect(
        Rect.fromLTRB(
          canvasRect.left - edgeHitSlop / 2,
          canvasRect.top,
          canvasRect.left + edgeHitSlop / 2,
          canvasRect.bottom,
        ),
        viewportSize,
      ),
      _clampZoneRect(
        Rect.fromLTRB(
          canvasRect.right - edgeHitSlop / 2,
          canvasRect.top,
          canvasRect.right + edgeHitSlop / 2,
          canvasRect.bottom,
        ),
        viewportSize,
      ),
      _clampZoneRect(
        Rect.fromLTRB(
          canvasRect.left,
          canvasRect.top - edgeHitSlop / 2,
          canvasRect.right,
          canvasRect.top + edgeHitSlop / 2,
        ),
        viewportSize,
      ),
      _clampZoneRect(
        Rect.fromLTRB(
          canvasRect.left,
          canvasRect.bottom - edgeHitSlop / 2,
          canvasRect.right,
          canvasRect.bottom + edgeHitSlop / 2,
        ),
        viewportSize,
      ),
    ].where((rect) => !rect.isEmpty).toList();
  }

  static Rect _clampZoneRect(Rect rect, Size viewportSize) {
    final left = rect.left.clamp(0.0, viewportSize.width).toDouble();
    final top = rect.top.clamp(0.0, viewportSize.height).toDouble();
    final right = rect.right.clamp(0.0, viewportSize.width).toDouble();
    final bottom = rect.bottom.clamp(0.0, viewportSize.height).toDouble();
    if (right <= left || bottom <= top) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  State<OutpaintEdgeDragOverlay> createState() =>
      _OutpaintEdgeDragOverlayState();
}

class _OutpaintEdgeDragOverlayState extends State<OutpaintEdgeDragOverlay> {
  _OutpaintDragHandle? _activeHandle;
  _OutpaintDragHandle? _hoveredHandle;
  int? _activePointer;
  Offset? _lastGlobalPosition;
  Offset _dragDelta = Offset.zero;
  OutpaintFrameDelta _previewDelta = const OutpaintFrameDelta();
  OutpaintFrameResolvedGeometry? _previewGeometry;
  _OutpaintPreviewGeometryKey? _visiblePreviewKey;
  bool _previewUpdateScheduled = false;
  bool _isCommitting = false;
  Timer? _outsideCommitTimer;

  bool get _canRenderOverlay =>
      widget.controller.rotation == 0 &&
      !widget.controller.isMirroredHorizontally;

  bool get _canShowHandles =>
      _canRenderOverlay && widget.enabled && !_isCommitting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            if (!_canRenderOverlay) {
              return const SizedBox.shrink();
            }

            final canvasRect = _screenCanvasRect;
            final preview = _activeHandle == null ? null : _previewGeometry;
            final highlightedHandle = _activeHandle ?? _hoveredHandle;

            return MouseRegion(
              opaque: false,
              hitTestBehavior: HitTestBehavior.deferToChild,
              onExit: (_) {
                if (_activeHandle != null && _hasVisiblePreview) {
                  _scheduleOutsideCommit();
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (preview != null && preview.hasAppliedChange)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _OutpaintEdgePreviewPainter(
                              canvasRect: canvasRect,
                              preview: preview,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (preview != null && preview.hasAppliedChange)
                    _PreviewLabel(
                      canvasRect: canvasRect,
                      handle: _activeHandle!,
                      preview: preview,
                      viewportSize: viewportSize,
                    ),
                  if (highlightedHandle != null)
                    Positioned.fill(
                      key: Key(
                        'outpaint_highlight_${highlightedHandle.keySuffix}',
                      ),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _OutpaintEdgeHighlightPainter(
                            canvasRect: canvasRect,
                            handle: highlightedHandle,
                          ),
                        ),
                      ),
                    ),
                  if (_canShowHandles)
                    ..._buildEdgeZones(canvasRect, viewportSize),
                  if (_canShowHandles)
                    ..._buildHandles(canvasRect, viewportSize),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool get _hasVisiblePreview => _previewGeometry?.hasAppliedChange == true;

  Rect get _screenCanvasRect {
    return OutpaintEdgeDragOverlay._screenCanvasRectFor(
      controller: widget.controller,
      canvasSize: widget.canvasSize,
    );
  }

  List<Widget> _buildHandles(Rect canvasRect, Size viewportSize) {
    return OutpaintEdgeDragOverlay._handleSpecsFor(
      canvasRect,
    ).map((spec) => _buildHandle(spec, viewportSize)).toList();
  }

  List<Widget> _buildEdgeZones(Rect canvasRect, Size viewportSize) {
    return [
      _buildEdgeZone(
        key: const Key('outpaint_edge_left'),
        handle: _OutpaintDragHandle.left,
        rect: Rect.fromLTRB(
          canvasRect.left - OutpaintEdgeDragOverlay.edgeHitSlop / 2,
          canvasRect.top,
          canvasRect.left + OutpaintEdgeDragOverlay.edgeHitSlop / 2,
          canvasRect.bottom,
        ),
        viewportSize: viewportSize,
      ),
      _buildEdgeZone(
        key: const Key('outpaint_edge_right'),
        handle: _OutpaintDragHandle.right,
        rect: Rect.fromLTRB(
          canvasRect.right - OutpaintEdgeDragOverlay.edgeHitSlop / 2,
          canvasRect.top,
          canvasRect.right + OutpaintEdgeDragOverlay.edgeHitSlop / 2,
          canvasRect.bottom,
        ),
        viewportSize: viewportSize,
      ),
      _buildEdgeZone(
        key: const Key('outpaint_edge_top'),
        handle: _OutpaintDragHandle.top,
        rect: Rect.fromLTRB(
          canvasRect.left,
          canvasRect.top - OutpaintEdgeDragOverlay.edgeHitSlop / 2,
          canvasRect.right,
          canvasRect.top + OutpaintEdgeDragOverlay.edgeHitSlop / 2,
        ),
        viewportSize: viewportSize,
      ),
      _buildEdgeZone(
        key: const Key('outpaint_edge_bottom'),
        handle: _OutpaintDragHandle.bottom,
        rect: Rect.fromLTRB(
          canvasRect.left,
          canvasRect.bottom - OutpaintEdgeDragOverlay.edgeHitSlop / 2,
          canvasRect.right,
          canvasRect.bottom + OutpaintEdgeDragOverlay.edgeHitSlop / 2,
        ),
        viewportSize: viewportSize,
      ),
    ];
  }

  Widget _buildEdgeZone({
    required Key key,
    required _OutpaintDragHandle handle,
    required Rect rect,
    required Size viewportSize,
  }) {
    final clampedRect = _clampZoneRect(rect, viewportSize);
    if (clampedRect.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned.fromRect(
      rect: clampedRect,
      child: MouseRegion(
        key: key,
        // 不能挡住画布的 MouseRegion 与 hover 事件，否则画笔光标会在画布边缘消失再重现
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: handle.cursor,
        onEnter: (_) => _setHoveredHandle(handle),
        onExit: (_) => _clearHoveredHandle(handle),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _handlePointerDown(event, handle),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildHandle(_OutpaintHandleSpec spec, Size viewportSize) {
    final handle = spec.handle;
    final isCorner = spec.isCorner;
    return Positioned.fromRect(
      rect: spec.rect(viewportSize),
      child: MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: handle.cursor,
        onEnter: (_) => _setHoveredHandle(handle),
        onExit: (_) => _clearHoveredHandle(handle),
        child: Listener(
          key: spec.key,
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _handlePointerDown(event, handle),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(isCorner ? 6 : 999),
              border: Border.all(
                color: Theme.of(context).colorScheme.onPrimary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event, _OutpaintDragHandle handle) {
    if (!widget.enabled || _isCommitting || _activePointer != null) {
      return;
    }

    _activePointer = event.pointer;
    _lastGlobalPosition = event.position;
    GestureBinding.instance.pointerRouter.addRoute(
      event.pointer,
      _handleRoutedPointerEvent,
    );
    _startDrag(handle);
  }

  void _handleRoutedPointerEvent(PointerEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }

    if (event is PointerMoveEvent) {
      final previousPosition = _lastGlobalPosition ?? event.position;
      _lastGlobalPosition = event.position;
      _updateDrag(
        event.position - previousPosition,
        globalPosition: event.position,
      );
      return;
    }

    if (event is PointerUpEvent) {
      _stopPointerRoute();
      unawaited(_commitDrag());
      return;
    }

    if (event is PointerCancelEvent) {
      _stopPointerRoute();
      unawaited(_commitDrag());
    }
  }

  void _stopPointerRoute() {
    final activePointer = _activePointer;
    if (activePointer != null) {
      GestureBinding.instance.pointerRouter.removeRoute(
        activePointer,
        _handleRoutedPointerEvent,
      );
    }
    _activePointer = null;
    _lastGlobalPosition = null;
  }

  Rect _clampZoneRect(Rect rect, Size viewportSize) {
    return OutpaintEdgeDragOverlay._clampZoneRect(rect, viewportSize);
  }

  void _setHoveredHandle(_OutpaintDragHandle handle) {
    if (_hoveredHandle == handle || _activeHandle != null) {
      return;
    }
    setState(() {
      _hoveredHandle = handle;
    });
  }

  void _clearHoveredHandle(_OutpaintDragHandle handle) {
    if (_hoveredHandle != handle || _activeHandle != null) {
      return;
    }
    setState(() {
      _hoveredHandle = null;
    });
  }

  void _startDrag(_OutpaintDragHandle handle) {
    if (_isCommitting) {
      return;
    }

    setState(() {
      _activeHandle = handle;
      _hoveredHandle = null;
      _dragDelta = Offset.zero;
      _previewDelta = const OutpaintFrameDelta();
      _previewGeometry = null;
      _visiblePreviewKey = null;
    });
  }

  void _updateDrag(Offset delta, {required Offset globalPosition}) {
    if (_isCommitting) {
      return;
    }

    final activeHandle = _activeHandle;
    if (activeHandle == null) {
      return;
    }

    _dragDelta += delta;
    _schedulePreviewUpdate();

    final pendingPreview = _resolveCurrentDragPreview();
    if (pendingPreview != null &&
        pendingPreview.canPreview &&
        pendingPreview.hasAppliedChange &&
        (activeHandle.affectsLeft || _isOutsideOverlay(globalPosition))) {
      _scheduleOutsideCommit();
    } else {
      _outsideCommitTimer?.cancel();
    }
  }

  bool _isOutsideOverlay(Offset globalPosition) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) {
      return false;
    }

    final localPosition = renderBox.globalToLocal(globalPosition);
    return localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > renderBox.size.width ||
        localPosition.dy > renderBox.size.height;
  }

  OutpaintFrameDelta _deltaForDrag(
    _OutpaintDragHandle handle,
    int sourceDx,
    int sourceDy,
  ) {
    return OutpaintFrameDelta(
      left: handle.affectsLeft ? -sourceDx : 0,
      top: handle.affectsTop ? -sourceDy : 0,
      right: handle.affectsRight ? sourceDx : 0,
      bottom: handle.affectsBottom ? sourceDy : 0,
    );
  }

  _ResolvedOutpaintDragPreview? _resolveCurrentDragPreview() {
    final activeHandle = _activeHandle;
    if (activeHandle == null) {
      return null;
    }

    final scale = widget.controller.scale;
    final sourceDx = (_dragDelta.dx / scale).round();
    final sourceDy = (_dragDelta.dy / scale).round();
    final delta = _deltaForDrag(activeHandle, sourceDx, sourceDy);
    final geometry = delta.isEmpty
        ? null
        : _resolvePreviewGeometry(activeHandle, delta);
    return _ResolvedOutpaintDragPreview(
      delta: delta,
      geometry: geometry,
      canPreview: delta.isEmpty || geometry != null,
    );
  }

  void _schedulePreviewUpdate() {
    if (_previewUpdateScheduled) {
      return;
    }

    _previewUpdateScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!_previewUpdateScheduled || !mounted) {
        return;
      }
      _flushPreviewUpdate();
    });
  }

  void _flushPreviewUpdate() {
    _previewUpdateScheduled = false;

    final resolved = _resolveCurrentDragPreview();
    if (resolved == null) {
      return;
    }

    if (!resolved.canPreview || !resolved.hasAppliedChange) {
      final hadVisiblePreview =
          !_previewDelta.isEmpty || _previewGeometry != null;
      _previewDelta = const OutpaintFrameDelta();
      _previewGeometry = null;
      _visiblePreviewKey = null;
      if (hadVisiblePreview && mounted) {
        setState(() {});
      }
      return;
    }

    final geometry = resolved.geometry!;
    final previewKey = _OutpaintPreviewGeometryKey.from(geometry);
    final shouldEmit = previewKey != _visiblePreviewKey;

    _previewDelta = resolved.delta;
    if (!shouldEmit) {
      return;
    }

    _previewGeometry = geometry;
    _visiblePreviewKey = previewKey;
    if (mounted) {
      setState(() {});
      final expansionEdges = resolved.delta.expansionEdges;
      if (!expansionEdges.isEmpty) {
        widget.onPreviewChanged?.call(expansionEdges);
      }
    }
  }

  OutpaintFrameResolvedGeometry? _resolvePreviewGeometry(
    _OutpaintDragHandle handle,
    OutpaintFrameDelta delta,
  ) {
    return InpaintOutpaintUtils.tryResolveFrameGeometry(
      sourceWidth: widget.canvasSize.width.round(),
      sourceHeight: widget.canvasSize.height.round(),
      delta: delta,
      horizontalSnapTarget: _horizontalSnapTarget(handle),
      verticalSnapTarget: _verticalSnapTarget(handle),
    );
  }

  Future<void> _commitDrag() async {
    if (_isCommitting) {
      return;
    }

    _flushPreviewUpdate();
    _stopPointerRoute();
    _outsideCommitTimer?.cancel();

    final activeHandle = _activeHandle;
    final delta = _previewDelta;
    final geometry = _previewGeometry;

    if (activeHandle == null ||
        geometry == null ||
        !geometry.hasAppliedChange) {
      _resetDrag();
      return;
    }

    setState(() {
      _isCommitting = true;
    });

    try {
      final horizontalSnapTarget = _horizontalSnapTarget(activeHandle);
      final verticalSnapTarget = _verticalSnapTarget(activeHandle);
      if (widget.onFrameResizeCommitted != null) {
        await widget.onFrameResizeCommitted!(
          delta,
          horizontalSnapTarget: horizontalSnapTarget,
          verticalSnapTarget: verticalSnapTarget,
        );
      } else if (delta.cropEdges.isEmpty) {
        await widget.onCommitted(
          delta.expansionEdges,
          horizontalSnapTarget: horizontalSnapTarget,
          verticalSnapTarget: verticalSnapTarget,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCommitting = false;
          _activeHandle = null;
          _dragDelta = Offset.zero;
          _previewDelta = const OutpaintFrameDelta();
          _previewGeometry = null;
          _visiblePreviewKey = null;
        });
      }
    }
  }

  void _resetDrag() {
    if (_isCommitting) {
      return;
    }
    _stopPointerRoute();
    _outsideCommitTimer?.cancel();
    _previewUpdateScheduled = false;

    setState(() {
      _activeHandle = null;
      _hoveredHandle = null;
      _dragDelta = Offset.zero;
      _previewDelta = const OutpaintFrameDelta();
      _previewGeometry = null;
      _visiblePreviewKey = null;
    });
  }

  void _scheduleOutsideCommit() {
    if (_isCommitting) {
      return;
    }

    _outsideCommitTimer?.cancel();
    _outsideCommitTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      unawaited(_commitDrag());
    });
  }

  @override
  void dispose() {
    _stopPointerRoute();
    _outsideCommitTimer?.cancel();
    _previewUpdateScheduled = false;
    super.dispose();
  }

  OutpaintHorizontalSnapTarget _horizontalSnapTarget(
    _OutpaintDragHandle handle,
  ) {
    return handle.affectsLeft
        ? OutpaintHorizontalSnapTarget.left
        : OutpaintHorizontalSnapTarget.right;
  }

  OutpaintVerticalSnapTarget _verticalSnapTarget(_OutpaintDragHandle handle) {
    return handle.affectsTop
        ? OutpaintVerticalSnapTarget.top
        : OutpaintVerticalSnapTarget.bottom;
  }
}

/// 手柄几何：拖拽热区判定与实际渲染共用同一份，避免两处 clamp 逻辑漂移
class _OutpaintHandleSpec {
  const _OutpaintHandleSpec(this.handle, this.center, {this.isCorner = false});

  final _OutpaintDragHandle handle;
  final Offset center;
  final bool isCorner;

  double get size => isCorner
      ? OutpaintEdgeDragOverlay.cornerHandleSize
      : OutpaintEdgeDragOverlay.handleSize;

  Key get key => Key('outpaint_handle_${handle.keySuffix}');

  Rect rect(Size viewportSize) {
    final visibleCenter = OutpaintEdgeDragOverlay._clampHandleCenter(
      center,
      size,
      viewportSize,
    );
    return Rect.fromCenter(center: visibleCenter, width: size, height: size);
  }
}

class _ResolvedOutpaintDragPreview {
  final OutpaintFrameDelta delta;
  final OutpaintFrameResolvedGeometry? geometry;
  final bool canPreview;

  const _ResolvedOutpaintDragPreview({
    required this.delta,
    required this.geometry,
    required this.canPreview,
  });

  bool get hasAppliedChange => geometry?.hasAppliedChange == true;
}

class _OutpaintPreviewGeometryKey {
  final int width;
  final int height;
  final int frameLeft;
  final int frameTop;
  final int frameRight;
  final int frameBottom;

  const _OutpaintPreviewGeometryKey({
    required this.width,
    required this.height,
    required this.frameLeft,
    required this.frameTop,
    required this.frameRight,
    required this.frameBottom,
  });

  factory _OutpaintPreviewGeometryKey.from(
    OutpaintFrameResolvedGeometry geometry,
  ) {
    return _OutpaintPreviewGeometryKey(
      width: geometry.width,
      height: geometry.height,
      frameLeft: geometry.appliedFrameLeft,
      frameTop: geometry.appliedFrameTop,
      frameRight: geometry.appliedFrameRight,
      frameBottom: geometry.appliedFrameBottom,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _OutpaintPreviewGeometryKey &&
            width == other.width &&
            height == other.height &&
            frameLeft == other.frameLeft &&
            frameTop == other.frameTop &&
            frameRight == other.frameRight &&
            frameBottom == other.frameBottom;
  }

  @override
  int get hashCode =>
      Object.hash(width, height, frameLeft, frameTop, frameRight, frameBottom);
}

enum _OutpaintDragHandle {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  bool get affectsLeft => this == left || this == topLeft || this == bottomLeft;
  bool get affectsRight =>
      this == right || this == topRight || this == bottomRight;
  bool get affectsTop => this == top || this == topLeft || this == topRight;
  bool get affectsBottom =>
      this == bottom || this == bottomLeft || this == bottomRight;

  String get keySuffix {
    switch (this) {
      case _OutpaintDragHandle.left:
        return 'left';
      case _OutpaintDragHandle.right:
        return 'right';
      case _OutpaintDragHandle.top:
        return 'top';
      case _OutpaintDragHandle.bottom:
        return 'bottom';
      case _OutpaintDragHandle.topLeft:
        return 'top_left';
      case _OutpaintDragHandle.topRight:
        return 'top_right';
      case _OutpaintDragHandle.bottomLeft:
        return 'bottom_left';
      case _OutpaintDragHandle.bottomRight:
        return 'bottom_right';
    }
  }

  MouseCursor get cursor {
    switch (this) {
      case _OutpaintDragHandle.left:
      case _OutpaintDragHandle.right:
        return SystemMouseCursors.resizeLeftRight;
      case _OutpaintDragHandle.top:
      case _OutpaintDragHandle.bottom:
        return SystemMouseCursors.resizeUpDown;
      case _OutpaintDragHandle.topLeft:
      case _OutpaintDragHandle.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _OutpaintDragHandle.topRight:
      case _OutpaintDragHandle.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
    }
  }
}

class _PreviewLabel extends StatelessWidget {
  static const double _width = 128;
  static const double _height = 28;

  final Rect canvasRect;
  final _OutpaintDragHandle handle;
  final OutpaintFrameResolvedGeometry preview;
  final Size viewportSize;

  const _PreviewLabel({
    required this.canvasRect,
    required this.handle,
    required this.preview,
    required this.viewportSize,
  });

  @override
  Widget build(BuildContext context) {
    final topLeft = _labelTopLeft;
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: _width,
      height: _height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Applied: ${preview.width} x ${preview.height}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onInverseSurface,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset get _labelTopLeft {
    final center = _labelCenter;
    final maxX = math.max(0.0, viewportSize.width - _width);
    final maxY = math.max(0.0, viewportSize.height - _height);
    return Offset(
      (center.dx - _width / 2).clamp(0.0, maxX).toDouble(),
      (center.dy - _height / 2).clamp(0.0, maxY).toDouble(),
    );
  }

  Offset get _labelCenter {
    if (handle.affectsLeft) {
      return Offset(canvasRect.left - 72, canvasRect.center.dy);
    }
    if (handle.affectsRight) {
      return Offset(canvasRect.right + 72, canvasRect.center.dy);
    }
    if (handle.affectsTop) {
      return Offset(canvasRect.center.dx, canvasRect.top - 28);
    }
    return Offset(canvasRect.center.dx, canvasRect.bottom + 28);
  }
}

class _OutpaintEdgePreviewPainter extends CustomPainter {
  final Rect canvasRect;
  final OutpaintFrameResolvedGeometry preview;

  const _OutpaintEdgePreviewPainter({
    required this.canvasRect,
    required this.preview,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = canvasRect.width / preview.sourceWidth;
    final scaleY = canvasRect.height / preview.sourceHeight;
    final frameRect = Rect.fromLTRB(
      canvasRect.left + preview.appliedFrameLeft * scaleX,
      canvasRect.top + preview.appliedFrameTop * scaleY,
      canvasRect.left + preview.appliedFrameRight * scaleX,
      canvasRect.top + preview.appliedFrameBottom * scaleY,
    );

    final fill = Paint()..color = const Color(0x5560AAFF);
    for (final edgeRect in _expansionRects(frameRect)) {
      canvas.drawRect(edgeRect, fill);
    }
    final cropFill = Paint()..color = const Color(0x33000000);
    for (final edgeRect in _cropRects(frameRect)) {
      canvas.drawRect(edgeRect, cropFill);
    }

    canvas.drawRect(
      frameRect,
      Paint()
        ..color = const Color(0xFF60AAFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  Iterable<Rect> _expansionRects(Rect frameRect) sync* {
    if (preview.appliedExpansionEdges.top > 0) {
      yield Rect.fromLTRB(
        frameRect.left,
        frameRect.top,
        frameRect.right,
        canvasRect.top,
      );
    }
    if (preview.appliedExpansionEdges.bottom > 0) {
      yield Rect.fromLTRB(
        frameRect.left,
        canvasRect.bottom,
        frameRect.right,
        frameRect.bottom,
      );
    }
    if (preview.appliedExpansionEdges.left > 0) {
      yield Rect.fromLTRB(
        frameRect.left,
        canvasRect.top,
        canvasRect.left,
        canvasRect.bottom,
      );
    }
    if (preview.appliedExpansionEdges.right > 0) {
      yield Rect.fromLTRB(
        canvasRect.right,
        canvasRect.top,
        frameRect.right,
        canvasRect.bottom,
      );
    }
  }

  Iterable<Rect> _cropRects(Rect frameRect) sync* {
    if (preview.appliedCropEdges.top > 0) {
      yield Rect.fromLTRB(
        canvasRect.left,
        canvasRect.top,
        canvasRect.right,
        frameRect.top,
      );
    }
    if (preview.appliedCropEdges.bottom > 0) {
      yield Rect.fromLTRB(
        canvasRect.left,
        frameRect.bottom,
        canvasRect.right,
        canvasRect.bottom,
      );
    }
    if (preview.appliedCropEdges.left > 0) {
      yield Rect.fromLTRB(
        canvasRect.left,
        canvasRect.top,
        frameRect.left,
        canvasRect.bottom,
      );
    }
    if (preview.appliedCropEdges.right > 0) {
      yield Rect.fromLTRB(
        frameRect.right,
        canvasRect.top,
        canvasRect.right,
        canvasRect.bottom,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OutpaintEdgePreviewPainter oldDelegate) {
    return canvasRect != oldDelegate.canvasRect ||
        preview.width != oldDelegate.preview.width ||
        preview.height != oldDelegate.preview.height ||
        preview.appliedFrameLeft != oldDelegate.preview.appliedFrameLeft ||
        preview.appliedFrameTop != oldDelegate.preview.appliedFrameTop ||
        preview.appliedFrameRight != oldDelegate.preview.appliedFrameRight ||
        preview.appliedFrameBottom != oldDelegate.preview.appliedFrameBottom;
  }
}

class _OutpaintEdgeHighlightPainter extends CustomPainter {
  static const double _strokeWidth = 10;

  final Rect canvasRect;
  final _OutpaintDragHandle handle;

  const _OutpaintEdgeHighlightPainter({
    required this.canvasRect,
    required this.handle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xAA8DD8FF)
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    if (handle.affectsLeft) {
      canvas.drawLine(canvasRect.topLeft, canvasRect.bottomLeft, paint);
    }
    if (handle.affectsRight) {
      canvas.drawLine(canvasRect.topRight, canvasRect.bottomRight, paint);
    }
    if (handle.affectsTop) {
      canvas.drawLine(canvasRect.topLeft, canvasRect.topRight, paint);
    }
    if (handle.affectsBottom) {
      canvas.drawLine(canvasRect.bottomLeft, canvasRect.bottomRight, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OutpaintEdgeHighlightPainter oldDelegate) {
    return canvasRect != oldDelegate.canvasRect || handle != oldDelegate.handle;
  }
}
