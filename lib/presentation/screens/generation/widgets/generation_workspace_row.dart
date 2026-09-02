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
        final overlayWorkspaceWidth =
            (constraints.maxWidth - inlineLeadingWidth).clamp(
              0.0,
              constraints.maxWidth,
            );
        final expandedWidth = rightPanelExpanded
            ? WorkspaceSidePanelContract.overlayWidth(
                overlayWorkspaceWidth,
                preferredWidth: preferredRightPanelWidth,
              )
            : 0.0;
        final showsExpandedPanel =
            rightPanelExpanded && expandedWidth >= minimumExpandedPanelWidth;
        final rightPanelWidth = showsExpandedPanel ? expandedWidth : 40.0;
        const collapsedRightPanelWidth = 40.0;
        final overlaysLeading =
            overlayableLeading != null &&
            constraints.maxWidth -
                    inlineLeadingWidth -
                    collapsedRightPanelWidth <
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
            if (!showsExpandedPanel) rightPanelBuilder(rightPanelWidth, false),
          ],
        );

        // Expanded queue/agent content is a transient workspace overlay. It
        // must never resize the preview or make the central canvas jump.
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            workspaceRow,
            if (overlayableLeading != null)
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
            if (showsExpandedPanel)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: rightPanelWidth + ResizeHandle.defaultWidth,
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        width: ResizeHandle.defaultWidth,
                        child: rightHandle,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        left: ResizeHandle.defaultWidth,
                        child: rightPanelBuilder(rightPanelWidth, true),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
