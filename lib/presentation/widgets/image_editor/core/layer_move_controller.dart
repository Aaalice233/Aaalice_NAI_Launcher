import 'dart:async';
import 'dart:ui';

import '../../../../core/utils/app_logger.dart';
import '../layers/layer.dart';
import '../layers/layer_patch_baker.dart';
import 'editor_state.dart';
import 'history_manager.dart';
import 'layer_actions.dart';

/// 移动工具的拖动会话：有选区时移动当前图层在选区内的像素，否则整层平移。
/// 拖动中只改预览，松手后按整数像素一次提交进撤销栈。
class LayerMoveController {
  LayerMoveController(this._state);

  final EditorState _state;
  _MoveGesture? _gesture;
  bool _committing = false;
  Future<void> _nudgeQueue = Future.value();

  bool get isDragging => _gesture != null;

  /// 原图层决定原图区域，整层平移会让取景框的原图参照失效；框选后移动其中的像素不受影响
  bool canMoveWholeLayer(Layer layer) => !_state.rolePolicy.isProtected(layer);

  bool begin(Offset point) {
    if (_committing || _gesture != null) return false;
    final layer = _movableActiveLayer();
    if (layer == null) return false;
    final selection = _state.selectionPath;
    if (selection != null) {
      _gesture = _MoveGesture(layerId: layer.id, start: point, region: selection);
      layer.setMovePreview(
        LayerMovePreview.region(selection, Offset.zero, layer.contentBounds),
      );
      _state.selectionManager.beginDrag();
    } else {
      if (!canMoveWholeLayer(layer)) return false;
      _gesture = _MoveGesture(layerId: layer.id, start: point);
      layer.setMovePreview(LayerMovePreview.whole(Offset.zero));
    }
    _state.notifyRenderChange();
    return true;
  }

  void update(Offset point) {
    final gesture = _gesture;
    if (gesture == null) return;
    final raw = point - gesture.start;
    final offset = Offset(raw.dx.roundToDouble(), raw.dy.roundToDouble());
    if (offset == gesture.offset) return;
    gesture.offset = offset;
    final layer = _state.layerManager.getLayerById(gesture.layerId);
    layer?.setMovePreview(layer.movePreview?.withOffset(offset));
    if (gesture.region != null) {
      _state.selectionManager.updateDrag(offset);
    }
    _state.notifyRenderChange();
  }

  Future<void> end() async {
    final gesture = _gesture;
    _gesture = null;
    if (gesture == null) return;
    final region = gesture.region;
    if (gesture.offset == Offset.zero) {
      _clearPreview(gesture.layerId);
      return;
    }
    if (region == null) {
      _clearPreview(gesture.layerId);
      _state.historyManager.execute(
        TranslateLayerAction(layerId: gesture.layerId, delta: gesture.offset),
        _state,
      );
      return;
    }
    await _commitRegionMove(gesture.layerId, region, gesture.offset);
  }

  void cancel() {
    final gesture = _gesture;
    _gesture = null;
    if (gesture == null) return;
    _clearPreview(gesture.layerId);
  }

  /// 方向键微移；选区像素的提交是异步的，连续按键按顺序排队
  Future<void> nudge(Offset delta) {
    return _nudgeQueue = _nudgeQueue.then((_) => _nudgeOnce(delta));
  }

  Future<void> _nudgeOnce(Offset delta) async {
    if (_gesture != null || _committing) return;
    final layer = _movableActiveLayer();
    if (layer == null) return;
    final selection = _state.selectionPath;
    if (selection != null) {
      await _commitRegionMove(layer.id, selection, delta);
      return;
    }
    if (!canMoveWholeLayer(layer)) return;
    _state.historyManager.execute(
      TranslateLayerAction(layerId: layer.id, delta: delta),
      _state,
    );
  }

  Layer? _movableActiveLayer() {
    final layer = _state.layerManager.activeLayer;
    if (layer == null || layer.locked || !layer.hasContent) return null;
    return layer;
  }

  /// 烘焙期间保留预览，结果落地的同一帧撤掉，画面不会跳回原位
  Future<void> _commitRegionMove(
    String layerId,
    Path region,
    Offset offset,
  ) async {
    final layer = _state.layerManager.getLayerById(layerId);
    if (layer == null) {
      _clearPreview(layerId);
      return;
    }
    _committing = true;
    final version = _state.layerManager.snapshotVersion;
    try {
      final BakedLayerImage moved;
      try {
        moved = await LayerPatchBaker.moveRegion(
          layer,
          region: region,
          offset: offset,
          extentLock: _state.rolePolicy.extentLockFor(layer),
        );
      } on Object catch (error, stackTrace) {
        AppLogger.e('Failed to move selection pixels', error, stackTrace,
            'ImageEditor');
        _clearPreview(layerId);
        return;
      }
      _clearPreview(layerId);
      if (_state.layerManager.snapshotVersion != version ||
          _state.layerManager.getLayerById(layerId) == null) {
        moved.dispose();
        return;
      }
      _state.historyManager.execute(
        ReplaceLayerImageAction.baked(
          layerId: layerId,
          pixels: moved,
          actionDescription: 'Move Selection',
          selectionChange: SelectionChange(
            before: region,
            after: region.shift(offset),
          ),
        ),
        _state,
      );
    } finally {
      _committing = false;
    }
  }

  void _clearPreview(String layerId) {
    _state.layerManager.getLayerById(layerId)?.setMovePreview(null);
    _state.selectionManager.cancelDrag();
    _state.notifyRenderChange();
  }
}

class _MoveGesture {
  _MoveGesture({required this.layerId, required this.start, this.region});

  final String layerId;
  final Offset start;

  /// 非空时移动的是该选区内的像素
  final Path? region;
  Offset offset = Offset.zero;
}
