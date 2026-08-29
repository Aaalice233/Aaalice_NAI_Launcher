import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../agent_chat/providers/agent_chat_notifier.dart';
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
  });

  final StatefulNavigationShell navigationShell;
  final Widget content;

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
        body: Row(
          children: [
            MainNavRail(
              navigationShell: widget.navigationShell,
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  widget.content,
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: GlobalStatusBanners(),
                  ),
                  ShellPanelsOverlay(
                    activePanel: activePanel,
                    desktop: true,
                    onClose: () => _setPanel(
                      null,
                      restoreFocus: activePanel == ShellPanel.agent
                          ? _agentFocusNode
                          : _queueFocusNode,
                    ),
                    onQueueStarted: () => widget.navigationShell.goBranch(
                      AppBranch.generation.index,
                    ),
                    onOpenAgentSettings: () => widget.navigationShell.goBranch(
                      AppBranch.settings.index,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
