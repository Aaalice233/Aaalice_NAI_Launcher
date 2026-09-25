import 'dart:ui';

import '../layers/layer.dart';
import '../layers/layer_patch_baker.dart';
import 'editor_state.dart';
import 'history_manager.dart';

/// 插入一个完整图层（新建、复制、导入共用），撤销时整层移除
class InsertLayerAction extends EditorAction {
  InsertLayerAction({
    required LayerData data,
    required this.index,
    required this.actionDescription,
  }) : _data = data;

  final LayerData _data;
  final int index;
  final String actionDescription;

  String get layerId => _data.id;

  @override
  void execute(EditorState state) {
    state.layerManager.insertLayerFromData(_data, index, setActive: true);
  }

  @override
  void undo(EditorState state) {
    state.layerManager.removeLayer(_data.id);
  }

  @override
  void dispose() => _data.dispose();

  @override
  String get description => actionDescription;
}

/// 删除图层；撤销按原位置恢复全部内容与属性
class RemoveLayerAction extends EditorAction {
  RemoveLayerAction({required this.layerId});

  final String layerId;
  LayerData? _data;
  int _index = 0;

  @override
  void execute(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    if (layer == null) return;
    _data?.dispose();
    _data = layer.toData();
    _index = state.layerManager.indexOfLayer(layerId);
    state.layerManager.removeLayer(layerId);
  }

  @override
  void undo(EditorState state) {
    final data = _data;
    if (data == null) return;
    state.layerManager.insertLayerFromData(data, _index, setActive: true);
  }

  @override
  void dispose() {
    _data?.dispose();
    _data = null;
  }

  @override
  String get description => 'Delete Layer';
}

/// 在图层栈里移动一个图层；索引 0 在最上层
class ReorderLayerAction extends EditorAction {
  ReorderLayerAction({required this.fromIndex, required this.toIndex});

  final int fromIndex;
  final int toIndex;

  @override
  void execute(EditorState state) {
    state.layerManager.reorderLayer(fromIndex, toIndex);
  }

  @override
  void undo(EditorState state) {
    state.layerManager.reorderLayer(toIndex, fromIndex);
  }

  @override
  String get description => 'Reorder Layers';
}

/// 向下合并：像素已按上层的不透明度与混合模式烘焙进 [merged]
class MergeDownAction extends EditorAction {
  MergeDownAction({
    required this.upperId,
    required this.lowerId,
    required BakedLayerImage merged,
  }) : _merged = merged;

  final String upperId;
  final String lowerId;
  final BakedLayerImage _merged;
  LayerData? _upper;
  int _upperIndex = 0;
  LayerContentSnapshot? _lowerBefore;

  @override
  void execute(EditorState state) {
    final layers = state.layerManager;
    final upper = layers.getLayerById(upperId);
    final lower = layers.getLayerById(lowerId);
    if (upper == null || lower == null) return;
    _upper?.dispose();
    _upper = upper.toData();
    _upperIndex = layers.indexOfLayer(upperId);
    _lowerBefore?.dispose();
    _lowerBefore = lower.captureContent();
    layers.runBatch(() {
      layers.removeLayer(upperId);
      layers.replaceLayerBaseImageSync(
        lowerId,
        _merged.image.clone(),
        _merged.bytes,
        offset: _merged.offset,
      );
      layers.setActiveLayer(lowerId);
    });
  }

  @override
  void undo(EditorState state) {
    final upper = _upper;
    final lowerBefore = _lowerBefore;
    if (upper == null || lowerBefore == null) return;
    final layers = state.layerManager;
    layers.runBatch(() {
      layers.restoreLayerContent(lowerId, lowerBefore);
      layers.insertLayerFromData(upper, _upperIndex, setActive: true);
    });
  }

  @override
  void dispose() {
    _merged.dispose();
    _upper?.dispose();
    _upper = null;
    _lowerBefore?.dispose();
    _lowerBefore = null;
  }

  @override
  String get description => 'Merge Down';
}

/// 整层平移；撤销反向平移，不持有任何像素
class TranslateLayerAction extends EditorAction {
  TranslateLayerAction({required this.layerId, required this.delta});

  final String layerId;
  final Offset delta;

  @override
  void execute(EditorState state) {
    state.layerManager.translateLayer(layerId, delta);
  }

  @override
  void undo(EditorState state) {
    state.layerManager.translateLayer(layerId, -delta);
  }

  @override
  String get description => 'Move Layer';
}

/// 把选区像素剪到紧贴源图层上方的新图层，一步撤销同时恢复源图层、删除新图层并找回选区
class CutSelectionToLayerAction extends EditorAction {
  CutSelectionToLayerAction({
    required this.sourceId,
    required BakedLayerImage remainder,
    required LayerData cutLayer,
    required this.selection,
  }) : _remainder = remainder,
       _cutLayer = cutLayer;

  final String sourceId;
  final BakedLayerImage _remainder;
  final LayerData _cutLayer;
  final Path selection;
  LayerContentSnapshot? _sourceBefore;

  String get cutLayerId => _cutLayer.id;

  @override
  void execute(EditorState state) {
    final layers = state.layerManager;
    final source = layers.getLayerById(sourceId);
    if (source == null) return;
    _sourceBefore?.dispose();
    _sourceBefore = source.captureContent();
    layers.runBatch(() {
      layers.replaceLayerBaseImageSync(
        sourceId,
        _remainder.image.clone(),
        _remainder.bytes,
        offset: _remainder.offset,
      );
      layers.insertLayerFromData(
        _cutLayer,
        layers.indexOfLayer(sourceId),
        setActive: true,
      );
    });
    state.clearSelection(saveHistory: false);
  }

  @override
  void undo(EditorState state) {
    final before = _sourceBefore;
    if (before == null) return;
    final layers = state.layerManager;
    layers.runBatch(() {
      layers.removeLayer(_cutLayer.id);
      layers.restoreLayerContent(sourceId, before);
      layers.setActiveLayer(sourceId);
    });
    state.setSelection(selection, saveHistory: false);
  }

  @override
  void dispose() {
    _remainder.dispose();
    _cutLayer.dispose();
    _sourceBefore?.dispose();
    _sourceBefore = null;
  }

  @override
  String get description => 'Cut Selection';
}
