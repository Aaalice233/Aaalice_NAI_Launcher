import 'package:flutter/material.dart';

/// 文本选择工具类
///
/// 提供 TextEditingController 的选中文本相关操作
class TextSelectionUtils {
  TextSelectionUtils._();

  /// 获取当前选中的文本
  ///
  /// 如果没有选中文本，返回空字符串
  ///
  /// 参数:
  /// - [controller]: 文本编辑控制器
  ///
  /// 返回:
  /// - 选中的文本内容，如果没有选中则返回空字符串
  static String getSelectedText(TextEditingController controller) {
    final selection = controller.selection;
    if (selection.start == selection.end) {
      return '';
    }
    return controller.text.substring(selection.start, selection.end);
  }

  /// 检查是否有选中的文本
  ///
  /// 参数:
  /// - [controller]: 文本编辑控制器
  ///
  /// 返回:
  /// - 如果有选中的文本返回 true，否则返回 false
  static bool hasSelection(TextEditingController controller) {
    final selection = controller.selection;
    return selection.start != selection.end;
  }
}
