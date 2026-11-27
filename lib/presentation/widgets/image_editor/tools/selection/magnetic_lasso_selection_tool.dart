import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/magnetic_lasso/edge_cost_map.dart';
import '../../core/editor_pixel_reader.dart';
import '../../core/editor_state.dart';
import 'base_selection_tool.dart';
import 'magnetic_lasso_options.dart';
import 'magnetic_lasso_path.dart';

typedef MagneticLassoEdgeBuilder =
    FutureOr<EdgeCostMap> Function(Uint8List rgba, int width, int height);
typedef _EdgeCacheKey = ({EditorState state, int version, Rect frame});

class MagneticLassoSelectionTool extends BaseSelectionTool {
  MagneticLassoSelectionTool({
    MagneticLassoEdgeBuilder buildEdgeMap = EdgeCostMap.buildAsync,
  }) : _buildEdgeMap = buildEdgeMap;

  final MagneticLassoEdgeBuilder _buildEdgeMap;
  final _anchors = ValueNotifier(0);
  Listenable get anchorListenable => _anchors;
  int get anchorCount => _anchors.value;

  int _width = 10;
  int _contrast = 10;
  int _frequency = 57;
  int get width => _width;
  int get contrast => _contrast;
  int get frequency => _frequency;

  MagneticLassoPath? _path;
  ({_EdgeCacheKey key, EdgeCostMap map})? _cache;
  ({Offset position, Duration time})? _lastPress;
  Offset? _dragStart;
  Offset? _previewTarget;
  bool _dragged = false;

  int get _interval => (160 + (16 - 160) * _frequency / 100).round();
  int get _radius => math.max(2 * _interval, 4 * _width).clamp(96, 256);

  @override
  String get id => 'magnetic_lasso_selection';
  @override
  String get name => 'Magnetic Lasso';
  @override
  IconData get icon => Icons.polyline;
  @override
  bool get belongsToInpaintGroup => true;
  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyL;

  @override
  Widget buildToolOptions(BuildContext context, EditorState state) =>
      MagneticLassoOptions(tool: this, state: state);

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    final point = event.localPosition;
    final path = _path;
    if (path == null) {
      if (beginOutlineDrag(state, point)) return;
      final frame = state.frame;
      if (frame.width.round() <= 0 || frame.height.round() <= 0) return;
      final started = MagneticLassoPath(frame, point);
      _path = started;
      unawaited(_loadEdges(state, started));
    } else {
      if (_shouldClose(event, state, path)) {
        onConfirm(state);
        return;
      }
      path.addAnchor(point, _radius);
    }
    _lastPress = (position: point, time: event.timeStamp);
    _dragStart = point;
    _dragged = false;
    _previewTarget = null;
    _publish(state);
  }

  bool _shouldClose(
    PointerDownEvent event,
    EditorState state,
    MagneticLassoPath path,
  ) {
    final scale = state.canvasController.scale;
    final point = event.localPosition;
    if (path.anchorCount >= 3 && (point - path.start).distance <= 10 / scale) {
      return true;
    }
    final last = _lastPress;
    if (last == null) return false;
    final elapsed = event.timeStamp - last.time;
    return elapsed >= Duration.zero &&
        elapsed <= const Duration(milliseconds: 350) &&
        (point - last.position).distance <= 6 / scale;
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    final point = event.localPosition;
    if (updateOutlineDrag(state, point)) return;
    final start = _dragStart;
    if (start == null) return;
    _dragged |= (point - start).distance > 6 / state.canvasController.scale;
    _preview(state, point);
  }

  @override
  void onPointerHover(PointerHoverEvent event, EditorState state) =>
      _preview(state, event.localPosition);

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (endOutlineDrag(state)) return;
    final start = _dragStart;
    _dragStart = null;
    if (start == null) return;
    final point = event.localPosition;
    if (_dragged ||
        (point - start).distance > 6 / state.canvasController.scale) {
      _path?.addAnchor(point, _radius);
      _lastPress = null; // 拖动不是双击的第一击。
      _previewTarget = null;
      _publish(state);
    }
    _dragged = false;
  }

  void _preview(EditorState state, Offset point, {bool fixAnchors = true}) {
    final path = _path;
    if (path == null) return;
    _previewTarget = point;
    path.updatePreview(
      point,
      width: _width,
      radius: _radius,
      interval: _interval,
      fixAnchors: fixAnchors,
    );
    _publish(state);
  }

  void _publish(EditorState state) {
    final path = _path;
    _anchors.value = path?.anchorCount ?? 0;
    if (path == null) {
      state.clearPreview();
    } else {
      state.setPreviewPath(path.previewPath(state.canvasController.scale));
    }
  }

  Future<void> _loadEdges(EditorState state, MagneticLassoPath path) async {
    final key = (
      state: state,
      version: state.layerManager.snapshotVersion,
      frame: path.frame,
    );
    bool isCurrent() =>
        !state.isDisposed &&
        identical(_path, path) &&
        identical(state.currentTool, this);
    try {
      final cached = _cache;
      if (cached != null && cached.key == key) {
        path.setEdgeMap(cached.map, contrast: _contrast, radius: _radius);
        return;
      }
      final source = await readEditorPixels(
        state,
        path.frame,
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (!isCurrent()) return;
      final map = await _buildEdgeMap(
        source.bytes,
        source.width,
        source.height,
      );
      if (!isCurrent()) return;
      _cache = (key: key, map: map);
      path.setEdgeMap(map, contrast: _contrast, radius: _radius);
      final target = _previewTarget;
      if (target != null) _preview(state, target, fixAnchors: false);
    } catch (error) {
      // 读取失败时仍可用直线继续完成这条路径。
      if (isCurrent()) {
        AppLogger.w(
          'Failed to prepare magnetic lasso edges: $error',
          'ImageEditor',
        );
      }
    }
  }

  void updateOptions(
    EditorState state, {
    int? width,
    int? contrast,
    int? frequency,
  }) {
    final oldRadius = _radius;
    final oldContrast = _contrast;
    _width = width ?? _width;
    _contrast = contrast ?? _contrast;
    _frequency = frequency ?? _frequency;
    final map = _path?.edgeMap;
    if (map != null && (oldRadius != _radius || oldContrast != _contrast)) {
      _path!.setEdgeMap(map, contrast: _contrast, radius: _radius);
    }
    final target = _previewTarget;
    if (target != null) _preview(state, target, fixAnchors: false);
  }

  @override
  bool onConfirm(EditorState state) {
    final path = _path;
    if (path == null) return false;
    final selection = path.closedPath();
    onSelectionCancel();
    if (selection == null) {
      state.clearPreview();
    } else {
      commitNewSelection(state, selection);
    }
    return true;
  }

  @override
  bool onDeleteKey(EditorState state) {
    final path = _path;
    if (path == null) return false;
    if (path.anchorCount == 1) return onEscape(state);
    path.removeAnchor(_radius);
    _previewTarget = null;
    _lastPress = null;
    _publish(state);
    return true;
  }

  @override
  bool onEscape(EditorState state) {
    if (_path == null) return false;
    onSelectionCancel();
    state.clearPreview();
    return true;
  }

  @override
  void onPointerCancel(EditorState state) {
    final path = _path;
    if (path == null) {
      super.onPointerCancel(state);
      return;
    }
    _dragStart = null;
    _dragged = false;
    _lastPress = null;
    _previewTarget = null;
    path.clearPreview();
    _publish(state);
  }

  @override
  void onSelectionCancel() {
    _path = null;
    _lastPress = null;
    _dragStart = null;
    _dragged = false;
    _previewTarget = null;
    _anchors.value = 0;
  }

  @override
  void dispose() {
    _path = null;
    _cache = null;
    _anchors.dispose();
    super.dispose();
  }
}
