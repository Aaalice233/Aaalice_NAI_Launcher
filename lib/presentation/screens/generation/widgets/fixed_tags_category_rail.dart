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
  });

  final String keyPrefix;
  final List<FixedTagsRailDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('$keyPrefix-category-rail'),
      width: 48,
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
            hoverLabelKey: '$keyPrefix-category-${destination.id}-hover-label',
            onTap: () => onSelected(destination.id),
          );
        },
      ),
    );
  }
}

class _RailDestinationButton extends StatefulWidget {
  const _RailDestinationButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.hoverLabelKey,
    required this.onTap,
  });

  final FixedTagsRailDestination destination;
  final bool selected;
  final String hoverLabelKey;
  final VoidCallback onTap;

  @override
  State<_RailDestinationButton> createState() => _RailDestinationButtonState();
}

class _RailDestinationButtonState extends State<_RailDestinationButton> {
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();
  var _hovered = false;
  var _focused = false;

  void _syncLabelOverlay() {
    if (_hovered || _focused) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = widget.selected
        ? widget.destination.color
        : theme.colorScheme.onSurfaceVariant;
    final button = Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.destination.label} ${widget.destination.count}',
      child: Material(
        color: widget.selected
            ? widget.destination.color.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.destination.icon, size: 18, color: foreground),
                  const SizedBox(height: 2),
                  Text(
                    widget.destination.count.toString(),
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

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.centerRight,
          followerAnchor: Alignment.centerLeft,
          offset: const Offset(6, 0),
          child: IgnorePointer(
            child: UnconstrainedBox(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) => Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.96 + progress * 0.04,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                ),
                child: Material(
                  key: ValueKey(widget.hoverLabelKey),
                  elevation: 4,
                  color: Color.alphaBlend(
                    widget.destination.color.withValues(alpha: 0.12),
                    theme.colorScheme.surfaceContainerHigh,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        widget.destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          onEnter: (_) {
            _hovered = true;
            _syncLabelOverlay();
          },
          onExit: (_) {
            _hovered = false;
            _syncLabelOverlay();
          },
          child: Focus(
            onFocusChange: (focused) {
              _focused = focused;
              _syncLabelOverlay();
            },
            child: button,
          ),
        ),
      ),
    );
  }
}
