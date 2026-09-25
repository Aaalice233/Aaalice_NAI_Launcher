import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:uuid/uuid.dart';

import '../layers/layer.dart';
import '../layers/layer_manager.dart';
import '../layers/layer_patch_baker.dart';
import '../layers/layer_role.dart';
import 'editor_state.dart';
import 'history_manager.dart';
import 'layer_actions.dart';
import 'layer_role_policy.dart';

/// 图层结构与像素操作的统一入口：先按 [LayerRolePolicy] 校验，再经撤销栈执行
class LayerCommands {
  LayerCommands(this._state);

  final EditorState _state;

  LayerManager get _layers => _state.layerManager;
  LayerRolePolicy get _policy => _state.rolePolicy;

  /// 新建空白图层，插在当前图层上方；重绘会话里按角色落到各自的分组
  Layer addLayer({required String name, LayerRole role = LayerRole.image}) {
    final data = LayerData(
      id: const Uuid().v4(),
      name: name,
      visible: true,
      locked: false,
      opacity: 1.0,
      role: role,
    );
    return _insert(data, role, 'Add Layer');
  }

  /// 以图片新建图层，底图左上角落在 [offset]；解码失败返回 null
  Future<Layer?> addImageLayer(
    Uint8List bytes, {
    required String name,
    Offset offset = Offset.zero,
  }) async {
    final ui.Image image;
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
    } on Object {
      return null;
    } finally {
      codec?.dispose();
    }
    final data = LayerData(
      id: const Uuid().v4(),
      name: name,
      visible: true,
      locked: false,
      opacity: 1.0,
      content: LayerContentSnapshot(
        baseImage: image,
        baseImageBytes: bytes,
        baseImageOffset: offset,
      ),
    );
    return _insert(data, LayerRole.image, 'Import Image Layer');
  }

  Layer _insert(LayerData data, LayerRole role, String description) {
    final index = _policy.insertIndexFor(_layers, role);
    _state.historyManager.execute(
      InsertLayerAction(
        data: data,
        index: index,
        actionDescription: description,
      ),
      _state,
    );
    return _layers.getLayerById(data.id)!;
  }

  bool canDelete(Layer layer) => _policy.canDelete(_layers, layer);

  void delete(Layer layer) {
    if (!canDelete(layer)) return;
    _state.historyManager.execute(RemoveLayerAction(layerId: layer.id), _state);
  }

  /// 副本放在原图层正上方，原图层的保护身份不随之复制
  Layer duplicate(Layer layer, {required String name}) {
    final data = LayerData(
      id: const Uuid().v4(),
      name: name,
      visible: layer.visible,
      locked: false,
      opacity: layer.opacity,
      blendMode: layer.blendMode,
      role: layer.role,
      model3d: layer.model3d,
      content: layer.captureContent(),
    );
    _state.historyManager.execute(
      InsertLayerAction(
        data: data,
        index: _layers.indexOfLayer(layer.id),
        actionDescription: 'Duplicate Layer',
      ),
      _state,
    );
    return _layers.getLayerById(data.id)!;
  }

  bool canMergeDown(Layer layer) =>
      _policy.mergeTargetFor(_layers, layer) != null;

  Future<bool> mergeDown(Layer layer) async {
    final lower = _policy.mergeTargetFor(_layers, layer);
    if (lower == null) return false;
    final version = _layers.snapshotVersion;
    final merged = await LayerPatchBaker.mergeDown(
      upper: layer,
      lower: lower,
      extentLock: _policy.extentLockFor(lower),
    );
    if (!_isStillCurrent(version) ||
        _policy.mergeTargetFor(_layers, layer)?.id != lower.id) {
      merged.dispose();
      return false;
    }
    _state.historyManager.execute(
      MergeDownAction(upperId: layer.id, lowerId: lower.id, merged: merged),
      _state,
    );
    return true;
  }

  bool canMoveUp(Layer layer) {
    final index = _layers.indexOfLayer(layer.id);
    return _policy.canReorder(_layers, index, index - 1);
  }

  bool canMoveDown(Layer layer) {
    final index = _layers.indexOfLayer(layer.id);
    return _policy.canReorder(_layers, index, index + 1);
  }

  void moveUp(Layer layer) {
    final index = _layers.indexOfLayer(layer.id);
    reorder(index, index - 1);
  }

  void moveDown(Layer layer) {
    final index = _layers.indexOfLayer(layer.id);
    reorder(index, index + 1);
  }

  bool canReorder(int fromIndex, int toIndex) =>
      _policy.canReorder(_layers, fromIndex, toIndex);

  void reorder(int fromIndex, int toIndex) {
    if (!canReorder(fromIndex, toIndex)) return;
    _state.historyManager.execute(
      ReorderLayerAction(fromIndex: fromIndex, toIndex: toIndex),
      _state,
    );
  }

  bool get canEditSelectionPixels {
    final layer = _layers.activeLayer;
    return _state.selectionPath != null &&
        layer != null &&
        !layer.locked &&
        layer.hasContent;
  }

  /// 剪切选区像素到紧贴当前图层上方的新图层，新图层与原图层同一角色
  Future<bool> cutSelectionToNewLayer({required String layerName}) async {
    final selection = _state.selectionPath;
    final source = _layers.activeLayer;
    if (!canEditSelectionPixels || selection == null || source == null) {
      return false;
    }
    final version = _layers.snapshotVersion;
    final extracted = await LayerPatchBaker.extractRegion(
      source,
      region: selection,
    );
    if (extracted == null) return false;
    final BakedLayerImage remainder;
    try {
      remainder = await LayerPatchBaker.eraseRegion(
        source,
        region: selection,
        extentLock: _policy.extentLockFor(source),
      );
    } on Object {
      extracted.dispose();
      rethrow;
    }
    if (!_isStillCurrent(version) || _state.selectionPath != selection) {
      extracted.dispose();
      remainder.dispose();
      return false;
    }
    _state.historyManager.execute(
      CutSelectionToLayerAction(
        sourceId: source.id,
        remainder: remainder,
        cutLayer: LayerData(
          id: const Uuid().v4(),
          name: layerName,
          visible: true,
          locked: false,
          opacity: source.opacity,
          blendMode: source.blendMode,
          role: source.role,
          content: LayerContentSnapshot(
            baseImage: extracted.image,
            baseImageBytes: extracted.bytes,
            baseImageOffset: extracted.offset,
          ),
        ),
        selection: selection,
      ),
      _state,
    );
    return true;
  }

  /// 清除当前图层在选区内的像素，选区保留
  Future<bool> clearSelectionPixels() async {
    final selection = _state.selectionPath;
    final layer = _layers.activeLayer;
    if (!canEditSelectionPixels || selection == null || layer == null) {
      return false;
    }
    final version = _layers.snapshotVersion;
    final erased = await LayerPatchBaker.eraseRegion(
      layer,
      region: selection,
      extentLock: _policy.extentLockFor(layer),
    );
    if (!_isStillCurrent(version)) {
      erased.dispose();
      return false;
    }
    _state.historyManager.execute(
      ReplaceLayerImageAction.baked(
        layerId: layer.id,
        pixels: erased,
        actionDescription: 'Clear Selection',
      ),
      _state,
    );
    return true;
  }

  /// 异步烘焙期间文档被改动过，结果已不对应当前内容
  bool _isStillCurrent(int version) => _layers.snapshotVersion == version;
}
