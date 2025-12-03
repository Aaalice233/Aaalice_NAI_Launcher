import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tools/stroke.dart';
import 'tools/tool_type.dart';
import 'utils/command_manager.dart';

/// 图像编辑器控制器
/// 工具本身决定操作对象：
/// - brush/eraser: 在图像层绘制
/// - rectSelect/ellipseSelect: 创建遮罩选区
class ImageEditorController extends ChangeNotifier {
  /// 当前工具
  ToolType _currentTool = ToolType.brush;
  ToolType get currentTool => _currentTool;

  /// 笔刷设置
  BrushSettings _brushSettings = const BrushSettings();
  BrushSettings get brushSettings => _brushSettings;

  /// 当前颜色（默认红色，更容易在图像上看到）
  Color _currentColor = const Color(0xFFFF4444);
  Color get currentColor => _currentColor;

  /// IMAGE 层笔画
  final List<Stroke> _imageStrokes = [];
  List<Stroke> get imageStrokes => List.unmodifiable(_imageStrokes);

  /// MASK 选区路径
  Path? _maskPath;
  Path? get maskPath => _maskPath;

  /// MASK 历史记录（用于撤销/重做）
  final List<Path?> _maskHistory = [];
  final List<Path?> _maskRedoStack = [];
  static const int _maxMaskHistory = 30;

  /// 当前正在绘制的笔画
  Stroke? _currentStroke;
  Stroke? get currentStroke => _currentStroke;

  /// 画布变换
  double _scale = 1.0;
  double get scale => _scale;

  Offset _offset = Offset.zero;
  Offset get offset => _offset;

  /// 原始图像
  ui.Image? _baseImage;
  ui.Image? get baseImage => _baseImage;

  /// 原始图像字节数据
  Uint8List? _baseImageBytes;
  Uint8List? get baseImageBytes => _baseImageBytes;

  /// 命令管理器
  final CommandManager _commandManager = CommandManager();
  CommandManager get commandManager => _commandManager;

  /// 是否有修改
  bool get hasImageChanges => _imageStrokes.isNotEmpty;
  bool get hasMaskChanges => _maskPath != null;
  bool get hasChanges => hasImageChanges || hasMaskChanges;

  /// 设置基础图像
  Future<void> setBaseImage(Uint8List bytes) async {
    _baseImageBytes = bytes;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _baseImage = frame.image;
    notifyListeners();
  }

  /// 加载已有遮罩
  Future<void> loadExistingMask(Uint8List maskBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(maskBytes);
      final frame = await codec.getNextFrame();
      final maskImage = frame.image;

      // 将遮罩图像转换为路径（白色区域为选区）
      _maskPath = await _maskImageToPath(maskImage);
      maskImage.dispose();
      notifyListeners();
    } catch (e) {
      // 加载失败时忽略
      debugPrint('Failed to load existing mask: $e');
    }
  }

  /// 将遮罩图像转换为路径
  Future<Path?> _maskImageToPath(ui.Image maskImage) async {
    // 简化实现：创建一个覆盖整个图像的矩形路径
    // 实际上应该分析像素来重建精确路径，但这需要更复杂的实现
    // 这里我们假设存在遮罩就创建一个全图选区
    // 用户可以在编辑器中修改

    // 获取图像数据
    final byteData = await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final pixels = byteData.buffer.asUint8List();
    final width = maskImage.width;
    final height = maskImage.height;

    // 检查是否有非黑色像素
    bool hasWhitePixels = false;
    for (int i = 0; i < pixels.length; i += 4) {
      // RGBA: 检查红色通道（遮罩是白色，R=255）
      if (pixels[i] > 128) {
        hasWhitePixels = true;
        break;
      }
    }

    if (!hasWhitePixels) return null;

    // 简化：返回整个图像大小的路径
    // 真正的实现需要边缘检测算法
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  }

  /// 设置当前工具
  void setTool(ToolType tool) {
    if (_currentTool != tool) {
      _currentTool = tool;
      notifyListeners();
    }
  }

  /// 设置笔刷大小
  void setBrushSize(double size) {
    _brushSettings = _brushSettings.copyWith(size: size.clamp(1.0, 500.0));
    notifyListeners();
  }

  /// 设置笔刷不透明度
  void setBrushOpacity(double opacity) {
    _brushSettings = _brushSettings.copyWith(opacity: opacity.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// 设置笔刷硬度
  void setBrushHardness(double hardness) {
    _brushSettings = _brushSettings.copyWith(hardness: hardness.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// 设置笔刷预设
  void setBrushPreset(BrushPreset preset) {
    _brushSettings = BrushSettings.fromPreset(preset, size: _brushSettings.size);
    notifyListeners();
  }

  /// 设置当前颜色
  void setColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  /// 开始绘制
  void startStroke(Offset point) {
    // 选区工具使用白色，绘画工具使用当前颜色
    final color = _currentTool.isMaskTool ? Colors.white : _currentColor;
    _currentStroke = Stroke(
      points: [point],
      brush: _brushSettings,
      color: color,
      tool: _currentTool,
    );
    notifyListeners();
  }

  /// 继续绘制
  void updateStroke(Offset point) {
    if (_currentStroke != null) {
      _currentStroke = _currentStroke!.addPoint(point);
      notifyListeners();
    }
  }

  /// 结束绘制
  void endStroke() {
    if (_currentStroke != null && !_currentStroke!.isEmpty) {
      // 绘画工具（brush/eraser）：添加到图像层笔画
      // 选区工具（rectSelect/ellipseSelect）：通过 addRectSelection/addEllipseSelection 处理
      if (_currentTool.isPaintTool) {
        _commandManager.execute(
          AddStrokeCommand(
            strokes: _imageStrokes,
            stroke: _currentStroke!,
          ),
        );
      }
      _currentStroke = null;
      notifyListeners();
    }
  }

  /// 取消当前绘制（不保存）
  void cancelCurrentStroke() {
    if (_currentStroke != null) {
      _currentStroke = null;
      notifyListeners();
    }
  }

  /// 保存遮罩历史
  void _saveMaskHistory() {
    // 复制当前路径到历史
    _maskHistory.add(_maskPath != null ? Path.from(_maskPath!) : null);
    // 清空重做栈
    _maskRedoStack.clear();
    // 限制历史记录数量
    while (_maskHistory.length > _maxMaskHistory) {
      _maskHistory.removeAt(0);
    }
  }

  /// 将笔画添加到遮罩路径
  void _addStrokeToMaskPath(Stroke stroke) {
    if (stroke.points.isEmpty) return;

    // 保存历史以支持撤销
    _saveMaskHistory();

    final strokePath = Path();
    if (stroke.points.length == 1) {
      // 单点：画圆
      strokePath.addOval(
        Rect.fromCircle(
          center: stroke.points.first,
          radius: stroke.brush.size / 2,
        ),
      );
    } else {
      // 多点：连接成路径并添加宽度
      for (int i = 0; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        strokePath.addOval(
          Rect.fromCircle(
            center: point,
            radius: stroke.brush.size / 2,
          ),
        );
      }
    }

    if (stroke.tool == ToolType.eraser) {
      // 橡皮擦：从遮罩中减去
      if (_maskPath != null) {
        _maskPath = Path.combine(PathOperation.difference, _maskPath!, strokePath);
      }
    } else {
      // 画笔：添加到遮罩
      if (_maskPath == null) {
        _maskPath = strokePath;
      } else {
        _maskPath = Path.combine(PathOperation.union, _maskPath!, strokePath);
      }
    }
  }

  /// 添加矩形选区
  void addRectSelection(Rect rect, {bool additive = true}) {
    _saveMaskHistory();
    final rectPath = Path()..addRect(rect);
    _addSelectionPath(rectPath, additive: additive);
    notifyListeners();
  }

  /// 添加椭圆选区
  void addEllipseSelection(Rect rect, {bool additive = true}) {
    _saveMaskHistory();
    final ellipsePath = Path()..addOval(rect);
    _addSelectionPath(ellipsePath, additive: additive);
    notifyListeners();
  }

  void _addSelectionPath(Path path, {bool additive = true}) {
    if (additive) {
      if (_maskPath == null) {
        _maskPath = path;
      } else {
        _maskPath = Path.combine(PathOperation.union, _maskPath!, path);
      }
    } else {
      if (_maskPath != null) {
        _maskPath = Path.combine(PathOperation.difference, _maskPath!, path);
      }
    }
  }

  /// 撤销（基于当前工具类型）
  bool undo() {
    if (_currentTool.isPaintTool) {
      // 绘画工具：撤销笔画
      final result = _commandManager.undo();
      if (result) notifyListeners();
      return result;
    } else {
      // 选区工具：撤销遮罩
      if (_maskHistory.isEmpty) return false;
      _maskRedoStack.add(_maskPath != null ? Path.from(_maskPath!) : null);
      _maskPath = _maskHistory.removeLast();
      notifyListeners();
      return true;
    }
  }

  /// 重做（基于当前工具类型）
  bool redo() {
    if (_currentTool.isPaintTool) {
      // 绘画工具：重做笔画
      final result = _commandManager.redo();
      if (result) notifyListeners();
      return result;
    } else {
      // 选区工具：重做遮罩
      if (_maskRedoStack.isEmpty) return false;
      _maskHistory.add(_maskPath != null ? Path.from(_maskPath!) : null);
      _maskPath = _maskRedoStack.removeLast();
      notifyListeners();
      return true;
    }
  }

  /// 清除图像层（所有笔画）
  void clearImageLayer() {
    if (_imageStrokes.isNotEmpty) {
      _commandManager.execute(ClearStrokesCommand(strokes: _imageStrokes));
      notifyListeners();
    }
  }

  /// 清除遮罩层
  void clearMaskLayer() {
    if (_maskPath != null) {
      _saveMaskHistory();
      _maskPath = null;
      notifyListeners();
    }
  }

  /// 清除当前层（基于当前工具类型）
  void clearCurrentLayer() {
    if (_currentTool.isPaintTool) {
      clearImageLayer();
    } else {
      clearMaskLayer();
    }
  }

  /// 设置缩放
  void setScale(double scale) {
    _scale = scale.clamp(0.1, 10.0);
    notifyListeners();
  }

  /// 设置偏移
  void setOffset(Offset offset) {
    _offset = offset;
    notifyListeners();
  }

  /// 重置视图
  void resetView() {
    _scale = 1.0;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// 适应视口大小（图像居中显示）
  void fitToViewport(Size viewportSize, {double padding = 40.0}) {
    if (_baseImage == null) return;

    final imageWidth = _baseImage!.width.toDouble();
    final imageHeight = _baseImage!.height.toDouble();

    // 计算可用空间
    final availableWidth = viewportSize.width - padding * 2;
    final availableHeight = viewportSize.height - padding * 2;

    // 计算缩放比例
    final scaleX = availableWidth / imageWidth;
    final scaleY = availableHeight / imageHeight;
    _scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.1, 10.0);

    // 计算居中偏移
    final scaledWidth = imageWidth * _scale;
    final scaledHeight = imageHeight * _scale;
    _offset = Offset(
      (viewportSize.width - scaledWidth) / 2,
      (viewportSize.height - scaledHeight) / 2,
    );

    notifyListeners();
  }

  /// 是否可以撤销（基于当前工具类型）
  bool get canUndo => _currentTool.isPaintTool
      ? _commandManager.canUndo
      : _maskHistory.isNotEmpty;

  /// 是否可以重做（基于当前工具类型）
  bool get canRedo => _currentTool.isPaintTool
      ? _commandManager.canRedo
      : _maskRedoStack.isNotEmpty;

  @override
  void dispose() {
    _baseImage?.dispose();
    super.dispose();
  }
}
