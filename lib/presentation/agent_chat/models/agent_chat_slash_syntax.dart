import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 输入框开头 `/片段` 的词法：只认开头，不认识命令有哪些。

/// 输入框开头正在编辑的 `/片段`。
@immutable
class AgentChatSlashQuery {
  const AgentChatSlashQuery({required this.query, required this.end});

  /// 斜杠之后、边界之前的内容，刚敲下斜杠时为空。
  final String query;

  /// 片段结束下标（不含），替换时作为右边界。
  final int end;
}

/// 全角斜杠一并接受：中文输入法处于全角态时敲出的是 U+FF0F。
const Set<int> _slashCodeUnits = {0x2F, 0xFF0F};

const Set<int> _boundaryCodeUnits = {
  0x2F, // /
  0xFF0F, // ／
  0x20, // space
  0x09, // tab
  0x0A, // \n
  0x0D, // \r
  0x3000, // 全角空格
};

/// 仅识别输入框开头、且光标仍停在其中的 `/片段`；否则返回 null。
AgentChatSlashQuery? parseSlashQuery(TextEditingValue value) {
  final text = value.text;
  if (text.isEmpty || !_slashCodeUnits.contains(text.codeUnitAt(0))) {
    return null;
  }
  // 输入法预编辑期间文本仍在变动，此时弹菜单会跟着中间态抖动。
  if (value.composing.isValid && !value.composing.isCollapsed) return null;
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final end = _tokenEnd(text);
  final caret = selection.baseOffset;
  if (caret < 1 || caret > end) return null;
  return AgentChatSlashQuery(query: text.substring(1, end), end: end);
}

/// 取出开头的 `/名称` 与其后的正文；开头不是斜杠或名称为空时返回 null。
({String name, String trailingText})? parseLeadingSlashToken(String text) {
  if (text.isEmpty || !_slashCodeUnits.contains(text.codeUnitAt(0))) {
    return null;
  }
  final end = _tokenEnd(text);
  if (end <= 1) return null;
  return (
    name: text.substring(1, end),
    trailingText: text.substring(end).trim(),
  );
}

int _tokenEnd(String text) {
  var end = 1;
  while (end < text.length &&
      !_boundaryCodeUnits.contains(text.codeUnitAt(end))) {
    end++;
  }
  return end;
}
