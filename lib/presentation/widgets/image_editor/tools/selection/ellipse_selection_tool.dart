import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_selection_tool.dart';

/// 椭圆选区工具
class EllipseSelectionTool extends ShapeSelectionTool {
  @override
  String get id => 'ellipse_selection';

  @override
  String get name => '椭圆选区';

  @override
  IconData get icon => Icons.circle_outlined;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyU;

  @override
  Path createShapePath(Rect rect) {
    return Path()..addOval(rect);
  }
}
