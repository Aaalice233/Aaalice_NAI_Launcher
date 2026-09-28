import 'package:flutter/material.dart';

/// Shared visual building block for prompt-category selection dialogs.
/// Business models and output encoding stay with each owning surface.
class PromptSelectionTile extends StatelessWidget {
  const PromptSelectionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.unavailableLabel,
    this.count,
    this.warning = false,
    this.indent = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String unavailableLabel;
  final int? count;
  final bool value;
  final bool enabled;
  final bool warning;
  final double indent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = warning ? colorScheme.tertiary : colorScheme.primary;
    return CheckboxListTile(
      value: enabled && value,
      onChanged: enabled ? (next) => onChanged(next ?? false) : null,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: Icon(
        icon,
        size: 20,
        color: enabled ? accent : colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 7),
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        enabled ? subtitle : unavailableLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
      contentPadding: EdgeInsetsDirectional.fromSTEB(14 + indent, 3, 14, 3),
      activeColor: accent,
      dense: true,
    );
  }
}
