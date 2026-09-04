import 'package:flutter/material.dart';

import 'gallery_sidebar.dart';

/// Shared responsive toolbar layout for collection-style library pages.
///
/// The title and count stay together, search owns the remaining width, and
/// page-specific actions are supplied as slots so Vibe and Precise Reference
/// keep one responsive toolbar structure without coupling their commands.
class GalleryLibraryToolbar extends StatelessWidget {
  const GalleryLibraryToolbar({
    super.key,
    required this.compact,
    required this.title,
    required this.search,
    this.count,
    this.desktopActions = const [],
    this.compactHeaderActions = const [],
    this.compactSearchActions = const [],
  });

  final bool compact;
  final Widget title;
  final Widget? count;
  final Widget search;
  final List<Widget> desktopActions;
  final List<Widget> compactHeaderActions;
  final List<Widget> compactSearchActions;

  @override
  Widget build(BuildContext context) {
    return GalleryCollectionToolbarSurface(
      child: compact ? _buildCompact() : _buildDesktop(),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
        title,
        if (count != null) ...[const SizedBox(width: 8), count!],
        const SizedBox(width: GalleryCollectionChrome.toolbarGroupGap),
        Expanded(child: search),
        if (desktopActions.isNotEmpty) ...[
          const SizedBox(width: 8),
          ..._spaced(desktopActions, 6),
        ],
      ],
    );
  }

  Widget _buildCompact() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(child: title),
                  if (count != null) ...[const SizedBox(width: 8), count!],
                ],
              ),
            ),
            ...compactHeaderActions,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: search),
            if (compactSearchActions.isNotEmpty) ...[
              const SizedBox(width: 4),
              ..._spaced(compactSearchActions, 4),
            ],
          ],
        ),
      ],
    );
  }

  List<Widget> _spaced(List<Widget> children, double spacing) {
    return [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) SizedBox(width: spacing),
        children[index],
      ],
    ];
  }
}

class GalleryLibraryCountBadge extends StatelessWidget {
  const GalleryLibraryCountBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
