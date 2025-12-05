import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_selection_tool.dart';

/// 矩形选区工具
class RectSelectionTool extends ShapeSelectionTool {
  @override
  String get id => 'rect_selection';

  @override
  String get name => '矩形选区';

  @override
  IconData get icon => Icons.crop_square;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyM;

  @override
  Path createShapePath(Rect rect) {
    return Path()..addRect(rect);
  }
}
