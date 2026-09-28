import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/workspace_panel_header.dart';

/// Compact page identity for the generation workspace's expanded control rail.
class GenerationWorkspaceHeader extends StatelessWidget {
  const GenerationWorkspaceHeader({super.key, required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspacePanelHeader(
      icon: Icons.brush_outlined,
      title: Text(
        context.l10n.nav_canvas,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: IconButton(
        key: const ValueKey('generation-workspace-collapse'),
        tooltip: context.l10n.common_collapse,
        onPressed: onCollapse,
        icon: const Icon(Icons.chevron_left),
      ),
    );
  }
}
