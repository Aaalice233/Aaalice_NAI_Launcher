import 'package:flutter/material.dart';

class PropertyField extends StatefulWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const PropertyField({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<PropertyField> createState() => _PropertyFieldState();
}

class _PropertyFieldState extends State<PropertyField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty) ...[
            Text(
              widget.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: widget.enabled
                    ? colorScheme.onSurfaceVariant.withOpacity(0.8)
                    : colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                _isFocused = hasFocus;
              });
            },
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : null,
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 32, // Dense height
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                      : colorScheme.surfaceContainerHighest.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border(
                    bottom: BorderSide(
                      color: _isFocused && widget.enabled
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: widget.enabled
                        ? colorScheme.onSurface
                        : colorScheme.outline,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
