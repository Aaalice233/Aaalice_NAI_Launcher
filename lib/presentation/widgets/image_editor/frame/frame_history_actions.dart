import 'dart:ui';

import '../core/editor_state.dart';
import '../core/history_manager.dart';
import '../layers/layer.dart';

/// 取景框的缩放或平移；图层内容不受影响
class FrameChangeAction extends EditorAction {
  FrameChangeAction({
    required this.from,
    required this.to,
    this.actionDescription = 'Change Frame',
  });

  final Rect from;
  final Rect to;
  final String actionDescription;

  @override
  void execute(EditorState state) => state.setFrame(to);

  @override
  void undo(EditorState state) => state.setFrame(from);

  @override
  String get description => actionDescription;
}

/// 单个图层在裁切前后的完整内容
class CropToFrameLayerChange {
  CropToFrameLayerChange({
    required this.layerId,
    required this.before,
    required this.after,
  });

  final String layerId;
  final LayerContentSnapshot before;
  final LayerContentSnapshot after;

  void dispose() {
    before.dispose();
    after.dispose();
  }
}

/// 丢弃取景框外的内容；所有像素处理在执行前完成，执行与撤销都是同步的整体替换
class CropToFrameAction extends EditorAction {
  CropToFrameAction({required List<CropToFrameLayerChange> changes})
    : changes = List.unmodifiable(changes);

  final List<CropToFrameLayerChange> changes;

  @override
  void execute(EditorState state) => _apply(state, useAfter: true);

  @override
  void undo(EditorState state) => _apply(state, useAfter: false);

  void _apply(EditorState state, {required bool useAfter}) {
    state.layerManager.runBatch(() {
      for (final change in changes) {
        state.layerManager.restoreLayerContent(
          change.layerId,
          useAfter ? change.after : change.before,
        );
      }
    });
  }

  @override
  void dispose() {
    for (final change in changes) {
      change.dispose();
    }
  }

  @override
  String get description => 'Crop to Frame';
}
