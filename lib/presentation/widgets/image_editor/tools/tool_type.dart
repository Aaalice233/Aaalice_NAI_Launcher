import 'package:flutter/material.dart';

/// 工具类型
/// 工具本身决定操作对象：
/// - brush/eraser: 在图像层绘制 → 输出到 sourceImage
/// - rectSelect/ellipseSelect: 创建遮罩选区 → 输出到 maskImage
enum ToolType {
  brush, // 画笔（图像层）
  eraser, // 橡皮擦（图像层）
  rectSelect, // 矩形选框（遮罩层）
  ellipseSelect, // 椭圆选框（遮罩层）
}

/// 工具类型扩展
extension ToolTypeExtension on ToolType {
  /// 获取工具图标
  IconData get icon {
    switch (this) {
      case ToolType.brush:
        return Icons.brush;
      case ToolType.eraser:
        return Icons.auto_fix_normal;
      case ToolType.rectSelect:
        return Icons.crop_square;
      case ToolType.ellipseSelect:
        return Icons.circle_outlined;
    }
  }

  /// 是否是遮罩工具（选区工具）
  bool get isMaskTool {
    switch (this) {
      case ToolType.brush:
      case ToolType.eraser:
        return false;
      case ToolType.rectSelect:
      case ToolType.ellipseSelect:
        return true;
    }
  }

  /// 是否是绘画工具
  bool get isPaintTool {
    switch (this) {
      case ToolType.brush:
      case ToolType.eraser:
        return true;
      case ToolType.rectSelect:
      case ToolType.ellipseSelect:
        return false;
    }
  }
}

/// 笔刷预设
enum BrushPreset {
  defaultBrush, // 默认
  pencil, // 铅笔
  marker, // 马克笔
  airbrush, // 喷枪
  inkPen, // 墨水笔
  pixel, // 像素
}

extension BrushPresetExtension on BrushPreset {
  String get label {
    switch (this) {
      case BrushPreset.defaultBrush:
        return 'Default';
      case BrushPreset.pencil:
        return 'Pencil';
      case BrushPreset.marker:
        return 'Marker';
      case BrushPreset.airbrush:
        return 'Airbrush';
      case BrushPreset.inkPen:
        return 'Ink Pen';
      case BrushPreset.pixel:
        return 'Pixel';
    }
  }

  IconData get icon {
    switch (this) {
      case BrushPreset.defaultBrush:
        return Icons.circle;
      case BrushPreset.pencil:
        return Icons.edit;
      case BrushPreset.marker:
        return Icons.highlight;
      case BrushPreset.airbrush:
        return Icons.blur_on;
      case BrushPreset.inkPen:
        return Icons.create;
      case BrushPreset.pixel:
        return Icons.grid_on;
    }
  }

  /// 获取预设的默认硬度
  double get defaultHardness {
    switch (this) {
      case BrushPreset.defaultBrush:
        return 0.8;
      case BrushPreset.pencil:
        return 1.0;
      case BrushPreset.marker:
        return 0.6;
      case BrushPreset.airbrush:
        return 0.2;
      case BrushPreset.inkPen:
        return 1.0;
      case BrushPreset.pixel:
        return 1.0;
    }
  }

  /// 获取预设的默认不透明度
  double get defaultOpacity {
    switch (this) {
      case BrushPreset.defaultBrush:
        return 1.0;
      case BrushPreset.pencil:
        return 0.9;
      case BrushPreset.marker:
        return 0.7;
      case BrushPreset.airbrush:
        return 0.5;
      case BrushPreset.inkPen:
        return 1.0;
      case BrushPreset.pixel:
        return 1.0;
    }
  }
}
