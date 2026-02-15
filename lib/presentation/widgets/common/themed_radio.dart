import 'package:flutter/material.dart';

/// 主题化单选框组件
///
/// 使用立体效果设计，外圈带有内阴影凹槽感，
/// 选中点带有凸起效果。
class ThemedRadio<T> extends StatefulWidget {
  /// 该单选框代表的值
  final T value;

  /// 当前选中的值
  final T? groupValue;

  /// 值改变回调
  final ValueChanged<T?>? onChanged;

  /// 是否启用
  final bool enabled;

  /// 选中时的颜色
  final Color? activeColor;

  /// 单选框大小
  final double size;

  const ThemedRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
    this.size = 20.0,
  });

  @override
  State<ThemedRadio<T>> createState() => _ThemedRadioState<T>();
}

class _ThemedRadioState<T> extends State<ThemedRadio<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  bool _isHovered = false;
  // ignore: unused_field - used in GestureDetector callbacks for future press effects
  bool _isPressed = false;

  bool get _isSelected => widget.value == widget.groupValue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      value: _isSelected ? 1.0 : 0.0,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(ThemedRadio<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasSelected = oldWidget.value == oldWidget.groupValue;
    if (wasSelected != _isSelected) {
      if (_isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled || widget.onChanged == null) return;
    widget.onChanged!(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 颜色
    final activeColorBase = widget.activeColor ?? theme.colorScheme.primary;
    final borderColor = _isSelected
        ? activeColorBase
        : (_isHovered
            ? theme.colorScheme.primary.withOpacity(0.5)
            : theme.colorScheme.outline.withOpacity(0.5));

    // 背景色
    final backgroundColor = isDark
        ? Color.lerp(theme.colorScheme.surface, Colors.black, 0.3)!
        : Color.lerp(theme.colorScheme.surface, Colors.black, 0.02)!;

    // 禁用状态透明度
    final opacity = widget.enabled ? 1.0 : 0.5;

    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: Opacity(
          opacity: opacity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: _buildInnerDot(activeColorBase),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerDot(Color activeColor) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        if (_scale.value == 0) return const SizedBox.shrink();
        final dotSize = widget.size * 0.45 * _scale.value;
        return Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// 带标签的主题化单选框
class ThemedRadioListTile<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final bool enabled;
  final ListTileControlAffinity controlAffinity;
  final EdgeInsetsGeometry? contentPadding;

  const ThemedRadioListTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.controlAffinity = ListTileControlAffinity.leading,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectListTile(
      control: ThemedRadio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        enabled: enabled,
      ),
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      controlAffinity: controlAffinity,
      contentPadding: contentPadding,
      onTap: enabled && onChanged != null ? () => onChanged!(value) : null,
    );
  }
}

/// 选择列表项基础组件
class _SelectListTile extends StatelessWidget {
  final Widget control;
  final Widget title;
  final Widget? subtitle;
  final bool enabled;
  final ListTileControlAffinity controlAffinity;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;

  const _SelectListTile({
    required this.control,
    required this.title,
    this.subtitle,
    required this.enabled,
    required this.controlAffinity,
    this.contentPadding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (controlAffinity == ListTileControlAffinity.leading) ...[
              control,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: enabled
                              ? null
                              : Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color!
                                  .withOpacity(0.5),
                        ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color!
                                .withOpacity(enabled ? 0.7 : 0.4),
                          ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (controlAffinity == ListTileControlAffinity.trailing) ...[
              const SizedBox(width: 12),
              control,
            ],
          ],
        ),
      ),
    );
  }
}
