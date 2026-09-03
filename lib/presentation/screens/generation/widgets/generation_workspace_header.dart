import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../themes/core/layered_surface_style.dart';

/// Compact page identity for the generation workspace's expanded control rail.
class GenerationWorkspaceHeader extends StatelessWidget {
  const GenerationWorkspaceHeader({super.key, required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ColoredBox(
      color: sectionSurfaceColor(colors),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.brush_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.nav_canvas,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('generation-workspace-collapse'),
                tooltip: context.l10n.common_collapse,
                onPressed: onCollapse,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
