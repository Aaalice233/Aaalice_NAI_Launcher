import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import '../layers/layer.dart';
import '../core/history_manager.dart';

/// 项目版本号
const int projectVersion = 1;

/// 项目数据
class ProjectData {
  /// 版本号
  final int version;

  /// 画布宽度
  final int width;

  /// 画布高度
  final int height;

  /// 图层数据列表
  final List<LayerProjectData> layers;

  /// 当前活动图层ID
  final String? activeLayerId;

  /// 选区数据（SVG路径格式）
  final String? selectionPath;

  /// 前景色
  final int foregroundColor;

  /// 背景色
  final int backgroundColor;

  /// 创建时间
  final DateTime createdAt;

  /// 修改时间
  final DateTime modifiedAt;

  ProjectData({
    this.version = projectVersion,
    required this.width,
    required this.height,
    required this.layers,
    this.activeLayerId,
    this.selectionPath,
    this.foregroundColor = 0xFF000000,
    this.backgroundColor = 0xFFFFFFFF,
    DateTime? createdAt,
    DateTime? modifiedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  /// 从JSON创建
  factory ProjectData.fromJson(Map<String, dynamic> json) {
    return ProjectData(
      version: json['version'] as int? ?? 1,
      width: json['width'] as int,
      height: json['height'] as int,
      layers: (json['layers'] as List)
          .map((l) => LayerProjectData.fromJson(l as Map<String, dynamic>))
          .toList(),
      activeLayerId: json['activeLayerId'] as String?,
      selectionPath: json['selectionPath'] as String?,
      foregroundColor: json['foregroundColor'] as int? ?? 0xFF000000,
      backgroundColor: json['backgroundColor'] as int? ?? 0xFFFFFFFF,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'width': width,
      'height': height,
      'layers': layers.map((l) => l.toJson()).toList(),
      'activeLayerId': activeLayerId,
      'selectionPath': selectionPath,
      'foregroundColor': foregroundColor,
      'backgroundColor': backgroundColor,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }
}

/// 图层项目数据
class LayerProjectData {
  /// 图层ID
  final String id;

  /// 图层名称
  final String name;

  /// 是否可见
  final bool visible;

  /// 是否锁定
  final bool locked;

  /// 不透明度
  final double opacity;

  /// 混合模式
  final String blendMode;

  /// 图像数据（Base64编码的PNG）
  final String? imageData;

  /// 笔画数据
  final List<StrokeProjectData> strokes;

  LayerProjectData({
    required this.id,
    required this.name,
    this.visible = true,
    this.locked = false,
    this.opacity = 1.0,
    this.blendMode = 'normal',
    this.imageData,
    this.strokes = const [],
  });

  /// 从JSON创建
  factory LayerProjectData.fromJson(Map<String, dynamic> json) {
    return LayerProjectData(
      id: json['id'] as String,
      name: json['name'] as String,
      visible: json['visible'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: json['blendMode'] as String? ?? 'normal',
      imageData: json['imageData'] as String?,
      strokes: (json['strokes'] as List?)
              ?.map((s) => StrokeProjectData.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'visible': visible,
      'locked': locked,
      'opacity': opacity,
      'blendMode': blendMode,
      'imageData': imageData,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
  }
}

/// 笔画项目数据
class StrokeProjectData {
  /// 点列表 [x1, y1, x2, y2, ...]
  final List<double> points;

  /// 笔画大小
  final double size;

  /// 颜色值
  final int color;

  /// 不透明度
  final double opacity;

  /// 硬度
  final double hardness;

  /// 是否是橡皮擦
  final bool isEraser;

  StrokeProjectData({
    required this.points,
    required this.size,
    required this.color,
    required this.opacity,
    required this.hardness,
    this.isEraser = false,
  });

  /// 从JSON创建
  factory StrokeProjectData.fromJson(Map<String, dynamic> json) {
    return StrokeProjectData(
      points: (json['points'] as List).map((p) => (p as num).toDouble()).toList(),
      size: (json['size'] as num).toDouble(),
      color: json['color'] as int,
      opacity: (json['opacity'] as num).toDouble(),
      hardness: (json['hardness'] as num).toDouble(),
      isEraser: json['isEraser'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'points': points,
      'size': size,
      'color': color,
      'opacity': opacity,
      'hardness': hardness,
      'isEraser': isEraser,
    };
  }

  /// 从StrokeData创建
  factory StrokeProjectData.fromStrokeData(StrokeData stroke) {
    final points = <double>[];
    for (final point in stroke.points) {
      points.add(point.dx);
      points.add(point.dy);
    }

    return StrokeProjectData(
      points: points,
      size: stroke.size,
      color: stroke.color.value,
      opacity: stroke.opacity,
      hardness: stroke.hardness,
      isEraser: stroke.isEraser,
    );
  }

  /// 转换为StrokeData
  StrokeData toStrokeData() {
    final offsets = <Offset>[];
    // 确保有成对的坐标点，忽略奇数末尾
    final safeLength = (points.length ~/ 2) * 2;
    for (int i = 0; i + 1 < safeLength; i += 2) {
      offsets.add(Offset(points[i], points[i + 1]));
    }

    return StrokeData(
      points: offsets,
      size: size,
      color: Color(color),
      opacity: opacity,
      hardness: hardness,
      isEraser: isEraser,
    );
  }
}
