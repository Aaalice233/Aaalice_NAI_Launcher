import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/windowing/agent_chat_dock_contract.dart';
import '../../../../core/windowing/workspace_side_panel_contract.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../adaptive/window_size_class.dart';
import '../../../agent_chat/providers/agent_chat_dock_provider.dart';
import '../../../agent_chat/providers/agent_chat_surface_registry.dart';
import '../../../agent_chat/widgets/agent_chat_panel.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../router/shell_panels_overlay.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../../widgets/common/owned_scroll_controller.dart';
import '../../../widgets/common/resizable_split.dart';
import 'collapsed_panel.dart';
import 'generation_workspace_row.dart';
import 'history_panel.dart';

/// 右侧面板组件
///
/// 按智能体停靠设置呈现聊天与历史：独占切换、上下分栏或左右分栏；聊天改为
/// 浮窗时只保留历史。折叠态为竖排双入口，点击展开并显示对应面板。
class RightPanel extends ConsumerStatefulWidget {
  final bool isResizing;
  final GenerationRightPanelAllocation? allocation;
  final OwnedViewportOffset? historyViewport;

  const RightPanel({
    super.key,
    this.isResizing = false,
    this.allocation,
    this.historyViewport,
  });

  @override
  ConsumerState<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<RightPanel>
    implements AgentChatDockHost {
  late final OwnedViewportOffset _historyViewport;
  late final AgentChatSurfaceRegistry _surfaces;
  late final AgentChatDockNotifier _dock;
  late final ResizableSplitController _stackedSplit;
  late final ResizableSplitController _sideBySideSplit;
  // 分栏方向与收起状态切换时两块面板换父节点，GlobalKey 保住其状态；
  // 面板实例只建一次，拖动右栏宽度时不随外层重建而重建。
  late final Widget _historyPane = KeyedSubtree(
    key: GlobalKey(debugLabel: 'docked-history-pane'),
    child: HistoryPanel(
      embedded: false,
      viewportOffset: _historyViewport,
      onCollapse: () =>
          unawaited(_dock.collapsePane(AgentChatDockPane.history)),
    ),
  );
  late final Widget _chatPane = KeyedSubtree(
    key: GlobalKey(debugLabel: 'docked-agent-chat-pane'),
    child: AgentChatPanel(
      onClose: () => unawaited(_dock.collapsePane(AgentChatDockPane.chat)),
      onPopOut: () => unawaited(_dock.popOut()),
      focusRequest: _surfaces.dockedFocus,
    ),
  );
  bool _fitsExpanded = true;

  @override
  bool get fitsExpanded => _fitsExpanded;

  @override
  void initState() {
    super.initState();
    _historyViewport = widget.historyViewport ?? OwnedViewportOffset();
    _surfaces = ref.read(agentChatSurfaceRegistryProvider)
      ..attachDockHost(this);
    _dock = ref.read(agentChatDockProvider.notifier);
    final dock = ref.read(agentChatDockProvider);
    _stackedSplit = ResizableSplitController.fraction(dock.stackedChatFraction);
    _sideBySideSplit = ResizableSplitController.logicalPixels(
      dock.sideBySideChatWidth,
    );
  }

  @override
  void dispose() {
    _surfaces.detachDockHost(this);
    _stackedSplit.dispose();
    _sideBySideSplit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<double>(
      agentChatDockProvider.select((dock) => dock.stackedChatFraction),
      (_, fraction) => _stackedSplit.setValue(fraction),
    );
    ref.listen<double>(
      agentChatDockProvider.select((dock) => dock.sideBySideChatWidth),
      (_, width) => _sideBySideSplit.setValue(width),
    );
    final theme = Theme.of(context);
    final allocation = widget.allocation ?? _fallbackAllocation(context);
    _fitsExpanded = allocation.canExpand;
    final layout = ref.watch(
      agentChatDockProvider.select(
        (dock) => dock.dockLayout(sideBySideFits: allocation.sideBySide),
      ),
    );

    return Container(
      key: const ValueKey('generation-right-panel'),
      width: allocation.width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(left: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: allocation.expanded
          ? _buildExpanded(layout, allocation)
          : _buildCollapsed(layout, allocation),
    );
  }

  GenerationRightPanelAllocation _fallbackAllocation(BuildContext context) {
    final layoutState = ref.watch(layoutStateNotifierProvider);
    if (!layoutState.rightPanelExpanded) {
      return const GenerationRightPanelAllocation(
        width: GenerationWorkspaceRow.collapsedRightPanelWidth,
        expanded: false,
        canExpand: true,
      );
    }
    return GenerationRightPanelAllocation(
      width: WorkspaceSidePanelContract.constrainedWorkspaceWidth(
        workspaceWidth: AdaptiveWindowMetrics.of(context).usableSize.width,
        preferredWidth: layoutState.rightPanelWidth,
      ),
      expanded: true,
      canExpand: true,
    );
  }

  Widget _buildExpanded(
    AgentChatDockLayout layout,
    GenerationRightPanelAllocation allocation,
  ) {
    final visiblePane = layout.visiblePane;
    if (visiblePane == null) return _buildSplit(layout.axis, allocation);
    final pane = _buildPane(visiblePane);
    final foldedPane = layout.foldedPane;
    if (foldedPane == null) return pane;
    final strip = _buildRestoreStrip(foldedPane, layout.axis);
    return Flex(
      direction: layout.axis,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: foldedPane == AgentChatDockPane.history
          ? [strip, Expanded(child: pane)]
          : [Expanded(child: pane), strip],
    );
  }

  Widget _buildSplit(Axis axis, GenerationRightPanelAllocation allocation) {
    final horizontal = axis == Axis.horizontal;
    return ResizableSplit(
      key: const ValueKey('agent-dock-split'),
      dividerKey: const ValueKey('agent-dock-split-divider'),
      axis: axis,
      controller: horizontal ? _sideBySideSplit : _stackedSplit,
      leading: _buildPane(AgentChatDockPane.history),
      trailing: _buildPane(AgentChatDockPane.chat),
      minimumLeadingExtent: horizontal
          ? AgentChatDockContract.minimumHistoryPaneWidth
          : AgentChatDockContract.minimumHistoryPaneHeight,
      minimumTrailingExtent: horizontal
          ? AgentChatDockContract.minimumChatPaneWidth
          : AgentChatDockContract.minimumChatPaneHeight,
      resizeLabel: context.l10n.agentChat_resizeDockSplit,
      onResizeEnd: horizontal
          ? () => _persistSideBySide(allocation.width)
          : () => unawaited(_dock.setStackedChatFraction(_stackedSplit.value)),
    );
  }

  // 中间分隔线只在两列之间让宽度，历史列同步回写，右栏总宽保持不变。
  void _persistSideBySide(double totalWidth) {
    final chatWidth = _sideBySideSplit.value;
    final historyWidth =
        totalWidth - AgentChatDockContract.splitHandleExtent - chatWidth;
    unawaited(_dock.setSideBySideChatWidth(chatWidth));
    unawaited(
      ref
          .read(layoutStateNotifierProvider.notifier)
          .setRightPanelWidth(
            historyWidth
                .clamp(
                  AgentChatDockContract.minimumHistoryPaneWidth,
                  WorkspaceSidePanelContract.maximumWidth,
                )
                .toDouble(),
          ),
    );
  }

  Widget _buildPane(AgentChatDockPane pane) => switch (pane) {
    AgentChatDockPane.history => _historyPane,
    AgentChatDockPane.chat => _chatPane,
  };

  Widget _buildRestoreStrip(AgentChatDockPane pane, Axis axis) {
    final extent = math.max(
      context.interactionPolicy.minimumControlExtent,
      MediaQuery.textScalerOf(context).scale(12) * 1.4 + 16,
    );
    return ColoredBox(
      key: ValueKey('agent-dock-restore-${pane.name}'),
      color: sectionSurfaceColor(Theme.of(context).colorScheme),
      child: SizedBox(
        width: axis == Axis.horizontal ? extent : null,
        height: axis == Axis.vertical ? extent : null,
        child: CollapsedPanel(
          icon: _paneIcon(pane),
          label: _paneLabel(pane),
          axis: axis == Axis.vertical ? Axis.horizontal : Axis.vertical,
          onTap: () => unawaited(_dock.revealDockedPane(pane)),
        ),
      ),
    );
  }

  Widget _buildCollapsed(
    AgentChatDockLayout layout,
    GenerationRightPanelAllocation allocation,
  ) {
    bool presents(AgentChatDockPane pane) =>
        layout.isSplit || layout.visiblePane == pane;
    return Column(
      children: [
        for (final pane in AgentChatDockPane.values) ...[
          if (pane != AgentChatDockPane.values.first) const Divider(height: 1),
          Expanded(
            child: CollapsedPanel(
              key: ValueKey('agent-dock-rail-${pane.name}'),
              icon: _paneIcon(pane),
              label: _paneLabel(pane),
              active: presents(pane),
              onTap: () => _openFromRail(pane, allocation),
            ),
          ),
        ],
      ],
    );
  }

  // 放不下右栏时聊天入口改开侧边浮层，避免点击后毫无反应。
  void _openFromRail(
    AgentChatDockPane pane,
    GenerationRightPanelAllocation allocation,
  ) {
    if (pane == AgentChatDockPane.chat) {
      if (ref.read(agentChatDockProvider).floatingEnabled) {
        unawaited(_dock.setFloatingVisible(true));
        return;
      }
      if (!allocation.canExpand) {
        ref.read(shellPanelProvider.notifier).state = ShellPanel.agent;
        return;
      }
    }
    unawaited(_dock.revealDockedPane(pane));
  }

  IconData _paneIcon(AgentChatDockPane pane) => switch (pane) {
    AgentChatDockPane.chat => Icons.smart_toy_outlined,
    AgentChatDockPane.history => Icons.history,
  };

  String _paneLabel(AgentChatDockPane pane) => switch (pane) {
    AgentChatDockPane.chat => context.l10n.agentChat_tab,
    AgentChatDockPane.history => context.l10n.generation_history,
  };
}
