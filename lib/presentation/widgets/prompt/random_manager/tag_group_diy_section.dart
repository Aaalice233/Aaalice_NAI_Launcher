import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

/// DIY 能力条目：未启用时提供添加，已启用时标记并提供编辑
class TagGroupDiySection extends StatefulWidget {
  const TagGroupDiySection({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onAdd,
    this.onEdit,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;

  @override
  State<TagGroupDiySection> createState() => _TagGroupDiySectionState();
}

class _TagGroupDiySectionState extends State<TagGroupDiySection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.enabled
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : _isHovered
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: widget.enabled
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: widget.enabled ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackContent =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) >= 2;
            final icon = Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.enabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            );
            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.enabled
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            final action = FilledButton.tonal(
              key: ValueKey('tag-group-diy-action-${widget.title}'),
              onPressed: widget.enabled ? widget.onEdit : widget.onAdd,
              child: Text(
                widget.enabled
                    ? AppLocalizations.of(context)!.common_edit
                    : AppLocalizations.of(context)!.common_add,
              ),
            );

            if (stackContent) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: description),
                    ],
                  ),
                  const SizedBox(height: 12),
                  action,
                ],
              );
            }
            return Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(child: description),
                if (widget.enabled) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, color: colorScheme.primary, size: 20),
                ],
                if (!widget.enabled || widget.onEdit != null) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
