import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/windowing/workspace_side_panel_contract.dart';
import '../agent_chat/widgets/agent_chat_panel.dart';
import '../providers/queue_execution_provider.dart';
import '../themes/theme_extension.dart';
import '../widgets/common/ticker_mode_indexed_stack.dart';
import '../widgets/queue/queue_management_page.dart';

/// Shell 级持久面板。单一状态所有者保证智能体与队列不会重叠。
enum ShellPanel { agent, queue }

final shellPanelProvider = NotifierProvider<ShellPanelNotifier, ShellPanel?>(
  ShellPanelNotifier.new,
);

class ShellPanelNotifier extends Notifier<ShellPanel?> {
  @override
  ShellPanel? build() => null;

  void setPanel(ShellPanel? panel) {
    state = panel;
  }

  void open(ShellPanel panel) {
    state = panel;
  }

  void close() {
    state = null;
  }

  void toggle(ShellPanel panel) {
    state = state == panel ? null : panel;
  }
}

/// Shell 级持久面板槽位。切换面板时只替换内容，不叠加两个抽屉。
class ShellPanelsOverlay extends ConsumerStatefulWidget {
  const ShellPanelsOverlay({
    super.key,
    required this.activePanel,
    required this.desktop,
    required this.onClose,
    required this.onQueueStarted,
    required this.onOpenAgentSettings,
    this.onPopOutAgent,
  });

  final ShellPanel? activePanel;
  final bool desktop;
  final VoidCallback onClose;
  final VoidCallback onQueueStarted;
  final VoidCallback onOpenAgentSettings;

  final VoidCallback? onPopOutAgent;

  @override
  ConsumerState<ShellPanelsOverlay> createState() => _ShellPanelsOverlayState();
}

class _ShellPanelsOverlayState extends ConsumerState<ShellPanelsOverlay> {
  final _panelFocusScopeNode = FocusScopeNode(
    debugLabel: 'shell-panel-focus-scope',
  );
  late ShellPanel _displayedPanel = widget.activePanel ?? ShellPanel.queue;
  late bool _hasOpenedAgent = widget.activePanel == ShellPanel.agent;
  late bool _hasOpenedQueue = widget.activePanel == ShellPanel.queue;
  late bool _isOffstage = widget.activePanel == null;

  @override
  void initState() {
    super.initState();
    ref.read(queueExecutionNotifierProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && widget.activePanel == null) {
      _isOffstage = true;
    }
  }

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
      _isOffstage = false;
      _displayedPanel = activePanel;
      if (activePanel == ShellPanel.agent) _hasOpenedAgent = true;
      if (activePanel == ShellPanel.queue) _hasOpenedQueue = true;
      if (oldWidget.activePanel != activePanel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.activePanel != null) {
            _panelFocusScopeNode.requestFocus();
          }
        });
      }
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _isOffstage = true;
    }
  }

  void _onVisibilityAnimationEnd() {
    if (widget.activePanel == null) {
      setState(() => _isOffstage = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisible = widget.activePanel != null;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
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
          _ShellPanelVisibility(
            isVisible: isVisible,
            isOffstage: _isOffstage,
            onEnd: _onVisibilityAnimationEnd,
            child: _ShellPanelBody(
              constraints: constraints,
              desktop: widget.desktop,
              showingAgent: _displayedPanel == ShellPanel.agent,
              isVisible: isVisible,
              hasOpenedQueue: _hasOpenedQueue,
              hasOpenedAgent: _hasOpenedAgent,
              focusScopeNode: _panelFocusScopeNode,
              onClose: widget.onClose,
              onQueueStarted: widget.onQueueStarted,
              onOpenAgentSettings: widget.onOpenAgentSettings,
              onPopOutAgent: widget.onPopOutAgent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellPanelVisibility extends StatelessWidget {
  const _ShellPanelVisibility({
    required this.isVisible,
    required this.isOffstage,
    required this.onEnd,
    required this.child,
  });

  final bool isVisible;
  final bool isOffstage;
  final VoidCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final panel = Offstage(
      offstage: isOffstage,
      child: TickerMode(enabled: !isOffstage, child: child),
    );
    return AnimatedOpacity(
      key: const ValueKey('shell-panel-visibility-transition'),
      opacity: isVisible ? 1 : 0,
      duration: reduceMotion ? Duration.zero : theme.appTheme.fastDuration,
      curve: theme.appTheme.standardCurve,
      // 零时长会同步触发 onEnd，减少动态效果时直接进入 Offstage。
      onEnd: reduceMotion ? null : onEnd,
      child: ExcludeSemantics(
        excluding: !isVisible,
        child: IgnorePointer(ignoring: !isVisible, child: panel),
      ),
    );
  }
}

class _ShellPanelBody extends StatelessWidget {
  const _ShellPanelBody({
    required this.constraints,
    required this.desktop,
    required this.showingAgent,
    required this.isVisible,
    required this.hasOpenedQueue,
    required this.hasOpenedAgent,
    required this.focusScopeNode,
    required this.onClose,
    required this.onQueueStarted,
    required this.onOpenAgentSettings,
    required this.onPopOutAgent,
  });

  final BoxConstraints constraints;
  final bool desktop;
  final bool showingAgent;
  final bool isVisible;
  final bool hasOpenedQueue;
  final bool hasOpenedAgent;
  final FocusScopeNode focusScopeNode;
  final VoidCallback onClose;
  final VoidCallback onQueueStarted;
  final VoidCallback onOpenAgentSettings;
  final VoidCallback? onPopOutAgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = FocusScope(
      node: focusScopeNode,
      canRequestFocus: isVisible,
      descendantsAreFocusable: isVisible,
      child: FocusTraversalGroup(child: _buildPanels()),
    );
    return Align(
      alignment: desktop ? Alignment.centerRight : Alignment.bottomCenter,
      child: SizedBox(
        key: const ValueKey('shell-panel-surface'),
        width: desktop
            ? showingAgent
                  ? WorkspaceSidePanelContract.overlayWidth(
                      constraints.maxWidth,
                    )
                  : 460.0.clamp(0, constraints.maxWidth).toDouble()
            : constraints.maxWidth,
        height: desktop
            ? constraints.maxHeight
            : constraints.maxHeight * (showingAgent ? 0.94 : 0.85),
        child: Material(
          color: showingAgent
              ? theme.colorScheme.surfaceContainerHigh
              : theme.scaffoldBackgroundColor,
          elevation: 18,
          shadowColor: theme.shadowColor.withValues(alpha: 0.28),
          borderRadius: desktop
              ? const BorderRadius.horizontal(left: Radius.circular(18))
              : const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(top: false, child: content),
        ),
      ),
    );
  }

  Widget _buildPanels() {
    return TickerModeIndexedStack(
      index: showingAgent ? 1 : 0,
      children: [
        KeyedSubtree(
          key: const ValueKey('queue-shell-panel'),
          child: hasOpenedQueue
              ? QueueManagementPage(
                  onClose: onClose,
                  onQueueStarted: onQueueStarted,
                )
              : const SizedBox.shrink(),
        ),
        KeyedSubtree(
          key: const ValueKey('agent-shell-panel'),
          child: hasOpenedAgent
              ? AgentChatPanel(
                  key: const ValueKey('agent-drawer-chat-panel'),
                  fullScreen: !desktop,
                  onClose: onClose,
                  onOpenSettings: onOpenAgentSettings,
                  onPopOut: desktop ? onPopOutAgent : null,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
