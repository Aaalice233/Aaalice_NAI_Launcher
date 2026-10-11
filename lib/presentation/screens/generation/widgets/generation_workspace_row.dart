import 'package:flutter/material.dart';

import '../../../../core/windowing/agent_chat_dock_contract.dart';
import '../../../../core/windowing/workspace_side_panel_contract.dart';
import 'resize_handle.dart';

@immutable
class GenerationRightPanelAllocation {
  const GenerationRightPanelAllocation({
    required this.width,
    required this.expanded,
    required this.canExpand,
    this.sideBySide = false,
  });

  final double width;
  final bool expanded;

  /// Whether an expanded panel fits the current constraints, regardless of
  /// the user's collapsed state.
  final bool canExpand;

  /// Whether a requested side-by-side split fits; callers stack the panes
  /// vertically otherwise.
  final bool sideBySide;
}

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
    this.sideBySideChatWidth,
    required this.rightHandle,
    required this.rightPanelBuilder,
  });

  static const double minimumMainWorkspaceWidth = 320;
  static const double minimumExpandedPanelWidth = 200;
  static const double collapsedRightPanelWidth = 40;

  final List<Widget> leading;
  final double occupiedLeadingWidth;

  /// A leading panel that remains mounted and moves over the main workspace
  /// when keeping it inline would make the workspace unusably narrow.
  final Widget? overlayableLeading;
  final double overlayableLeadingWidth;

  final Widget main;
  final bool rightPanelExpanded;

  /// Single panel width, which is also the history column of a split.
  final double preferredRightPanelWidth;

  /// Chat column width requested beside history; null keeps a single column.
  final double? sideBySideChatWidth;
  final Widget rightHandle;
  final Widget Function(GenerationRightPanelAllocation allocation)
  rightPanelBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _resolve(constraints.maxWidth);
        final allocation = layout.allocation;

        final workspaceRow = Row(
          key: const ValueKey('generation-workspace-row'),
          children: [
            ...leading,
            if (overlayableLeading != null && !layout.overlaysLeading)
              SizedBox(width: overlayableLeadingWidth),
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('generation-main-workspace-slot'),
                child: main,
              ),
            ),
            if (allocation.expanded) rightHandle,
            rightPanelBuilder(allocation),
          ],
        );

        // The generation rail is a persistent workspace column. Unlike the
        // shell navigation overlay, it must participate in layout so image
        // content never remains interactable underneath it.
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
                  elevation: layout.overlaysLeading ? 8 : 0,
                  child: overlayableLeading!,
                ),
              ),
          ],
        );
      },
    );
  }

  _WorkspaceLayout _resolve(double workspaceWidth) {
    const handleWidth = ResizeHandle.defaultWidth;
    final hasOverlayable = overlayableLeading != null;
    final inlineLeadingWidth =
        occupiedLeadingWidth + (hasOverlayable ? overlayableLeadingWidth : 0);

    // A side-by-side split keeps the fixed tags sidebar inline; when two
    // minimum columns no longer fit, the single-panel rules take over.
    final chatWidth = sideBySideChatWidth;
    final sideBySideWidth = chatWidth == null
        ? null
        : AgentChatDockContract.sideBySideWidthFor(
            workspaceWidth: workspaceWidth,
            occupiedWidth: inlineLeadingWidth + handleWidth,
            minimumPrimaryWidth: minimumMainWorkspaceWidth,
            preferredWidth: AgentChatDockContract.sideBySidePreferredWidth(
              historyWidth: preferredRightPanelWidth,
              chatWidth: chatWidth,
            ),
          );

    final bool expandedOverlaysLeading;
    final double expandedWidth;
    if (sideBySideWidth != null) {
      expandedOverlaysLeading = false;
      expandedWidth = sideBySideWidth;
    } else {
      expandedOverlaysLeading =
          hasOverlayable &&
          _mainWidth(
                workspaceWidth,
                overlayableInline: true,
                rightWidth: minimumExpandedPanelWidth + handleWidth,
              ) <
              minimumMainWorkspaceWidth;
      expandedWidth = WorkspaceSidePanelContract.constrainedWorkspaceWidth(
        workspaceWidth: workspaceWidth,
        preferredWidth: preferredRightPanelWidth,
        occupiedWidth:
            occupiedLeadingWidth +
            (hasOverlayable && !expandedOverlaysLeading
                ? overlayableLeadingWidth
                : 0) +
            handleWidth,
        minimumPrimaryWidth: minimumMainWorkspaceWidth,
        minimumWidth: minimumExpandedPanelWidth,
      );
    }
    final canExpand = expandedWidth >= minimumExpandedPanelWidth;

    if (rightPanelExpanded && canExpand) {
      return _WorkspaceLayout(
        overlaysLeading: expandedOverlaysLeading,
        allocation: GenerationRightPanelAllocation(
          width: expandedWidth,
          expanded: true,
          canExpand: true,
          sideBySide: sideBySideWidth != null,
        ),
      );
    }
    return _WorkspaceLayout(
      overlaysLeading:
          hasOverlayable &&
          _mainWidth(
                workspaceWidth,
                overlayableInline: true,
                rightWidth: collapsedRightPanelWidth,
              ) <
              minimumMainWorkspaceWidth,
      allocation: GenerationRightPanelAllocation(
        width: collapsedRightPanelWidth,
        expanded: false,
        canExpand: canExpand,
        sideBySide: sideBySideWidth != null,
      ),
    );
  }

  double _mainWidth(
    double workspaceWidth, {
    required bool overlayableInline,
    required double rightWidth,
  }) =>
      workspaceWidth -
      occupiedLeadingWidth -
      (overlayableInline ? overlayableLeadingWidth : 0) -
      rightWidth;
}

class _WorkspaceLayout {
  const _WorkspaceLayout({
    required this.overlaysLeading,
    required this.allocation,
  });

  final bool overlaysLeading;
  final GenerationRightPanelAllocation allocation;
}
