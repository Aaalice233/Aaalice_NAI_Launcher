import 'package:flutter/material.dart';

import '../../../../core/windowing/workspace_side_panel_contract.dart';
import 'resize_handle.dart';

/// Arranges the desktop generation workspace while protecting its main pane.
class GenerationWorkspaceRow extends StatelessWidget {
  const GenerationWorkspaceRow({
    super.key,
    required this.leading,
    required this.occupiedLeadingWidth,
    this.overlayableLeading,
    this.overlayableLeadingWidth = 0,
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

  /// A leading panel that remains mounted and moves over the main workspace
  /// when keeping it inline would make the workspace unusably narrow.
  final Widget? overlayableLeading;
  final double overlayableLeadingWidth;

  final Widget main;
  final bool rightPanelExpanded;
  final double preferredRightPanelWidth;
  final Widget rightHandle;
  final Widget Function(double width, bool expanded) rightPanelBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineLeadingWidth =
            occupiedLeadingWidth +
            (overlayableLeading == null ? 0 : overlayableLeadingWidth);
        final expandedWidth = rightPanelExpanded
            ? WorkspaceSidePanelContract.constrainedWorkspaceWidth(
                workspaceWidth: constraints.maxWidth,
                preferredWidth: preferredRightPanelWidth,
                occupiedWidth: inlineLeadingWidth + ResizeHandle.defaultWidth,
                minimumPrimaryWidth: minimumMainWorkspaceWidth,
              )
            : 0.0;
        final showsExpandedPanel =
            rightPanelExpanded && expandedWidth >= minimumExpandedPanelWidth;
        final rightPanelWidth = showsExpandedPanel ? expandedWidth : 40.0;
        final rightOccupiedWidth =
            rightPanelWidth +
            (showsExpandedPanel ? ResizeHandle.defaultWidth : 0.0);
        final overlaysLeading =
            overlayableLeading != null &&
            constraints.maxWidth - inlineLeadingWidth - rightOccupiedWidth <
                minimumMainWorkspaceWidth;

        final workspaceRow = Row(
          key: const ValueKey('generation-workspace-row'),
          children: [
            ...leading,
            if (overlayableLeading != null && !overlaysLeading)
              SizedBox(width: overlayableLeadingWidth),
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
        if (overlayableLeading == null) return workspaceRow;

        // The panel is always hosted by this Stack, so crossing the responsive
        // threshold does not discard its search, scroll, or editing state.
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            workspaceRow,
            Positioned(
              top: 0,
              bottom: 0,
              left: occupiedLeadingWidth,
              width: overlayableLeadingWidth,
              child: Material(
                elevation: overlaysLeading ? 8 : 0,
                child: overlayableLeading!,
              ),
            ),
          ],
        );
      },
    );
  }
}
