import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/windowing/workspace_side_panel_contract.dart';
import '../agent_chat/widgets/agent_chat_panel.dart';
import '../themes/theme_extension.dart';
import '../widgets/queue/queue_management_page.dart';

/// Shell 级持久面板。单一状态所有者保证智能体与队列不会重叠。
enum ShellPanel { agent, queue }

final shellPanelProvider = StateProvider<ShellPanel?>((ref) => null);

/// Shell 级持久面板槽位。切换面板时只替换内容，不叠加两个抽屉。
class ShellPanelsOverlay extends StatefulWidget {
  const ShellPanelsOverlay({
    super.key,
    required this.activePanel,
    required this.desktop,
    required this.onClose,
    required this.onQueueStarted,
    required this.onOpenAgentSettings,
  });

  final ShellPanel? activePanel;
  final bool desktop;
  final VoidCallback onClose;
  final VoidCallback onQueueStarted;
  final VoidCallback onOpenAgentSettings;

  @override
  State<ShellPanelsOverlay> createState() => _ShellPanelsOverlayState();
}

class _ShellPanelsOverlayState extends State<ShellPanelsOverlay> {
  final _panelFocusScopeNode = FocusScopeNode(
    debugLabel: 'shell-panel-focus-scope',
  );
  late ShellPanel _displayedPanel = widget.activePanel ?? ShellPanel.queue;
  late bool _hasOpenedAgent = widget.activePanel == ShellPanel.agent;

  @override
  void dispose() {
    _panelFocusScopeNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShellPanelsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activePanel = widget.activePanel;
    if (oldWidget.activePanel != activePanel && oldWidget.activePanel != null) {
      // 隐藏的输入框不能继续持有焦点，否则手机键盘会挡住主界面。
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (activePanel != null) {
      _displayedPanel = activePanel;
      if (activePanel == ShellPanel.agent) _hasOpenedAgent = true;
      if (oldWidget.activePanel != activePanel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.activePanel != null) {
            _panelFocusScopeNode.requestFocus();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isVisible = widget.activePanel != null;
    final showingAgent = _displayedPanel == ShellPanel.agent;
    final hiddenOffset = widget.desktop
        ? const Offset(1, 0)
        : const Offset(0, 1);
    final duration = reduceMotion
        ? Duration.zero
        : theme.appTheme.normalDuration;
    final motionCurve = theme.appTheme.standardCurve;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            if (isVisible && !widget.desktop)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('shell-panel-scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: ColoredBox(
                    color: theme.colorScheme.scrim.withValues(alpha: 0.36),
                  ),
                ),
              ),
            TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: hiddenOffset,
                end: isVisible ? Offset.zero : hiddenOffset,
              ),
              duration: duration,
              curve: motionCurve,
              builder: (context, offset, panel) {
                final hidden = widget.desktop
                    ? offset.dx >= 0.5
                    : offset.dy >= 0.5;
                return ExcludeSemantics(
                  excluding: hidden,
                  child: IgnorePointer(
                    ignoring: hidden,
                    child: FractionalTranslation(
                      translation: offset,
                      child: panel,
                    ),
                  ),
                );
              },
              child: Align(
                alignment: widget.desktop
                    ? Alignment.centerRight
                    : Alignment.bottomCenter,
                child: AnimatedContainer(
                  key: const ValueKey('shell-panel-surface'),
                  duration: duration,
                  curve: motionCurve,
                  width: widget.desktop
                      ? showingAgent
                            ? WorkspaceSidePanelContract.overlayWidth(
                                constraints.maxWidth,
                              )
                            : 460.0.clamp(0, constraints.maxWidth).toDouble()
                      : constraints.maxWidth,
                  height: widget.desktop
                      ? constraints.maxHeight
                      : constraints.maxHeight * (showingAgent ? 0.94 : 0.85),
                  child: Material(
                    color: showingAgent
                        ? theme.colorScheme.surfaceContainerHigh
                        : theme.scaffoldBackgroundColor,
                    elevation: 18,
                    shadowColor: theme.shadowColor.withValues(alpha: 0.28),
                    borderRadius: widget.desktop
                        ? const BorderRadius.horizontal(
                            left: Radius.circular(18),
                          )
                        : const BorderRadius.vertical(top: Radius.circular(22)),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      child: FocusScope(
                        node: _panelFocusScopeNode,
                        canRequestFocus: isVisible,
                        descendantsAreFocusable: isVisible,
                        child: FocusTraversalGroup(
                          child: IndexedStack(
                            index: showingAgent ? 1 : 0,
                            children: [
                              KeyedSubtree(
                                key: const ValueKey('queue-shell-panel'),
                                child: QueueManagementPage(
                                  onClose: widget.onClose,
                                  onQueueStarted: widget.onQueueStarted,
                                ),
                              ),
                              KeyedSubtree(
                                key: const ValueKey('agent-shell-panel'),
                                child: _hasOpenedAgent
                                    ? AgentChatPanel(
                                        key: const ValueKey(
                                          'agent-drawer-chat-panel',
                                        ),
                                        fullScreen: !widget.desktop,
                                        onClose: widget.onClose,
                                        onOpenSettings:
                                            widget.onOpenAgentSettings,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
