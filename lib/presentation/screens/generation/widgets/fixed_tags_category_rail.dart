import 'package:flutter/material.dart';

/// A category destination shared by the positive and negative fixed-tag panes.
class FixedTagsRailDestination {
  const FixedTagsRailDestination({
    required this.id,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final int count;
  final IconData icon;
  final Color color;
}

/// Compact, pane-local category navigation for the fixed-tags sidebar.
///
/// The rail owns navigation presentation only. Filtering and selection state
/// remain with [FixedTagsSidebar], so both list and grid views share one source
/// of truth.
class FixedTagsCategoryRail extends StatelessWidget {
  const FixedTagsCategoryRail({
    super.key,
    required this.keyPrefix,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    required this.compact,
  });

  final String keyPrefix;
  final List<FixedTagsRailDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final bool compact;

  double get width => compact ? 48 : 68;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('$keyPrefix-category-rail'),
      width: width,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        itemCount: destinations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return _RailDestinationButton(
            key: ValueKey('$keyPrefix-category-${destination.id}'),
            destination: destination,
            selected: destination.id == selectedId,
            compact: compact,
            onTap: () => onSelected(destination.id),
          );
        },
      ),
    );
  }
}

class _RailDestinationButton extends StatelessWidget {
  const _RailDestinationButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final FixedTagsRailDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? destination.color
        : theme.colorScheme.onSurfaceVariant;
    final button = Semantics(
      button: true,
      selected: selected,
      label: '${destination.label} ${destination.count}',
      child: Material(
        color: selected
            ? destination.color.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 48 : 58),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 6,
                vertical: 6,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(destination.icon, size: 18, color: foreground),
                  if (!compact) ...[
                    const SizedBox(height: 3),
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    destination.count.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!compact) return button;
    return Tooltip(message: destination.label, child: button);
  }
}
