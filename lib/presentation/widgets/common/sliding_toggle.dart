import 'package:flutter/material.dart';

/// 滑动切换组件 - 精致的分段切换器
///
/// 支持两个选项的切换，带有滑动高亮动画效果。
/// 可用于视图模式切换、开关切换等场景。
///
/// 示例:
/// ```dart
/// SlidingToggle<ViewMode>(
///   value: currentMode,
///   options: [
///     SlidingToggleOption(value: ViewMode.list, icon: Icons.view_list),
///     SlidingToggleOption(value: ViewMode.card, icon: Icons.grid_view),
///   ],
///   onChanged: (mode) => setState(() => currentMode = mode),
/// )
/// ```
class SlidingToggle<T> extends StatelessWidget {
  /// 当前选中的值
  final T value;

  /// 切换选项列表（必须恰好两个）
  final List<SlidingToggleOption<T>> options;

  /// 值变化回调
  final ValueChanged<T>? onChanged;

  /// 组件高度
  final double height;

  /// 单个选项宽度
  final double itemWidth;

  /// 图标大小
  final double iconSize;

  /// 外层圆角
  final double borderRadius;

  /// 滑块圆角
  final double thumbRadius;

  /// 动画时长
  final Duration animationDuration;

  /// 是否禁用
  final bool enabled;

  const SlidingToggle({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
    this.height = 32,
    this.itemWidth = 36,
    this.iconSize = 18,
    this.borderRadius = 8,
    this.thumbRadius = 6,
    this.animationDuration = const Duration(milliseconds: 200),
    this.enabled = true,
  }) : assert(options.length == 2, 'SlidingToggle requires exactly 2 options');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = options.indexWhere((o) => o.value == value);

    // 点击整个开关切换到另一个选项
    void toggle() {
      if (enabled && onChanged != null) {
        final otherIndex = selectedIndex == 0 ? 1 : 0;
        onChanged!(options[otherIndex].value);
      }
    }

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: toggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: height,
            width: itemWidth * 2,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Stack(
              children: [
                // 滑动高亮背景
                AnimatedPositioned(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                  left: selectedIndex == 0 ? 2 : itemWidth + 2,
                  top: 2,
                  child: Container(
                    width: itemWidth - 4,
                    height: height - 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(thumbRadius),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // 选项图标
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = index == selectedIndex;

                    return Container(
                      width: itemWidth,
                      height: height,
                      alignment: Alignment.center,
                      child: _buildOptionContent(
                        context,
                        option,
                        isSelected,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionContent(
    BuildContext context,
    SlidingToggleOption<T> option,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    // 如果有图标
    if (option.icon != null) {
      return Icon(
        option.icon,
        size: iconSize,
        color: color,
      );
    }

    // 如果有文本
    if (option.label != null) {
      return Text(
        option.label!,
        style: TextStyle(
          fontSize: iconSize * 0.7,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      );
    }

    // 如果有自定义 builder
    if (option.builder != null) {
      return option.builder!(context, isSelected, color);
    }

    return const SizedBox.shrink();
  }
}

/// 滑动切换选项
class SlidingToggleOption<T> {
  /// 选项值
  final T value;

  /// 图标（可选）
  final IconData? icon;

  /// 文本标签（可选）
  final String? label;

  /// 自定义内容构建器（可选）
  final Widget Function(BuildContext context, bool isSelected, Color color)?
      builder;

  /// 提示文本
  final String? tooltip;

  const SlidingToggleOption({
    required this.value,
    this.icon,
    this.label,
    this.builder,
    this.tooltip,
  }) : assert(
          icon != null || label != null || builder != null,
          'At least one of icon, label, or builder must be provided',
        );
}

/// 带标签的滑动切换组件
///
/// 在切换器两侧显示标签文本
class LabeledSlidingToggle<T> extends StatelessWidget {
  final T value;
  final List<SlidingToggleOption<T>> options;
  final ValueChanged<T>? onChanged;
  final double height;
  final double itemWidth;
  final double iconSize;
  final bool enabled;

  /// 左侧标签
  final String? leftLabel;

  /// 右侧标签
  final String? rightLabel;

  const LabeledSlidingToggle({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
    this.height = 32,
    this.itemWidth = 36,
    this.iconSize = 18,
    this.enabled = true,
    this.leftLabel,
    this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = options.indexWhere((o) => o.value == value);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leftLabel != null) ...[
          Text(
            leftLabel!,
            style: TextStyle(
              fontSize: 12,
              color: selectedIndex == 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              fontWeight:
                  selectedIndex == 0 ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
        ],
        SlidingToggle<T>(
          value: value,
          options: options,
          onChanged: onChanged,
          height: height,
          itemWidth: itemWidth,
          iconSize: iconSize,
          enabled: enabled,
        ),
        if (rightLabel != null) ...[
          const SizedBox(width: 8),
          Text(
            rightLabel!,
            style: TextStyle(
              fontSize: 12,
              color: selectedIndex == 1
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              fontWeight:
                  selectedIndex == 1 ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }
}
