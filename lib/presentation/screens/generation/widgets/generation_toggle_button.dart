import 'package:flutter/material.dart';

/// Compact pill toggle shared by generation controls.
class GenerationToggleButton extends StatefulWidget {
  const GenerationToggleButton({
    super.key,
    required this.label,
    required this.isEnabled,
    required this.onChanged,
  });

  final String label;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  State<GenerationToggleButton> createState() => _GenerationToggleButtonState();
}

class _GenerationToggleButtonState extends State<GenerationToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    if (widget.isEnabled) {
      backgroundColor = _isHovered
          ? theme.colorScheme.primary.withValues(alpha: 0.85)
          : theme.colorScheme.primary;
    } else {
      final baseColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      backgroundColor = _isHovered
          ? (isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1))
          : baseColor;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.isEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isEnabled
                  ? theme.colorScheme.primary
                  : (_isHovered
                        ? theme.colorScheme.outline.withValues(alpha: 0.4)
                        : theme.colorScheme.outline.withValues(alpha: 0.2)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isEnabled) ...[
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.isEnabled
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(
                          alpha: _isHovered ? 0.8 : 0.6,
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
