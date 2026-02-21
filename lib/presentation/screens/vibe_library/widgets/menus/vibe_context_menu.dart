import 'package:flutter/material.dart';
import '../../../../widgets/common/themed_divider.dart';

/// Vibe上下文菜单项
class VibeMenuItem {
  final String id;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isDivider;
  final bool isDanger;

  const VibeMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.onTap,
    this.isDivider = false,
    this.isDanger = false,
  });

  const VibeMenuItem.divider()
      : id = '_divider',
        label = '',
        icon = null,
        onTap = null,
        isDivider = true,
        isDanger = false;
}

/// Vibe上下文菜单组件
/// 用于显示Vibe相关的右键/长按上下文菜单
class VibeContextMenu extends StatelessWidget {
  final Offset position;
  final List<VibeMenuItem> items;
  final void Function(VibeMenuItem) onSelect;

  const VibeContextMenu({
    super.key,
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.98)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  colorScheme.outlineVariant.withOpacity(isDark ? 0.15 : 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items.map((item) {
                if (item.isDivider) {
                  return const ThemedDivider(height: 1);
                }
                return _VibeContextMenuItem(
                  item: item,
                  onSelect: onSelect,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _VibeContextMenuItem extends StatefulWidget {
  final VibeMenuItem item;
  final void Function(VibeMenuItem) onSelect;

  const _VibeContextMenuItem({
    required this.item,
    required this.onSelect,
  });

  @override
  State<_VibeContextMenuItem> createState() => _VibeContextMenuItemState();
}

class _VibeContextMenuItemState extends State<_VibeContextMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor =
        widget.item.isDanger ? colorScheme.error : colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          widget.item.onTap?.call();
          widget.onSelect(widget.item);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          color: _isHovered
              ? (widget.item.isDanger
                  ? colorScheme.error.withOpacity(isDark ? 0.15 : 0.1)
                  : colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(
                  widget.item.icon,
                  size: 16,
                  color: _isHovered ? itemColor : itemColor.withOpacity(0.8),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: itemColor,
                    fontWeight:
                        _isHovered ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
