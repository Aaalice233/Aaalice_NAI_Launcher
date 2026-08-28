import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_composer.dart';
import 'agent_chat_header.dart';
import 'agent_chat_messages.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_coordinator.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_chat_status.dart';

/// Stable shell for the AI chat workspace.
///
/// Ephemeral editing, focus, scrolling, image and preview resources live in
/// [AgentChatPanelController]. Provider-facing operations live in
/// [AgentChatPanelCoordinator], while child widgets receive immutable data and
/// typed commands only.
class AgentChatPanel extends ConsumerStatefulWidget {
  const AgentChatPanel({
    super.key,
    this.onClose,
    this.onOpenSettings,
    this.mobile = false,
    this.fullScreen = false,
    this.mobileHeaderWrapper,
  });

  final VoidCallback? onClose;
  final VoidCallback? onOpenSettings;
  final bool mobile;
  final bool fullScreen;
  final Widget Function(Widget child)? mobileHeaderWrapper;

  @override
  ConsumerState<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends ConsumerState<AgentChatPanel> {
  late final AgentChatPanelController _controller;
  late final AgentChatPanelCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _controller = AgentChatPanelController()..addListener(_refresh);
    _coordinator = AgentChatPanelCoordinator(
      ref: ref,
      controller: _controller,
      isMounted: () => mounted,
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentChatNotifierProvider);
    final config = ref.watch(promptAssistantConfigProvider);
    _controller
      ..attachOverlayContext(context)
      ..observe(state);
    final commands = _coordinator.commands(context, state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewData = AgentChatPanelViewData(
          state: state,
          config: config,
          mobile: widget.mobile,
          fullScreen: widget.fullScreen,
          compactMobile: widget.mobile && constraints.maxHeight < 480,
          onClose: widget.onClose,
          onOpenSettings: widget.onOpenSettings,
          mobileHeaderWrapper: widget.mobileHeaderWrapper,
        );
        return Column(
          children: [
            AgentChatHeader(viewData: viewData, commands: commands),
            const Divider(height: 1),
            Expanded(
              child: AgentChatMessages(
                viewData: viewData,
                commands: commands,
                controller: _controller,
              ),
            ),
            AgentChatStatus(viewData: viewData, commands: commands),
            if (state.routeReady)
              AgentChatComposer(
                viewData: viewData,
                commands: commands,
                controller: _controller,
              ),
          ],
        );
      },
    );
  }
}
