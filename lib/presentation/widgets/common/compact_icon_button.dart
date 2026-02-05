import 'package:flutter/material.dart';
import '../shortcuts/shortcut_tooltip.dart';

/// Compact icon button with optional label for toolbars
/// 工具栏紧凑图标按钮（可带标签）
class CompactIconButton extends StatefulWidget {
  /// Icon to display
  /// 显示的图标
  final IconData icon;

  /// Optional label text
  /// 可选的标签文本
  final String? label;

  /// Tooltip text (defaults to label if not provided)
  /// 提示文本（未提供时默认使用标签）
  final String? tooltip;

  /// Callback when button is pressed
  /// 按钮点击回调
  final VoidCallback? onPressed;

  /// Whether the button is in active state
  /// 按钮是否处于激活状态
  final bool isActive;

  /// Whether to use danger color scheme
  /// 是否使用危险颜色方案
  final bool isDanger;

  /// Shortcut ID for displaying keyboard shortcut in tooltip
  /// 快捷键ID（用于在提示中显示键盘快捷键）
  final String? shortcutId;

  const CompactIconButton({
    super.key,
    required this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
    this.isActive = false,
    this.isDanger = false,
    this.shortcutId,
  });

  @override
  State<CompactIconButton> createState() => _CompactIconButtonState();
}

class _CompactIconButtonState extends State<CompactIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;

    Color iconColor;
    Color bgColor;
    Color borderColor;

    if (widget.isDanger) {
      iconColor = theme.colorScheme.error;
      bgColor = _isHovered
          ? theme.colorScheme.error.withOpacity(isDark ? 0.2 : 0.12)
          : theme.colorScheme.error.withOpacity(isDark ? 0.08 : 0.04);
      borderColor = theme.colorScheme.error.withOpacity(isDark ? 0.3 : 0.2);
    } else if (widget.isActive) {
      iconColor = theme.colorScheme.primary;
      bgColor = _isHovered
          ? theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.15)
          : theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08);
      borderColor = theme.colorScheme.primary.withOpacity(isDark ? 0.4 : 0.25);
    } else {
      iconColor = isEnabled
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurfaceVariant.withOpacity(0.4);
      bgColor = _isHovered
          ? theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.15 : 0.1)
          : theme.colorScheme.onSurfaceVariant
              .withOpacity(isDark ? 0.06 : 0.03);
      borderColor =
          theme.colorScheme.outlineVariant.withOpacity(isDark ? 0.3 : 0.4);
    }

    final buttonContent = MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: hasLabel ? 10 : 6,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: iconColor),
              if (hasLabel) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: iconColor,
                    fontWeight:
                        _isHovered ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // 如果提供了shortcutId，使用ShortcutTooltip包装
    if (widget.shortcutId != null) {
      return ShortcutTooltip(
        message: widget.tooltip ?? widget.label ?? '',
        shortcutId: widget.shortcutId,
        child: buttonContent,
      );
    }

    // 否则使用普通Tooltip
    return Tooltip(
      message: widget.tooltip ?? widget.label ?? '',
      child: buttonContent,
    );
  }
}
