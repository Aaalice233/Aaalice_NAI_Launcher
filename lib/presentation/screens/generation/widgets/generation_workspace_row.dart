import 'package:flutter/material.dart';

import '../../../../core/windowing/workspace_side_panel_contract.dart';
import 'resize_handle.dart';

/// Arranges the desktop generation workspace while protecting its main pane.
class GenerationWorkspaceRow extends StatelessWidget {
  const GenerationWorkspaceRow({
    super.key,
    required this.leading,
    required this.occupiedLeadingWidth,
    required this.main,
    required this.rightPanelExpanded,
    required this.preferredRightPanelWidth,
    required this.rightHandle,
    required this.rightPanelBuilder,
  });

  static const double minimumMainWorkspaceWidth = 320;
  static const double minimumExpandedPanelWidth = 200;

  final List<Widget> leading;
  final double occupiedLeadingWidth;
  final Widget main;
  final bool rightPanelExpanded;
  final double preferredRightPanelWidth;
  final Widget rightHandle;
  final Widget Function(double width, bool expanded) rightPanelBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedWidth = rightPanelExpanded
            ? WorkspaceSidePanelContract.constrainedWorkspaceWidth(
                workspaceWidth: constraints.maxWidth,
                preferredWidth: preferredRightPanelWidth,
                occupiedWidth: occupiedLeadingWidth + ResizeHandle.defaultWidth,
                minimumPrimaryWidth: minimumMainWorkspaceWidth,
              )
            : 0.0;
        final showsExpandedPanel =
            rightPanelExpanded && expandedWidth >= minimumExpandedPanelWidth;
        final rightPanelWidth = showsExpandedPanel ? expandedWidth : 40.0;
        return Row(
          key: const ValueKey('generation-workspace-row'),
          children: [
            ...leading,
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('generation-main-workspace-slot'),
                child: main,
              ),
            ),
            if (showsExpandedPanel) rightHandle,
            rightPanelBuilder(rightPanelWidth, showsExpandedPanel),
          ],
        );
      },
    );
  }
}
