import 'package:flutter/material.dart';

/// 随机词库管理器公共组件库
///
/// 包含可复用的 UI 组件，用于统一设计风格

/// 统计项组件
///
/// 支持水平和垂直两种布局模式
/// 用于显示带图标的统计数据
class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.layout = StatItemLayout.horizontal,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  /// 布局模式：horizontal（水平）或 vertical（垂直）
  final StatItemLayout layout;

  /// 是否使用 Expanded 包装（仅垂直布局有效）
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = layout == StatItemLayout.horizontal
        ? _buildHorizontal(theme)
        : _buildVertical(theme, colorScheme);

    if (expanded && layout == StatItemLayout.vertical) {
      return Expanded(child: content);
    }
    return content;
  }

  Widget _buildHorizontal(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildVertical(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 统计项布局模式
enum StatItemLayout {
  /// 水平布局：图标 标签: 值
  horizontal,

  /// 垂直布局：图标 -> 值 -> 标签
  vertical,
}

/// 区块标题组件
///
/// 带图标的渐变背景标题，用于分隔不同区域
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 对话框标题栏组件
///
/// 标准的对话框标题栏（标题 + 关闭按钮）
class DialogTitleBar extends StatelessWidget {
  const DialogTitleBar({
    super.key,
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 38.0,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            iconSize: 18,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

/// 概率进度条组件
///
/// 显示概率百分比的渐变进度条
/// 支持启用/禁用状态和悬停效果
class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({
    super.key,
    required this.probability,
    this.enabled = true,
    this.isHovered = false,
    this.height = 6.0,
    this.showLabel = true,
    this.useBadgeStyle = true,
  });

  final double probability;

  /// 是否启用状态（影响颜色）
  final bool enabled;

  /// 是否悬停状态（影响动画和阴影）
  final bool isHovered;

  /// 进度条高度
  final double height;

  /// 是否显示百分比标签
  final bool showLabel;

  /// 是否使用徽章样式（带背景）或简单文本样式
  final bool useBadgeStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor =
        enabled ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final secondaryColor =
        enabled ? colorScheme.secondary : colorScheme.onSurfaceVariant;
    final tertiaryColor =
        enabled ? colorScheme.tertiary : colorScheme.onSurfaceVariant;

    final percentValue = (probability * 100).toInt();

    return Row(
      children: [
        Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: enabled
                  ? colorScheme.surfaceContainerHighest
                  : primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: probability,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: isHovered
                        ? [primaryColor, tertiaryColor]
                        : enabled
                            ? [
                                primaryColor.withOpacity(0.9),
                                secondaryColor.withOpacity(0.7),
                              ]
                            : [
                                primaryColor.withOpacity(0.4),
                                secondaryColor.withOpacity(0.3),
                              ],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: (isHovered || enabled)
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          SizedBox(width: useBadgeStyle ? 8 : 6),
          if (useBadgeStyle)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$percentValue%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryColor.withOpacity(enabled ? 1.0 : 0.6),
                ),
              ),
            )
          else
            Text(
              '$percentValue%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
        ],
      ],
    );
  }
}

/// 图例项组件
///
/// 显示带图标的图例条目，通常用于图表
class ChartLegendItem extends StatelessWidget {
  const ChartLegendItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.valueUnit = '%',
  });

  final IconData icon;
  final String label;
  final dynamic value;
  final Color color;

  /// 值的单位后缀
  final String valueUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 12,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value$valueUnit',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
