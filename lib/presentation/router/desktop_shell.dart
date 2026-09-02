import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/windowing/workspace_side_panel_contract.dart';
import '../adaptive/window_size_class.dart';
import '../agent_chat/providers/agent_chat_notifier.dart';
import '../themes/theme_extension.dart';
import '../widgets/navigation/main_nav_rail.dart';
import 'app_branch.dart';
import 'global_status_banners.dart';
import 'shell_panels_overlay.dart';

/// 桌面端布局
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({
    super.key,
    required this.navigationShell,
    required this.content,
    this.panelOverlayKey,
  });

  final StatefulNavigationShell navigationShell;
  final Widget content;
  final Key? panelOverlayKey;

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  final _agentFocusNode = FocusNode(debugLabel: 'agent-nav-item');
  final _queueFocusNode = FocusNode(debugLabel: 'queue-nav-item');

  @override
  void dispose() {
    _agentFocusNode.dispose();
    _queueFocusNode.dispose();
    super.dispose();
  }

  void _setPanel(ShellPanel? panel, {FocusNode? restoreFocus}) {
    ref.read(shellPanelProvider.notifier).state = panel;
    if (panel == null && restoreFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) restoreFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePanel = ref.watch(shellPanelProvider);
    final agentRunning = ref.watch(
      agentChatNotifierProvider.select(
        (state) => state.status == AgentChatRunStatus.running,
      ),
    );
    final isAgentVisible = activePanel == ShellPanel.agent;
    final isQueueVisible = activePanel == ShellPanel.queue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final safeUsableWidth =
            (constraints.maxWidth - MediaQuery.paddingOf(context).horizontal)
                .clamp(0.0, double.infinity)
                .toDouble();
        final allowRailExpansion = WindowSizeClass.fromWidth(
          safeUsableWidth,
        ).isExpandedOrWider;
        return CallbackShortcuts(
          bindings: {
            if (activePanel != null)
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (activePanel == ShellPanel.agent) {
                  _setPanel(null, restoreFocus: _agentFocusNode);
                } else {
                  _setPanel(null, restoreFocus: _queueFocusNode);
                }
              },
          },
          child: Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  MainNavRail(
                    navigationShell: widget.navigationShell,
                    allowExpansion: allowRailExpansion,
                    isAgentVisible: isAgentVisible,
                    isAgentRunning: agentRunning,
                    isQueueVisible: isQueueVisible,
                    agentFocusNode: _agentFocusNode,
                    queueFocusNode: _queueFocusNode,
                    onAgentVisibilityChanged: (isVisible) => _setPanel(
                      isVisible ? ShellPanel.agent : null,
                      restoreFocus: isVisible ? null : _agentFocusNode,
                    ),
                    onQueueVisibilityChanged: (isVisible) => _setPanel(
                      isVisible ? ShellPanel.queue : null,
                      restoreFocus: isVisible ? null : _queueFocusNode,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, workspaceConstraints) {
                        final usesParallelPanel = allowRailExpansion;
                        final reduceMotion = MediaQuery.disableAnimationsOf(
                          context,
                        );
                        final panelWidth =
                            WorkspaceSidePanelContract.constrainedWorkspaceWidth(
                              workspaceWidth: workspaceConstraints.maxWidth,
                              preferredWidth: activePanel == ShellPanel.queue
                                  ? 460
                                  : 520,
                              minimumPrimaryWidth:
                                  (workspaceConstraints.maxWidth * 0.52)
                                      .clamp(320.0, 560.0)
                                      .toDouble(),
                            );
                        final primaryWorkspace = Column(
                          key: const ValueKey('desktop-primary-workspace'),
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: (constraints.maxHeight * 0.45).clamp(
                                  0.0,
                                  360.0,
                                ),
                              ),
                              child: const SingleChildScrollView(
                                child: GlobalStatusBanners(),
                              ),
                            ),
                            Expanded(child: widget.content),
                          ],
                        );
                        final panels = ShellPanelsOverlay(
                          key: widget.panelOverlayKey,
                          activePanel: activePanel,
                          desktop: usesParallelPanel,
                          onClose: () => _setPanel(
                            null,
                            restoreFocus: activePanel == ShellPanel.agent
                                ? _agentFocusNode
                                : _queueFocusNode,
                          ),
                          onQueueStarted: () => widget.navigationShell.goBranch(
                            AppBranch.generation.index,
                          ),
                          onOpenAgentSettings: () => widget.navigationShell
                              .goBranch(AppBranch.settings.index),
                        );

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Row(
                              children: [
                                Expanded(child: primaryWorkspace),
                                if (usesParallelPanel)
                                  AnimatedContainer(
                                    key: const ValueKey(
                                      'desktop-parallel-panel-slot',
                                    ),
                                    duration: reduceMotion
                                        ? Duration.zero
                                        : Theme.of(
                                            context,
                                          ).appTheme.normalDuration,
                                    curve: Theme.of(
                                      context,
                                    ).appTheme.standardCurve,
                                    width: activePanel == null ? 0 : panelWidth,
                                    clipBehavior: Clip.hardEdge,
                                    decoration: const BoxDecoration(),
                                    child: OverflowBox(
                                      alignment: Alignment.centerRight,
                                      minWidth: panelWidth,
                                      maxWidth: panelWidth,
                                      child: panels,
                                    ),
                                  ),
                              ],
                            ),
                            if (!usesParallelPanel) panels,
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
