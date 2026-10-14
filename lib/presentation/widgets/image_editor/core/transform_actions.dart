import 'dart:ui';

import '../layers/layer.dart';
import '../layers/layer_patch_baker.dart';
import 'editor_state.dart';
import 'history_manager.dart';

/// 自由变换会话在撤销栈里只占一条：会话里每次调整都就地改写这条记录的结果
sealed class TransformCommitAction extends EditorAction {
  TransformCommitAction({required this.layerId, BakedLayerImage? pixels})
    : _pixels = pixels;

  final String layerId;

  /// 为 null 表示像素全部移出范围，图层变空
  BakedLayerImage? _pixels;

  /// 用新结果替换上一次写入的像素；[pixels] 的所有权移交给操作
  void amend(EditorState state, BakedLayerImage? pixels, Path? selection);

  void _writePixels(EditorState state) {
    final pixels = _pixels;
    if (pixels == null) {
      state.layerManager.restoreLayerContent(
        layerId,
        const LayerContentSnapshot.empty(),
      );
    } else {
      state.layerManager.replaceLayerBaseRasterSync(
        layerId,
        pixels.raster.retain(),
        offset: pixels.offset,
      );
    }
  }

  void _replacePixels(BakedLayerImage? pixels) {
    _pixels?.dispose();
    _pixels = pixels;
  }

  @override
  void dispose() {
    _pixels?.dispose();
    _pixels = null;
  }

  @override
  String get description => 'Free Transform';
}

/// 变换已有图层；选区变换时选区随像素一起变换，撤销时一并换回
final class TransformLayerAction extends TransformCommitAction {
  TransformLayerAction({
    required super.layerId,
    required super.pixels,
    required Path? selectionBefore,
    required Path? selectionAfter,
  }) : _selectionBefore = selectionBefore,
       _selectionAfter = selectionAfter;

  final Path? _selectionBefore;
  Path? _selectionAfter;
  LayerContentSnapshot? _before;

  bool get _tracksSelection => _selectionBefore != null;

  @override
  void execute(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    if (layer == null) return;
    _before?.dispose();
    _before = layer.captureContent();
    _apply(state);
  }

  @override
  void undo(EditorState state) {
    final before = _before;
    if (before == null) return;
    state.layerManager.restoreLayerContent(layerId, before);
    if (_tracksSelection) {
      state.setSelection(_selectionBefore, saveHistory: false);
    }
  }

  @override
  void amend(EditorState state, BakedLayerImage? pixels, Path? selection) {
    _replacePixels(pixels);
    _selectionAfter = selection;
    _apply(state);
  }

  void _apply(EditorState state) {
    _writePixels(state);
    if (_tracksSelection) {
      state.setSelection(_selectionAfter, saveHistory: false);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _before?.dispose();
    _before = null;
  }
}

/// 导入的图片作为新图层落地；撤销即移除该图层
final class PlaceImageLayerAction extends TransformCommitAction {
  PlaceImageLayerAction({
    required super.layerId,
    required super.pixels,
    required this.name,
    required this.index,
  });

  final String name;
  final int index;

  @override
  void execute(EditorState state) {
    final pixels = _pixels;
    final data = LayerData(
      id: layerId,
      name: name,
      visible: true,
      locked: false,
      opacity: 1.0,
      content: pixels == null
          ? const LayerContentSnapshot.empty()
          : LayerContentSnapshot.shared(
              baseRaster: pixels.raster.retain(),
              baseImageOffset: pixels.offset,
            ),
    );
    try {
      state.layerManager.insertLayerFromData(data, index, setActive: true);
    } finally {
      data.dispose();
    }
  }

  @override
  void undo(EditorState state) {
    state.layerManager.removeLayer(layerId);
  }

  @override
  void amend(EditorState state, BakedLayerImage? pixels, Path? selection) {
    _replacePixels(pixels);
    _writePixels(state);
  }

  @override
  String get description => 'Place Image';
}
