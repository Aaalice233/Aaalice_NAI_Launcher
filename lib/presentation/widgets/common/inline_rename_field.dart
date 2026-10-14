import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'focus_on_appear.dart';
import 'themed_input.dart';

/// 就地重命名输入框：挂载时从当前名称开始并取得焦点，每次挂载只结束一次
/// 回车提交去掉首尾空白的非空名称；空名、Esc、点外部都放弃修改
class InlineRenameField extends StatefulWidget {
  const InlineRenameField({
    super.key,
    required this.name,
    required this.onSubmit,
    required this.onCancel,
    this.style,
    this.decoration,
    this.framed = true,
  });

  final String name;

  final ValueChanged<String> onSubmit;

  final VoidCallback onCancel;

  final TextStyle? style;

  final InputDecoration? decoration;

  /// false 时不带输入色面，只显示文字与光标
  final bool framed;

  @override
  State<InlineRenameField> createState() => _InlineRenameFieldState();
}

class _InlineRenameFieldState extends State<InlineRenameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.name,
  );
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'InlineRename',
    onKeyEvent: _handleKeyEvent,
  );
  bool _finished = false;

  // Esc 在此消费，不能冒泡给外层面板或页面的 Esc 绑定
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) _cancel();
    return KeyEventResult.handled;
  }

  void _submit(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      _cancel();
      return;
    }
    if (_finished) return;
    _finished = true;
    widget.onSubmit(name);
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    widget.onCancel();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusOnAppear(
      child: widget.framed
          ? ThemedInput(
              controller: _controller,
              focusNode: _focusNode,
              style: widget.style,
              decoration: widget.decoration,
              onSubmitted: _submit,
              onTapOutside: (_) => _cancel(),
            )
          : TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: widget.style,
              decoration: widget.decoration ?? const InputDecoration(),
              onSubmitted: _submit,
              onTapOutside: (_) => _cancel(),
            ),
    );
  }
}
