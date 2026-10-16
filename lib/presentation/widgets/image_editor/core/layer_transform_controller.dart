import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_logger.dart';
import '../layers/layer.dart';
import '../layers/layer_patch_baker.dart';
import '../layers/layer_role.dart';
import '../layers/transform_source.dart';
import 'editor_state.dart';
import 'transform_actions.dart';
import 'transform_geometry.dart';

/// 移动工具上的自由变换。没有会话时显示当前目标的外接框，拖缩放或旋转手柄即进入会话；
/// 会话里每次松手都从会话开始时截下的像素重新计算并立即写回图层，
/// 所以其他功能随时读到的都是最终像素，撤销栈里整次会话只占一条
class LayerTransformController extends ChangeNotifier {
  LayerTransformController(this._state) {
    _state.historyManager.addListener(_onHistoryChanged);
    _state.layerManager.activeLayerNotifier.addListener(_onActiveLayerChanged);
    _state.selectionManager.selectionNotifier.addListener(_onSelectionChanged);
  }

  final EditorState _state;
  _TransformSession? _session;
  _TransformDrag? _drag;
  _TransformPinch? _pinch;
  int _mutating = 0;
  bool _keepAspect = true;

  /// 悬停与拖动时的鼠标样式
  final ValueNotifier<MouseCursor> cursor = ValueNotifier(
    SystemMouseCursors.move,
  );

  /// 画布按当前交互方式设置，变换框的绘制与命中共用
  TransformHandleMetrics handleMetrics = TransformHandleMetrics.pointer;

  bool get isActive => _session != null;

  bool get isDragging => _drag != null || _pinch != null;

  /// 角点拖动与数值输入是否保持宽高比；拖动时按住 Shift 临时取反
  bool get keepAspect => _keepAspect;

  set keepAspect(bool value) {
    if (_keepAspect == value) return;
    _keepAspect = value;
    notifyListeners();
  }

  /// 变换框当前显示的参数：会话中含拖动预览，否则为目标的外接框
  TransformParams? get params {
    final session = _session;
    if (session == null) {
      final target = _resolveTarget();
      return target == null ? null : TransformParams.identity(target.bounds);
    }
    return _pinch?.current ?? _drag?.current ?? session.params;
  }

  /// 进入会话；Ctrl+T 与数值输入从这里开始。已在会话中时直接返回 true
  bool begin() {
    final current = _session;
    if (current != null) {
      if (!_isStale(current)) return true;
      _end();
    }
    final target = _resolveTarget();
    if (target == null) return false;
    final layer = target.layer;
    final source = _capture(target);
    if (source == null) return false;
    _session = _TransformSession(
      layerId: layer.id,
      source: source,
      params: source.identity,
      revision: layer.contentRevision,
    );
    _changed();
    return true;
  }

  /// 导入的图片作为新图层落地并立即进入会话：放进取景框中央，放不下时等比缩小。
  /// [image] 的所有权移交给控制器；无法光栅化时返回 false
  bool placeImage(ui.Image image, {required String name}) {
    apply();
    final source = TransformSource.placed(image, clip: _resultLimit());
    final params = TransformParams.fitInside(source.sourceRect, _state.frame);
    final BakedLayerImage? pixels;
    try {
      pixels = source.bake(params);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to place imported image',
        error,
        stackTrace,
        'ImageEditor',
      );
      source.dispose();
      return false;
    }
    final action = PlaceImageLayerAction(
      layerId: const Uuid().v4(),
      pixels: pixels,
      name: name,
      index: _state.rolePolicy.insertIndexFor(
        _state.layerManager,
        LayerRole.image,
      ),
    );
    _mutate(() {
      _state.clearSelection(saveHistory: false);
      _state.historyManager.execute(action, _state, tentative: true);
    });
    final layer = _state.layerManager.getLayerById(action.layerId);
    _session = _TransformSession(
      layerId: action.layerId,
      source: source,
      params: params,
      revision: layer?.contentRevision ?? 0,
      action: action,
    );
    _changed();
    return true;
  }

  /// 确认：保留已写入的结果，结束会话
  void apply() {
    if (_session == null) return;
    _finishGestures(commit: true);
    _end();
  }

  /// 取消：整次会话撤回到开始之前；导入的图片随之移除
  void cancel() {
    final session = _session;
    if (session == null) return;
    _finishGestures(commit: false);
    final action = session.action;
    if (action != null) {
      _mutate(() => _state.historyManager.discardLatest(action, _state));
    }
    _end();
  }

  /// 以当前参数为基础做一次调整并写回；不在会话中时先进入会话
  bool update(TransformParams Function(TransformParams current) change) {
    if (isDragging || !begin()) return false;
    final session = _session!;
    _commit(session, change(session.params));
    return true;
  }

  /// 按 [change] 算出结果但不写回，供预览；没有可变换的内容时返回 null，调用方负责释放
  BakedLayerImage? bakePreview(
    TransformParams Function(TransformParams current) change,
  ) {
    final session = _session;
    if (session != null && !_isStale(session)) {
      return session.source.bake(change(session.params).pixelAligned());
    }
    final target = _resolveTarget();
    final source = target == null ? null : _capture(target);
    if (source == null) return null;
    try {
      return source.bake(change(source.identity).pixelAligned());
    } finally {
      source.dispose();
    }
  }

  void nudge(Offset delta) => update((params) => params.translated(delta));

  void flip({required bool horizontal}) =>
      update((params) => params.flipped(horizontal: horizontal));

  // ===== 指针 =====

  /// 落在缩放或旋转手柄上、或已在会话中时接管拖动；返回 false 时交给普通移动
  bool pointerDown(Offset point, PointerDeviceKind kind) {
    final current = _session;
    if (current != null && _isStale(current)) _end();
    final params = this.params;
    if (params == null || isDragging) return false;
    final hit = params.hitTest(
      point,
      _metricsFor(kind),
      rotateOutside: isActive,
    );
    if (hit == null) return false;
    if (!isActive && hit.grip == TransformGrip.move) return false;
    if (!begin()) return false;
    final session = _session!;
    _drag = _TransformDrag(hit: hit, origin: point, start: session.params);
    cursor.value = _cursorFor(hit, session.params, dragging: true);
    _showPreview(session, session.params);
    return true;
  }

  void pointerMove(Offset point, {required bool shift, required bool alt}) {
    final drag = _drag;
    final session = _session;
    if (drag == null || session == null) return;
    final next = switch (drag.hit.grip) {
      TransformGrip.move => drag.start.translated(point - drag.origin),
      TransformGrip.scale => drag.start.scaledBy(
        drag.hit.handle!,
        point,
        keepAspect: _keepAspect != shift,
        fromCenter: alt,
      ),
      TransformGrip.rotate => drag.start.rotatedTowards(
        drag.origin,
        point,
        snap: shift,
      ),
    };
    if (next == drag.current) return;
    drag.current = next;
    _showPreview(session, next);
  }

  void pointerUp() {
    final drag = _drag;
    _drag = null;
    final session = _session;
    if (drag == null || session == null) return;
    _commit(session, drag.current);
  }

  /// 放弃进行中的拖动或双指手势，会话保持在手势开始前
  void pointerCancel() {
    if (!isDragging) return;
    _drag = null;
    _pinch = null;
    final session = _session;
    if (session != null) _clearPreview(session);
  }

  void hover(Offset point, PointerDeviceKind kind) {
    if (isDragging) return;
    final params = this.params;
    cursor.value = params == null
        ? SystemMouseCursors.move
        : _cursorFor(
            params.hitTest(point, _metricsFor(kind), rotateOutside: isActive),
            params,
            dragging: false,
          );
  }

  // ===== 双指 =====

  /// 只在会话中接管双指，其余时候双指照常平移缩放画布
  bool pinchStart(Offset focal) {
    final session = _session;
    if (session == null) return false;
    if (_isStale(session)) {
      _end();
      return false;
    }
    _drag = null;
    _pinch = _TransformPinch(focal: focal, start: session.params);
    return true;
  }

  /// [focal] 为文档坐标；[scale] 与 [turn] 相对手势开始时
  void pinchUpdate(Offset focal, double scale, double turn) {
    final pinch = _pinch;
    final session = _session;
    if (pinch == null || session == null) return;
    final next = pinch.start.pinched(
      from: pinch.focal,
      to: focal,
      scale: scale,
      turn: turn,
    );
    if (next == pinch.current) return;
    pinch.current = next;
    _showPreview(session, next);
  }

  void pinchEnd() {
    final pinch = _pinch;
    _pinch = null;
    final session = _session;
    if (pinch == null || session == null) return;
    _commit(session, pinch.current);
  }

  // ===== 内部 =====

  /// 有选区时是当前图层选区内的像素，否则是整个当前图层；原图层只能变换选区内的像素
  _TransformTarget? _resolveTarget() {
    final layer = _state.layerMover.movableActiveLayer();
    if (layer == null) return null;
    final selection = _state.selectionPath;
    if (selection != null) {
      final bounds = selection.getBounds();
      if (bounds.width < 1 || bounds.height < 1) return null;
      return (layer: layer, selection: selection, bounds: bounds);
    }
    if (!_state.layerMover.canMoveWholeLayer(layer)) return null;
    final bounds = layer.contentBounds;
    if (bounds.width < 1 || bounds.height < 1) return null;
    return (layer: layer, selection: null, bounds: bounds);
  }

  TransformSource? _capture(_TransformTarget target) {
    final layer = target.layer;
    final selection = target.selection;
    try {
      return selection == null
          ? TransformSource.captureLayer(layer, clip: _resultLimit())
          : TransformSource.captureRegion(
              layer,
              selection,
              clip: _resultLimit(),
              extentLock: _state.rolePolicy.extentLockFor(layer),
            );
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to capture pixels for free transform',
        error,
        stackTrace,
        'ImageEditor',
      );
      return null;
    }
  }

  /// 变换结果保留的范围：取景框与所有图层已有内容，四周再留出半条长边，
  /// 内容绕中心任意旋转都不会被裁掉；同时防止反复放大让图层无限变大
  Rect _resultLimit() {
    var bounds = _state.frame;
    for (final layer in _state.layerManager.layers) {
      final content = layer.contentBounds;
      if (!content.isEmpty) bounds = bounds.expandToInclude(content);
    }
    return bounds.inflate(bounds.longestSide / 2);
  }

  /// 图层被会话以外的操作改过，截下的像素已不再对应图层内容
  bool _isStale(_TransformSession session) {
    final layer = _state.layerManager.getLayerById(session.layerId);
    return layer == null ||
        layer.locked ||
        layer.contentRevision != session.revision;
  }

  void _commit(_TransformSession session, TransformParams requested) {
    final next = requested.pixelAligned();
    if (next == session.params) {
      _clearPreview(session);
      return;
    }
    final layer = _state.layerManager.getLayerById(session.layerId);
    if (layer == null) {
      _end();
      return;
    }
    final BakedLayerImage? pixels;
    try {
      pixels = session.source.bake(next);
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to bake free transform',
        error,
        stackTrace,
        'ImageEditor',
      );
      _clearPreview(session);
      return;
    }
    final selection = session.source.selectionFor(next);
    var written = true;
    _mutate(() {
      final action = session.action;
      if (action == null) {
        final created = TransformLayerAction(
          layerId: session.layerId,
          pixels: pixels,
          selectionBefore: session.source.selection,
          selectionAfter: selection,
        );
        session.action = created;
        _state.historyManager.execute(created, _state, tentative: true);
      } else {
        written = _state.historyManager.amendLatest(
          action,
          () => action.amend(_state, pixels, selection),
        );
      }
    });
    if (!written) {
      pixels?.dispose();
      _end();
      return;
    }
    session
      ..params = next
      ..revision = layer.contentRevision;
    // 结果与撤掉预览落在同一帧，画面不会跳回原位
    _clearPreview(session);
  }

  void _showPreview(_TransformSession session, TransformParams params) {
    _state.layerManager
        .getLayerById(session.layerId)
        ?.setPreview(session.source.previewFor(params));
    _state.selectionManager.previewOutline(session.source.selectionFor(params));
    _changed();
  }

  void _clearPreview(_TransformSession session) {
    _state.layerManager.getLayerById(session.layerId)?.setPreview(null);
    _state.selectionManager.previewOutline(null);
    _changed();
  }

  void _finishGestures({required bool commit}) {
    final session = _session;
    final pending = _pinch?.current ?? _drag?.current;
    _drag = null;
    _pinch = null;
    if (session == null || pending == null) return;
    if (commit) {
      _commit(session, pending);
    } else {
      _clearPreview(session);
    }
  }

  void _end() {
    final session = _session;
    if (session == null) return;
    _drag = null;
    _pinch = null;
    _session = null;
    final action = session.action;
    if (action != null) _state.historyManager.settle(action);
    _clearPreview(session);
    session.dispose();
    cursor.value = SystemMouseCursors.move;
  }

  void _mutate(void Function() change) {
    _mutating++;
    try {
      change();
    } finally {
      _mutating--;
    }
  }

  void _changed() {
    _state.notifyRenderChange();
    notifyListeners();
  }

  /// 撤销、重做或别的操作改动了撤销栈：会话的结果已不在栈顶，截下的像素随之作废
  void _onHistoryChanged() {
    final session = _session;
    if (_mutating > 0 || session == null) return;
    final action = session.action;
    if (action == null || !_state.historyManager.isLatest(action)) _end();
  }

  void _onActiveLayerChanged() {
    final session = _session;
    if (_mutating > 0 || session == null) return;
    if (_state.layerManager.activeLayer?.id != session.layerId) apply();
  }

  void _onSelectionChanged() {
    if (_mutating > 0 || _session == null) return;
    apply();
  }

  /// 手柄位置跟随画布的交互方式；触摸输入另把命中半径放大到触屏标准
  TransformHandleMetrics _metricsFor(PointerDeviceKind kind) {
    final touch = switch (kind) {
      PointerDeviceKind.touch ||
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => true,
      _ => false,
    };
    final radius = touch
        ? math.max(
            handleMetrics.hitRadius,
            TransformHandleMetrics.touch.hitRadius,
          )
        : handleMetrics.hitRadius;
    return TransformHandleMetrics(
      hitRadius: radius,
      rotateHandleOffset: handleMetrics.rotateHandleOffset,
    ).inDocument(_state.canvasController.scale);
  }

  MouseCursor _cursorFor(
    TransformHit? hit,
    TransformParams params, {
    required bool dragging,
  }) {
    if (hit == null) return SystemMouseCursors.move;
    return switch (hit.grip) {
      TransformGrip.move => SystemMouseCursors.move,
      TransformGrip.rotate =>
        dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      TransformGrip.scale => _resizeCursor(params, hit.handle!),
    };
  }

  /// 按手柄在屏幕上相对中心的方向选箭头，视图旋转、镜像后依然指向拖动方向
  MouseCursor _resizeCursor(TransformParams params, TransformHandle handle) {
    final controller = _state.canvasController;
    final frame = _state.frame;
    final center = controller.canvasToScreen(params.center, frame: frame);
    final grip = controller.canvasToScreen(
      params.pointAt(handle.unit),
      frame: frame,
    );
    final degrees = (grip - center).direction * 180 / math.pi;
    final octant = ((degrees % 180) / 45).round() % 4;
    return const [
      SystemMouseCursors.resizeLeftRight,
      SystemMouseCursors.resizeUpLeftDownRight,
      SystemMouseCursors.resizeUpDown,
      SystemMouseCursors.resizeUpRightDownLeft,
    ][octant];
  }

  @override
  void dispose() {
    _state.historyManager.removeListener(_onHistoryChanged);
    _state.layerManager.activeLayerNotifier.removeListener(
      _onActiveLayerChanged,
    );
    _state.selectionManager.selectionNotifier.removeListener(
      _onSelectionChanged,
    );
    final session = _session;
    _session = null;
    session?.dispose();
    cursor.dispose();
    super.dispose();
  }
}

typedef _TransformTarget = ({Layer layer, Path? selection, Rect bounds});

class _TransformSession {
  _TransformSession({
    required this.layerId,
    required this.source,
    required this.params,
    required this.revision,
    this.action,
  });

  final String layerId;
  final TransformSource source;

  /// 已写回图层的参数
  TransformParams params;

  /// 会话最后一次写回后图层的内容版本
  int revision;

  /// 第一次写回前为 null；导入图片时创建即有
  TransformCommitAction? action;

  void dispose() => source.dispose();
}

class _TransformDrag {
  _TransformDrag({required this.hit, required this.origin, required this.start})
    : current = start;

  final TransformHit hit;
  final Offset origin;
  final TransformParams start;
  TransformParams current;
}

class _TransformPinch {
  _TransformPinch({required this.focal, required this.start}) : current = start;

  final Offset focal;
  final TransformParams start;
  TransformParams current;
}
