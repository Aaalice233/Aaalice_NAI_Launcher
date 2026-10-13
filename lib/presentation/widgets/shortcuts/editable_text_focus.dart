import 'package:flutter/widgets.dart';

/// 主焦点是否在可编辑文本内；是则 Ctrl+A/Z 等编辑键应留给文本自身处理
bool isEditableTextFocused() {
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) return false;
  return focusedContext.widget is EditableText ||
      focusedContext.findAncestorWidgetOfExactType<EditableText>() != null;
}
