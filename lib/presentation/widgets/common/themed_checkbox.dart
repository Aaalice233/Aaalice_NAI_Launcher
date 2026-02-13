import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';

/// 主题化复选框组件
///
/// 使用立体效果设计，选中状态带有内阴影凹槽感，
/// 勾选标记带有凸起效果。支持三态（选中/未选中/部分选中）。
class ThemedCheckbox extends StatefulWidget {
  /// 当前值（null 表示部分选中状态，需要 tristate 为 true）
  final bool? value;

  /// 值改变回调
  final ValueChanged<bool?>? onChanged;

  /// 是否支持三态
  final bool tristate;

  /// 是否启用
  final bool enabled;

  /// 选中时的颜色
  final Color? activeColor;

  /// 勾选标记颜色
  final Color? checkColor;

  /// 边框颜色
  final Color? borderColor;

  /// 复选框大小
  final double size;

  const ThemedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.enabled = true,
    this.activeColor,
    this.checkColor,
    this.borderColor,
    this.size = 20.0,
  });

  @override
  State<ThemedCheckbox> createState() => _ThemedCheckboxState();
}

class _ThemedCheckboxState extends State<ThemedCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  bool _isHovered = false;
  // ignore: unused_field - used in GestureDetector callbacks for future press effects
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      value: (widget.value == true || widget.value == null) ? 1.0 : 0.0,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(ThemedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value == true || widget.value == null) {
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

    bool? newValue;
    if (widget.tristate) {
      // 三态循环：false -> true -> null -> false
      if (widget.value == false) {
        newValue = true;
      } else if (widget.value == true) {
        newValue = null;
      } else {
        newValue = false;
      }
    } else {
      // 二态切换
      newValue = !(widget.value ?? false);
    }

    widget.onChanged!(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appExt = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    // 颜色
    final activeColorBase = widget.activeColor ?? theme.colorScheme.primary;
    final checkColorBase = widget.checkColor ?? theme.colorScheme.onPrimary;
    final borderColorBase =
        widget.borderColor ?? theme.colorScheme.outline.withOpacity(0.5);

    // 内阴影参数
    final shadowDepth = appExt?.insetShadowDepth ?? 0.12;
    final enableInsetShadow = appExt?.enableInsetShadow ?? true;

    // 禁用状态透明度
    final opacity = widget.enabled ? 1.0 : 0.5;

    // 是否选中或部分选中
    final isCheckedOrPartial = widget.value == true || widget.value == null;

    // 背景色
    final backgroundColor = isCheckedOrPartial
        ? activeColorBase
        : (isDark
            ? Color.lerp(theme.colorScheme.surface, Colors.black, 0.3)!
            : Color.lerp(theme.colorScheme.surface, Colors.black, 0.02)!);

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
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCheckedOrPartial
                    ? activeColorBase
                    : (_isHovered
                        ? theme.colorScheme.primary.withOpacity(0.5)
                        : borderColorBase),
                width: 1.5,
              ),
              boxShadow: enableInsetShadow && isCheckedOrPartial
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(shadowDepth),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                        blurStyle: BlurStyle.inner,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedBuilder(
              animation: _scale,
              builder: (context, child) {
                if (_scale.value == 0) return const SizedBox.shrink();
                return Transform.scale(
                  scale: _scale.value,
                  child: _buildCheckmark(
                    checkColor: checkColorBase,
                    isPartial: widget.value == null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckmark({
    required Color checkColor,
    required bool isPartial,
  }) {
    if (isPartial) {
      // 部分选中 - 横线
      return Center(
        child: Container(
          width: widget.size * 0.5,
          height: 2,
          decoration: BoxDecoration(
            color: checkColor,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
    }

    // 完全选中 - 勾选标记
    return Icon(
      Icons.check,
      size: widget.size * 0.75,
      color: checkColor,
    );
  }
}

/// 带标签的主题化复选框
class ThemedCheckboxListTile extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final bool tristate;
  final bool enabled;
  final ListTileControlAffinity controlAffinity;
  final EdgeInsetsGeometry? contentPadding;

  const ThemedCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.tristate = false,
    this.enabled = true,
    this.controlAffinity = ListTileControlAffinity.leading,
    this.contentPadding,
  });

  bool? get _nextValue {
    if (tristate) {
      if (value == false) return true;
      if (value == true) return null;
      return false;
    }
    return !(value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return _CheckboxListTile(
      control: ThemedCheckbox(
        value: value,
        onChanged: onChanged,
        tristate: tristate,
        enabled: enabled,
      ),
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      controlAffinity: controlAffinity,
      contentPadding: contentPadding,
      onTap: enabled && onChanged != null
          ? () => onChanged!(_nextValue)
          : null,
    );
  }
}

/// 复选框列表项基础组件
class _CheckboxListTile extends StatelessWidget {
  final Widget control;
  final Widget title;
  final Widget? subtitle;
  final bool enabled;
  final ListTileControlAffinity controlAffinity;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;

  const _CheckboxListTile({
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
