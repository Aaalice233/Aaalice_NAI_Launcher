import 'package:flutter/material.dart';

/// Compact pill toggle shared by generation controls.
///
/// A null [onChanged] renders the toggle disabled.
class GenerationToggleButton extends StatefulWidget {
  const GenerationToggleButton({
    super.key,
    required this.label,
    required this.isEnabled,
    required this.onChanged,
  });

  final String label;
  final bool isEnabled;
  final ValueChanged<bool>? onChanged;

  @override
  State<GenerationToggleButton> createState() => _GenerationToggleButtonState();
}

class _GenerationToggleButtonState extends State<GenerationToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onChanged = widget.onChanged;
    final interactive = onChanged != null;
    final hovered = interactive && _isHovered;

    Color backgroundColor;
    if (widget.isEnabled) {
      backgroundColor = hovered
          ? theme.colorScheme.primary.withValues(alpha: 0.85)
          : theme.colorScheme.primary;
    } else {
      final baseColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      backgroundColor = hovered
          ? (isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1))
          : baseColor;
    }

    final toggle = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: interactive ? () => onChanged(!widget.isEnabled) : null,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
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
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.isEnabled
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface.withValues(
                            alpha: hovered ? 0.8 : 0.6,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      toggled: widget.isEnabled,
      enabled: interactive,
      child: interactive ? toggle : Opacity(opacity: 0.38, child: toggle),
    );
  }
}
