import 'package:flutter/widgets.dart';

/// 主焦点是否在可编辑文本内；是则 Ctrl+A/Z 等编辑键应留给文本自身处理
bool isEditableTextFocused() =>
    _editableTextOf(FocusManager.instance.primaryFocus) != null;

/// 主焦点是否在可写输入框内，只读的可选中文本不算
bool isWritableTextFocused() =>
    _editableTextOf(FocusManager.instance.primaryFocus)?.readOnly == false;

/// [node] 是否是可编辑文本的焦点节点
bool isEditableTextNode(FocusNode node) => _editableTextOf(node) != null;

EditableText? _editableTextOf(FocusNode? node) {
  final focusedContext = node?.context;
  if (focusedContext == null) return null;
  final widget = focusedContext.widget;
  if (widget is EditableText) return widget;
  return focusedContext.findAncestorWidgetOfExactType<EditableText>();
}
