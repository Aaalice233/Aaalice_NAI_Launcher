import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../themes/core/layered_surface_style.dart';
import 'themed_switch.dart';

/// Fixed comparison controls, kept outside the transformed image subtree.
class ImageComparisonToolbar extends StatelessWidget {
  const ImageComparisonToolbar({
    super.key,
    required this.followMouse,
    required this.onFollowMouseChanged,
    required this.showZoom,
    required this.scale,
    required this.actualPixelScale,
    required this.onScaleChanged,
    required this.canUseActualPixels,
  });

  final bool followMouse;
  final ValueChanged<bool> onFollowMouseChanged;
  final bool showZoom;
  final double scale;
  final double actualPixelScale;
  final ValueChanged<double> onScaleChanged;
  final bool canUseActualPixels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fit = (scale - 1).abs() < 0.001;
    final style = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.onSurfaceVariant,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: theme.textTheme.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    );
    final follow = Semantics(
      toggled: followMouse,
      label: context.l10n.comparison_followMouse,
      child: Tooltip(
        message: context.l10n.comparison_followMouseHint,
        child: InkWell(
          key: const ValueKey('comparison-follow-mouse'),
          borderRadius: BorderRadius.circular(7),
          onTap: () => onFollowMouseChanged(!followMouse),
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(context.l10n.comparison_followMouse)),
                const SizedBox(width: 4),
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Transform.scale(
                          scale: 0.65,
                          child: ThemedSwitch(
                            value: followMouse,
                            onChanged: onFollowMouseChanged,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final zoom = Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('comparison-zoom-out'),
              tooltip: context.l10n.editor_zoomOut,
              onPressed: () => onScaleChanged(scale / 1.25),
              iconSize: 16,
              icon: const Icon(Icons.remove),
            ),
            Flexible(
              child: Text(
                '${(scale / actualPixelScale * 100).round()}%',
                key: const ValueKey('comparison-zoom-value'),
                style: theme.textTheme.labelMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('comparison-zoom-in'),
              tooltip: context.l10n.editor_zoomIn,
              onPressed: () => onScaleChanged(scale * 1.25),
              iconSize: 16,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        TextButton(
          key: const ValueKey('comparison-actual-pixels'),
          onPressed: canUseActualPixels
              ? () => onScaleChanged(actualPixelScale)
              : null,
          child: const Text('100%'),
        ),
        TextButton(
          key: const ValueKey('comparison-fit-window'),
          style: fit
              ? style.copyWith(
                  backgroundColor: WidgetStatePropertyAll(
                    controlSurfaceColor(theme.colorScheme),
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    theme.colorScheme.onSurface,
                  ),
                )
              : null,
          onPressed: () => onScaleChanged(1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fit_screen_rounded, size: 16),
              const SizedBox(width: 6),
              Flexible(child: Text(context.l10n.editor_fitToWindow)),
            ],
          ),
        ),
      ],
    );
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: DefaultTextStyle(
          style: theme.textTheme.labelMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          child: TextButtonTheme(
            data: TextButtonThemeData(style: style),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth <
                    460 * MediaQuery.textScalerOf(context).scale(1);
                if (stacked && showZoom) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      zoom,
                      Align(alignment: Alignment.centerRight, child: follow),
                    ],
                  );
                }
                return Row(
                  children: [
                    if (showZoom) Expanded(child: zoom),
                    if (showZoom)
                      follow
                    else
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: follow,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
