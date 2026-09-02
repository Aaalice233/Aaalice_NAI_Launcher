import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';

/// Shared visual shell for gallery-like collection navigation.
class GallerySidebarSurface extends StatelessWidget {
  const GallerySidebarSurface({
    super.key,
    required this.child,
    this.footer,
    this.modal = false,
    this.width = 250,
  });

  final Widget child;
  final Widget? footer;
  final bool modal;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: modal ? double.infinity : width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: modal
            ? null
            : Border(
                right: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
      ),
      child: Column(
        children: [
          Expanded(child: child),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class GallerySidebarSectionHeader extends StatefulWidget {
  const GallerySidebarSectionHeader({
    super.key,
    required this.toggleKey,
    required this.icon,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    this.onCreate,
  });

  final Key toggleKey;
  final IconData icon;
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onCreate;

  @override
  State<GallerySidebarSectionHeader> createState() =>
      _GallerySidebarSectionHeaderState();
}

class _GallerySidebarSectionHeaderState
    extends State<GallerySidebarSectionHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minimumControlExtent = context.interactionPolicy.minimumControlExtent;
    final toggleLabel = widget.isExpanded
        ? context.l10n.common_collapse
        : context.l10n.common_expand;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        key: widget.toggleKey,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(
            alpha: _isHovered ? 0.11 : 0.06,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: widget.isExpanded,
                  label: '${widget.title}，$toggleLabel',
                  child: Tooltip(
                    message: toggleLabel,
                    child: InkWell(
                      onTap: widget.onToggle,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            Icon(
                              widget.isExpanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              widget.icon,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.onCreate != null) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: widget.onCreate,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.common_new),
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, minimumControlExtent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
