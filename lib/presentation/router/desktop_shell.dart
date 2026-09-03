import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adaptive/window_size_class.dart';
import '../agent_chat/providers/agent_chat_notifier.dart';
import '../providers/layout_state_provider.dart';
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
        final storedRailExpansion = ref.watch(
          layoutStateNotifierProvider.select(
            (state) => state.mainNavRailExpanded,
          ),
        );
        final targetRailWidth = allowRailExpansion && storedRailExpansion
            ? MainNavRail.expandedWidthFor(context)
            : MainNavRail.collapsedWidth;
        final targetWorkspaceWidth = (safeUsableWidth - targetRailWidth)
            .clamp(0.0, double.infinity)
            .toDouble();
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
                  _StableWorkspaceViewport(
                    targetWidth: targetWorkspaceWidth,
                    child: Stack(
                      key: const ValueKey('desktop-workspace-stack'),
                      children: [
                        Column(
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
                        ),
                        Positioned.fill(
                          key: const ValueKey('desktop-panel-overlay-layer'),
                          child: ShellPanelsOverlay(
                            key: widget.panelOverlayKey,
                            activePanel: activePanel,
                            desktop: true,
                            onClose: () => _setPanel(
                              null,
                              restoreFocus: activePanel == ShellPanel.agent
                                  ? _agentFocusNode
                                  : _queueFocusNode,
                            ),
                            onQueueStarted: () => widget.navigationShell
                                .goBranch(AppBranch.generation.index),
                            onOpenAgentSettings: () => widget.navigationShell
                                .goBranch(AppBranch.settings.index),
                          ),
                        ),
                      ],
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

/// Keeps routed pages on their target constraint while the rail clips through
/// intermediate widths. This prevents page-level LayoutBuilders from running
/// once per animation frame without changing the rail's visible motion.
class _StableWorkspaceViewport extends StatelessWidget {
  const _StableWorkspaceViewport({
    required this.targetWidth,
    required this.child,
  });

  final double targetWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRect(
        key: const ValueKey('desktop-workspace-viewport'),
        child: OverflowBox(
          alignment: Alignment.centerRight,
          minWidth: targetWidth,
          maxWidth: targetWidth,
          child: SizedBox(
            width: targetWidth,
            height: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}
