import 'package:flutter/material.dart';

/// A common collapsible panel with optional background image support.
///
/// Used for Precise Reference, Vibe Transfer, and Img2Img panels.
class CollapsibleImagePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget? backgroundImage;
  final bool hasData;
  final Widget? badge;
  final Widget? trailing;
  final Widget child;

  const CollapsibleImagePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    this.backgroundImage,
    this.hasData = false,
    this.badge,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBackground = hasData && !isExpanded;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Image Layer
          if (showBackground && backgroundImage != null)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  backgroundImage!,
                  // Dark Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Content Layer
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              InkWell(
                onTap: onToggle,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: showBackground
                            ? Colors.white
                            : hasData
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: showBackground
                                ? Colors.white
                                : hasData
                                    ? theme.colorScheme.primary
                                    : null,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        trailing!,
                        const SizedBox(width: 4),
                      ],
                      if (hasData && badge != null) ...[
                        badge!,
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: showBackground ? Colors.white : null,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable Content
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: child,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
