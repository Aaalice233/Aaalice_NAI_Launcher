import 'package:flutter/material.dart';

import 'input_surface_container.dart';

/// 安全的下拉框 - 自动验证value是否在items中
/// 复用共享填充色面与状态边界
class SafeDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final bool isExpanded;
  final double borderRadius;
  final Widget? icon;

  const SafeDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.isExpanded = true,
    this.borderRadius = 8.0,
    this.icon,
  });

  @override
  State<SafeDropdown<T>> createState() => _SafeDropdownState<T>();
}

class _SafeDropdownState<T> extends State<SafeDropdown<T>> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validValue = _validateValue();

    return InputSurfaceContainer(
      borderRadius: widget.borderRadius,
      isFocused: _focusNode.hasFocus,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: validValue,
          items: widget.items,
          onChanged: widget.onChanged,
          isExpanded: widget.isExpanded,
          focusNode: _focusNode,
          hint: widget.hintText != null
              ? Text(
                  widget.hintText!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                )
              : null,
          icon:
              widget.icon ??
              Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.zero,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
        ),
      ),
    );
  }

  T? _validateValue() {
    final itemValues = widget.items.map((item) => item.value).toList();
    return itemValues.contains(widget.value) ? widget.value : null;
  }
}
