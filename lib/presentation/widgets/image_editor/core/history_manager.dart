import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/app_logger.dart';
import 'editor_state.dart';
import '../layers/layer.dart';
import '../layers/layer_patch_baker.dart';
import '../layers/layer_raster.dart';
import '../layers/layer_role.dart';
import '../layers/model3d_layer_data.dart';

/// 编辑器操作基类
abstract class EditorAction {
  /// 执行操作
  void execute(EditorState state);

  /// 撤销操作
  void undo(EditorState state);

  /// 释放操作持有的资源（如 ui.Image 缓存）
  ///
  /// 当操作从历史栈中移除（超出 maxHistorySize 或清空）时调用。
  void dispose() {}

  /// 操作描述
  String get description;

  /// 操作时间戳
  final DateTime timestamp = DateTime.now();
}

/// 历史管理器
/// 使用命令模式管理撤销/重做
class HistoryManager extends ChangeNotifier {
  /// 撤销栈
  final List<EditorAction> _undoStack = [];

  /// 重做栈
  final List<EditorAction> _redoStack = [];

  /// 最大历史记录数
  static const int maxHistorySize = 100;

  /// 是否可以撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 撤销栈大小
  int get undoStackSize => _undoStack.length;

  /// 重做栈大小
  int get redoStackSize => _redoStack.length;

  /// 执行操作
  void execute(EditorAction action, EditorState state) {
    action.execute(state);
    _undoStack.add(action);
    for (final a in _redoStack) {
      a.dispose();
    }
    _redoStack.clear();

    while (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0).dispose();
    }
    notifyListeners();
  }

  /// 撤销
  bool undo(EditorState state) {
    if (_undoStack.isEmpty) return false;

    final action = _undoStack.removeLast();
    action.undo(state);
    _redoStack.add(action);
    notifyListeners();
    return true;
  }

  /// 重做
  bool redo(EditorState state) {
    if (_redoStack.isEmpty) return false;

    final action = _redoStack.removeLast();
    action.execute(state);
    _undoStack.add(action);
    notifyListeners();
    return true;
  }

  /// 清空历史
  void clear() {
    for (final a in _undoStack) {
      a.dispose();
    }
    for (final a in _redoStack) {
      a.dispose();
    }
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  /// 获取撤销操作描述
  String? get undoDescription =>
      _undoStack.isNotEmpty ? _undoStack.last.description : null;

  /// 获取重做操作描述
  String? get redoDescription =>
      _redoStack.isNotEmpty ? _redoStack.last.description : null;
}

/// 添加笔画操作
class AddStrokeAction extends EditorAction {
  final String layerId;
  final StrokeData stroke;

  AddStrokeAction({required this.layerId, required this.stroke});

  @override
  void execute(EditorState state) {
    state.layerManager.addStrokeToLayer(layerId, stroke);
  }

  @override
  void undo(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    if (layer == null) {
      AppLogger.w('Layer $layerId not found for undo', 'ImageEditor');
      return;
    }
    state.layerManager.removeLastStrokeFromLayer(layerId);
  }

  @override
  String get description => 'Draw Stroke';
}

/// 清除图层操作
class ClearLayerAction extends EditorAction {
  final String layerId;
  LayerContentSnapshot? _previousContent;

  ClearLayerAction({required this.layerId});

  @override
  void execute(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    if (layer == null) return;

    _previousContent?.dispose();
    _previousContent = layer.captureContent();

    if (layer.hasBaseImage) {
      layer.clearBaseImage();
    }
    state.layerManager.clearLayer(layerId);
  }

  @override
  void undo(EditorState state) {
    final previous = _previousContent;
    if (previous == null) return;
    state.layerManager.restoreLayerContent(layerId, previous);
  }

  @override
  void dispose() {
    _previousContent?.dispose();
    _previousContent = null;
  }

  @override
  String get description => 'Clear Layer';
}

/// 调整画布大小操作
class ResizeCanvasAction extends EditorAction {
  final Size newSize;
  final CanvasResizeMode mode;
  Size? _previousSize;

  ResizeCanvasAction({required this.newSize, required this.mode});

  @override
  void execute(EditorState state) {
    _previousSize = state.canvasSize;
    final oldSize = _previousSize!;

    // 变换所有图层内容
    state.layerManager.transformAllLayers(oldSize, newSize, mode);

    // 更新画布尺寸
    state.setCanvasSize(newSize);
  }

  @override
  void undo(EditorState state) {
    if (_previousSize == null) return;

    final oldSize = state.canvasSize;
    final newSize = _previousSize!;

    // 反向变换图层内容
    // 注意：反向变换时使用相反的模式
    final reverseMode = _getReverseMode(mode);
    state.layerManager.transformAllLayers(oldSize, newSize, reverseMode);

    // 恢复画布尺寸
    state.setCanvasSize(newSize);
  }

  /// 获取反向变换模式
  CanvasResizeMode _getReverseMode(CanvasResizeMode mode) {
    switch (mode) {
      case CanvasResizeMode.crop:
        // 如果原来是裁剪（变小），反向就是填充（变大）
        return CanvasResizeMode.pad;
      case CanvasResizeMode.pad:
        // 如果原来是填充（变大），反向就是裁剪（变小）
        return CanvasResizeMode.crop;
      case CanvasResizeMode.stretch:
        // 拉伸模式反向仍然是拉伸
        return CanvasResizeMode.stretch;
    }
  }

  @override
  String get description => 'Resize Canvas (${mode.label})';
}

/// 选区随像素一起变化时，撤销/重做要把选区一并换回
class SelectionChange {
  const SelectionChange({required this.before, required this.after});

  final Path? before;
  final Path? after;
}

/// 替换图层图像操作（用于模糊、仿制图章等全图处理）
///
/// 新底图在构造前已就绪，execute/undo 都是同步的整体替换。
class ReplaceLayerImageAction extends EditorAction {
  final String layerId;

  /// 新底图在文档中的位置（渲染区域的左上角）
  final Offset newImageOffset;
  final String actionDescription;
  final SelectionChange? selectionChange;

  LayerRaster? _newPixels;

  /// 保存的旧内容（用于同步 undo）
  LayerContentSnapshot? _previousContent;

  /// [newImage] 的所有权移交给操作
  ReplaceLayerImageAction({
    required String layerId,
    required Uint8List? newImageBytes,
    required Image newImage,
    Offset newImageOffset = Offset.zero,
    String actionDescription = 'Replace Layer Image',
    SelectionChange? selectionChange,
  }) : this._(
         layerId: layerId,
         pixels: LayerRaster(newImage, bytes: newImageBytes),
         newImageOffset: newImageOffset,
         actionDescription: actionDescription,
         selectionChange: selectionChange,
       );

  /// [pixels] 的所有权移交给操作
  ReplaceLayerImageAction.baked({
    required String layerId,
    required BakedLayerImage pixels,
    required String actionDescription,
    SelectionChange? selectionChange,
  }) : this._(
         layerId: layerId,
         pixels: pixels.raster,
         newImageOffset: pixels.offset,
         actionDescription: actionDescription,
         selectionChange: selectionChange,
       );

  ReplaceLayerImageAction._({
    required this.layerId,
    required LayerRaster pixels,
    required this.newImageOffset,
    required this.actionDescription,
    required this.selectionChange,
  }) : _newPixels = pixels;

  @override
  void execute(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    final newPixels = _newPixels;
    if (layer == null || newPixels == null) return;

    _previousContent?.dispose();
    _previousContent = layer.captureContent();

    state.layerManager.replaceLayerBaseRasterSync(
      layerId,
      newPixels.retain(),
      offset: newImageOffset,
    );
    final change = selectionChange;
    if (change != null) {
      state.setSelection(change.after, saveHistory: false);
    }
  }

  @override
  void undo(EditorState state) {
    final previous = _previousContent;
    if (previous == null) return;
    state.layerManager.restoreLayerContent(layerId, previous);
    final change = selectionChange;
    if (change != null) {
      state.setSelection(change.before, saveHistory: false);
    }
  }

  @override
  void dispose() {
    _newPixels?.release();
    _newPixels = null;
    _previousContent?.dispose();
    _previousContent = null;
  }

  @override
  String get description => actionDescription;
}

/// 笔画数据（用于历史记录）
class StrokeData {
  final List<Offset> points;
  final double size;
  final Color color;
  final double opacity;
  final double hardness;
  final bool isEraser;

  StrokeData({
    required this.points,
    required this.size,
    required this.color,
    required this.opacity,
    required this.hardness,
    this.isEraser = false,
  });

  StrokeData copyWith({
    List<Offset>? points,
    double? size,
    Color? color,
    double? opacity,
    double? hardness,
    bool? isEraser,
  }) {
    return StrokeData(
      points: points ?? this.points,
      size: size ?? this.size,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      hardness: hardness ?? this.hardness,
      isEraser: isEraser ?? this.isEraser,
    );
  }
}

/// 图层完整数据（用于历史记录），[content] 持有底图克隆
class LayerData {
  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final double opacity;
  final LayerBlendMode blendMode;
  final LayerRole role;
  final Model3dLayerData? model3d;
  final LayerContentSnapshot content;

  LayerData({
    required this.id,
    required this.name,
    required this.visible,
    required this.locked,
    required this.opacity,
    this.blendMode = LayerBlendMode.normal,
    this.role = LayerRole.image,
    this.model3d,
    this.content = const LayerContentSnapshot.empty(),
  });

  void dispose() => content.dispose();
}
