import 'package:flutter/material.dart';

import '../tools/tool_base.dart';
import '../tools/brush_tool.dart';
import '../tools/eraser_tool.dart';
import '../tools/selection/rect_selection_tool.dart';
import '../tools/selection/ellipse_selection_tool.dart';
import '../tools/selection/lasso_selection_tool.dart';
import '../tools/color_picker_tool.dart';
import 'tool_settings_manager.dart';

/// 工具管理器
/// 负责工具的注册、切换和状态管理
class ToolManager extends ChangeNotifier {
  /// 工具设置管理器
  final ToolSettingsManager settingsManager = ToolSettingsManager();

  /// 可用工具列表
  final List<EditorTool> _tools;

  /// 当前工具
  EditorTool? _currentTool;
  EditorTool? get currentTool => _currentTool;

  /// 上一个工具（用于普通切换时切回）
  EditorTool? _previousTool;

  /// 临时拾色器模式前的工具（与 _previousTool 独立）
  EditorTool? _toolBeforeTemporaryColorPicker;

  /// 是否处于临时拾色器模式
  bool _isTemporaryColorPickerMode = false;
  bool get isTemporaryColorPickerMode => _isTemporaryColorPickerMode;

  /// 工具切换通知器（轻量级，仅工具相关 UI 监听）
  /// 使用 ValueNotifier 避免触发全局重建
  final ValueNotifier<String?> toolNotifier = ValueNotifier(null);

  /// 构造函数
  ToolManager() : _tools = _createTools() {
    // 初始化时选中第一个工具
    if (_tools.isNotEmpty) {
      _currentTool = _tools.first;
      toolNotifier.value = _currentTool?.id;
    }
    // 异步加载持久化设置
    _loadSettingsAsync();
  }

  /// 异步加载持久化设置
  Future<void> _loadSettingsAsync() async {
    await settingsManager.load();
    // 恢复当前工具的设置
    if (_currentTool != null) {
      _restoreToolSettings(_currentTool!);
    }
  }

  /// 获取所有工具（只读）
  List<EditorTool> get tools => List.unmodifiable(_tools);

  /// 设置当前工具
  void setTool(EditorTool tool) {
    if (_currentTool != tool) {
      // 保存当前工具设置
      if (_currentTool != null) {
        _saveToolSettings(_currentTool!);
      }

      _previousTool = _currentTool;
      _currentTool = tool;

      // 恢复新工具设置
      _restoreToolSettings(tool);

      // 只通知工具切换，不触发画布重绘
      toolNotifier.value = tool.id;
    }
  }

  /// 保存工具设置
  void _saveToolSettings(EditorTool tool) {
    if (tool is BrushTool) {
      settingsManager.setSetting(tool.id, 'settings', tool.settings.toJson());
      settingsManager.setSetting(tool.id, 'presetIndex', tool.selectedPresetIndex);
    } else if (tool is EraserTool) {
      settingsManager.setSetting(tool.id, 'size', tool.size);
      settingsManager.setSetting(tool.id, 'hardness', tool.hardness);
    }
    // 异步保存到本地存储
    settingsManager.save();
  }

  /// 恢复工具设置
  void _restoreToolSettings(EditorTool tool) {
    final settings = settingsManager.getToolSettings(tool.id);
    if (settings == null) return;

    if (tool is BrushTool) {
      final brushSettings = settings['settings'];
      if (brushSettings is Map<String, dynamic>) {
        tool.updateSettings(BrushSettings.fromJson(brushSettings));
      }
      final presetIndex = settings['presetIndex'];
      if (presetIndex is int) {
        // 直接设置预设索引，不触发额外操作
        tool.setSelectedPresetIndex(presetIndex);
      }
    } else if (tool is EraserTool) {
      final size = settings['size'];
      if (size is num) {
        tool.setSize(size.toDouble());
      }
      final hardness = settings['hardness'];
      if (hardness is num) {
        tool.setHardness(hardness.toDouble());
      }
    }
  }

  /// 通过ID设置工具
  void setToolById(String toolId) {
    final tool = _tools.firstWhere(
      (t) => t.id == toolId,
      orElse: () => _tools.first,
    );
    setTool(tool);
  }

  /// 切回上一个工具
  void switchToPreviousTool() {
    if (_previousTool != null) {
      final temp = _currentTool;
      _currentTool = _previousTool;
      _previousTool = temp;
      // 只通知工具切换，不触发画布重绘
      toolNotifier.value = _currentTool?.id;
    }
  }

  /// 进入临时拾色器模式（Alt 按下）
  void enterTemporaryColorPicker() {
    if (_isTemporaryColorPickerMode) return; // 防止重复进入

    _isTemporaryColorPickerMode = true;
    _toolBeforeTemporaryColorPicker = _currentTool;

    // 切换到拾色器
    final colorPicker = getToolById('color_picker');
    if (colorPicker != null) {
      _currentTool = colorPicker;
      toolNotifier.value = colorPicker.id;
    }
  }

  /// 退出临时拾色器模式（Alt 松开）
  void exitTemporaryColorPicker() {
    if (!_isTemporaryColorPickerMode) return;

    _isTemporaryColorPickerMode = false;

    // 切回之前的工具
    if (_toolBeforeTemporaryColorPicker != null) {
      _currentTool = _toolBeforeTemporaryColorPicker;
      toolNotifier.value = _currentTool?.id;
      _toolBeforeTemporaryColorPicker = null;
    }
  }

  /// 通过ID获取工具
  EditorTool? getToolById(String id) {
    try {
      return _tools.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 创建所有工具实例
  static List<EditorTool> _createTools() {
    return [
      BrushTool(),
      EraserTool(),
      RectSelectionTool(),
      EllipseSelectionTool(),
      LassoSelectionTool(),
      ColorPickerTool(),
    ];
  }

  @override
  void dispose() {
    // 保存当前工具设置
    if (_currentTool != null) {
      _saveToolSettings(_currentTool!);
    }
    toolNotifier.dispose();
    super.dispose();
  }
}
