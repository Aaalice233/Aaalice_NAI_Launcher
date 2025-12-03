import 'dart:ui';

import 'tool_type.dart';

/// 笔刷设置
class BrushSettings {
  final double size; // 1-500px
  final double opacity; // 0-1
  final double hardness; // 0-1
  final double spacing; // 0.01-1
  final BrushPreset preset;

  const BrushSettings({
    this.size = 20.0,
    this.opacity = 1.0,
    this.hardness = 0.8,
    this.spacing = 0.1,
    this.preset = BrushPreset.defaultBrush,
  });

  BrushSettings copyWith({
    double? size,
    double? opacity,
    double? hardness,
    double? spacing,
    BrushPreset? preset,
  }) {
    return BrushSettings(
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      hardness: hardness ?? this.hardness,
      spacing: spacing ?? this.spacing,
      preset: preset ?? this.preset,
    );
  }

  /// 从预设创建设置
  factory BrushSettings.fromPreset(BrushPreset preset, {double? size}) {
    return BrushSettings(
      size: size ?? 20.0,
      opacity: preset.defaultOpacity,
      hardness: preset.defaultHardness,
      preset: preset,
    );
  }
}

/// 笔画数据
class Stroke {
  final List<Offset> points;
  final BrushSettings brush;
  final Color color;
  final ToolType tool;

  const Stroke({
    required this.points,
    required this.brush,
    required this.color,
    required this.tool,
  });

  Stroke copyWith({
    List<Offset>? points,
    BrushSettings? brush,
    Color? color,
    ToolType? tool,
  }) {
    return Stroke(
      points: points ?? this.points,
      brush: brush ?? this.brush,
      color: color ?? this.color,
      tool: tool ?? this.tool,
    );
  }

  /// 添加点
  Stroke addPoint(Offset point) {
    return copyWith(points: [...points, point]);
  }

  /// 是否为空笔画
  bool get isEmpty => points.isEmpty;

  /// 是否只有一个点
  bool get isSinglePoint => points.length == 1;
}

/// 选区路径（用于 MASK 模式）
class SelectionPath {
  final Path path;
  final SelectionType type;
  final bool isAdditive; // true=添加 false=减去

  const SelectionPath({
    required this.path,
    required this.type,
    this.isAdditive = true,
  });
}

/// 选区类型
enum SelectionType {
  rect, // 矩形
  ellipse, // 椭圆
  lasso, // 套索
  brush, // 画笔
}
