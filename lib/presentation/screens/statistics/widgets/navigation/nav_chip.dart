import 'package:flutter/material.dart';

/// Navigation section data model
class NavSection {
  final String id;
  final IconData icon;
  final String label;
  final GlobalKey sectionKey;

  const NavSection({
    required this.id,
    required this.icon,
    required this.label,
    required this.sectionKey,
  });
}

/// Navigation chip button for statistics sections
class NavChip extends StatefulWidget {
  final NavSection section;
  final bool isActive;
  final VoidCallback onTap;
  final bool compactMode;

  const NavChip({
    super.key,
    required this.section,
    required this.isActive,
    required this.onTap,
    this.compactMode = false,
  });

  @override
  State<NavChip> createState() => _NavChipState();
}

class _NavChipState extends State<NavChip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Tooltip(
            message: widget.compactMode ? widget.section.label : '',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compactMode ? 12 : 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? colorScheme.primary
                    : _isHovered
                        ? colorScheme.surfaceContainerHighest
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isActive
                      ? colorScheme.primary
                      : _isHovered
                          ? colorScheme.outline.withOpacity(0.3)
                          : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.section.icon,
                    size: 18,
                    color: widget.isActive
                        ? colorScheme.onPrimary
                        : _isHovered
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                  if (!widget.compactMode) ...[
                    const SizedBox(width: 6),
                    Text(
                      widget.section.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: widget.isActive
                            ? colorScheme.onPrimary
                            : _isHovered
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                        fontWeight:
                            widget.isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
