import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';

/// Shared geometry for collection pages that pair a navigation sidebar with a
/// content toolbar. Keeping both regions on one vertical rhythm prevents the
/// library screens from drifting as their controls evolve independently.
abstract final class GalleryCollectionChrome {
  static const sidebarWidth = 250.0;
  static const toolbarHeight = 72.0;
  static const navigationTopPadding = 4.0;

  static EdgeInsets toolbarPadding(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: 16,
        vertical: context.interactionPolicy.shouldExposeTouchAlternatives
            ? 11
            : 12,
      );
}

/// Page identity shown at the top of persistent collection sidebars.
///
/// Compact layouts keep their identity in the content toolbar because the
/// sidebar is presented as a temporary panel with its own route title.
class GallerySidebarPageHeader extends StatelessWidget {
  const GallerySidebarPageHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: GalleryCollectionChrome.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared visual shell for gallery-like collection navigation.
class GallerySidebarSurface extends StatelessWidget {
  const GallerySidebarSurface({
    super.key,
    required this.child,
    this.footer,
    this.modal = false,
    this.width = GalleryCollectionChrome.sidebarWidth,
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

/// Shared leaf row used inside gallery-like sidebar sections.
///
/// Root entries such as "All" remain visually prominent; favorites and other
/// section children use this quieter, consistently indented treatment.
class GallerySidebarNavigationItem extends StatefulWidget {
  const GallerySidebarNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.selectedIcon,
    this.iconColor,
    this.depth = 0,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final Color? iconColor;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final int depth;

  @override
  State<GallerySidebarNavigationItem> createState() =>
      _GallerySidebarNavigationItemState();
}

/// Built-in favorites category shared by gallery-like sidebars.
class GallerySidebarFavoritesItem extends StatelessWidget {
  const GallerySidebarFavoritesItem({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.depth = 0,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return GallerySidebarNavigationItem(
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
      iconColor: Theme.of(context).colorScheme.error,
      label: label,
      count: count,
      isSelected: isSelected,
      onTap: onTap,
      depth: depth,
    );
  }
}

class _GallerySidebarNavigationItemState
    extends State<GallerySidebarNavigationItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const controlExtent = 48.0;
    final indent = (12.0 + widget.depth * 16.0).clamp(12.0, 44.0);

    return Semantics(
      button: true,
      selected: widget.isSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colors.primaryContainer
                : _isHovered
                ? colors.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: controlExtent),
              child: Padding(
                padding: EdgeInsets.only(left: indent, right: 8),
                child: Row(
                  children: [
                    const SizedBox.square(dimension: controlExtent),
                    Icon(
                      widget.isSelected
                          ? widget.selectedIcon ?? widget.icon
                          : widget.icon,
                      size: 18,
                      color:
                          widget.iconColor ??
                          (widget.isSelected
                              ? colors.primary
                              : colors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.isSelected
                              ? colors.primary
                              : colors.onSurface,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.count.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.72),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
