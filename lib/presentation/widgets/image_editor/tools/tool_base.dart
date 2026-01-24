import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';

/// 工具基类
/// 所有编辑器工具的抽象基类
abstract class EditorTool {
  /// 工具唯一标识
  String get id;

  /// 工具名称
  String get name;

  /// 工具图标
  IconData get icon;

  /// 工具提示
  String get tooltip => name;

  /// 快捷键
  LogicalKeyboardKey? get shortcutKey => null;

  /// 是否是选区工具
  bool get isSelectionTool => false;

  /// 是否是绘画工具
  bool get isPaintTool => false;

  /// 指针按下
  void onPointerDown(PointerDownEvent event, EditorState state);

  /// 指针移动
  void onPointerMove(PointerMoveEvent event, EditorState state);

  /// 指针抬起
  void onPointerUp(PointerUpEvent event, EditorState state);

  /// 指针悬停（用于拾色器等需要实时预览的工具）
  void onPointerHover(PointerHoverEvent event, EditorState state) {}

  /// 指针取消
  void onPointerCancel(EditorState state) {
    state.cancelStroke();
  }

  /// 快速停用（同步，无异步操作）
  /// 仅清理内存中的临时状态，不触发任何异步操作
  /// 用于实现即时工具切换
  void onDeactivateFast(EditorState state) {}

  /// 延迟激活（在下一帧异步执行）
  /// 用于资源预热、缓存更新等耗时操作
  /// 不会阻塞工具切换
  void onActivateDeferred(EditorState state) {}

  /// 构建设置面板
  Widget buildSettingsPanel(BuildContext context, EditorState state);

  /// 构建光标预览
  /// [screenCursorPosition] 是屏幕坐标系中的光标位置，用于定位覆盖层UI
  Widget? buildCursor(EditorState state, {Offset? screenCursorPosition}) =>
      null;

  /// 获取光标半径（用于画布显示）
  double getCursorRadius(EditorState state) => 10.0;
}

/// 画笔设置
class BrushSettings {
  /// 画笔大小 (1-500)
  final double size;

  /// 不透明度 (0-1)
  final double opacity;

  /// 硬度 (0-1)
  final double hardness;

  /// 画笔间距 (0.01-1)
  final double spacing;

  const BrushSettings({
    this.size = 20.0,
    this.opacity = 1.0,
    this.hardness = 0.8,
    this.spacing = 0.1,
  });

  BrushSettings copyWith({
    double? size,
    double? opacity,
    double? hardness,
    double? spacing,
  }) {
    return BrushSettings(
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      hardness: hardness ?? this.hardness,
      spacing: spacing ?? this.spacing,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'size': size,
      'opacity': opacity,
      'hardness': hardness,
      'spacing': spacing,
    };
  }

  factory BrushSettings.fromJson(Map<String, dynamic> json) {
    return BrushSettings(
      size: (json['size'] as num?)?.toDouble() ?? 20.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      hardness: (json['hardness'] as num?)?.toDouble() ?? 0.8,
      spacing: (json['spacing'] as num?)?.toDouble() ?? 0.1,
    );
  }
}

/// 选区模式
enum SelectionMode {
  /// 新建（替换现有选区）
  replace,

  /// 添加
  add,

  /// 减去
  subtract,

  /// 交叉
  intersect,
}

extension SelectionModeExtension on SelectionMode {
  String get label {
    switch (this) {
      case SelectionMode.replace:
        return '新建';
      case SelectionMode.add:
        return '添加';
      case SelectionMode.subtract:
        return '减去';
      case SelectionMode.intersect:
        return '交叉';
    }
  }

  IconData get icon {
    switch (this) {
      case SelectionMode.replace:
        return Icons.crop_square;
      case SelectionMode.add:
        return Icons.add_box_outlined;
      case SelectionMode.subtract:
        return Icons.indeterminate_check_box_outlined;
      case SelectionMode.intersect:
        return Icons.filter_none;
    }
  }
}

/// 选区设置
class SelectionSettings {
  /// 选区模式
  final SelectionMode mode;

  /// 羽化半径
  final double featherRadius;

  /// 是否反转
  final bool invert;

  const SelectionSettings({
    this.mode = SelectionMode.replace,
    this.featherRadius = 0.0,
    this.invert = false,
  });

  SelectionSettings copyWith({
    SelectionMode? mode,
    double? featherRadius,
    bool? invert,
  }) {
    return SelectionSettings(
      mode: mode ?? this.mode,
      featherRadius: featherRadius ?? this.featherRadius,
      invert: invert ?? this.invert,
    );
  }
}
