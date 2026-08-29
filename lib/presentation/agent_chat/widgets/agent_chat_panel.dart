import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/providers/web_access_provider.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_composer.dart';
import 'agent_chat_header.dart';
import 'agent_chat_messages.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_coordinator.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_resource_drop_region.dart';
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
    _controller.inputController.addListener(_syncComposerDraft);
    _coordinator = AgentChatPanelCoordinator(
      ref: ref,
      controller: _controller,
      isMounted: () => mounted,
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _syncComposerDraft() {
    ref
        .read(agentChatNotifierProvider.notifier)
        .setComposerText(_controller.inputController.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.inputController.removeListener(_syncComposerDraft);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentChatNotifierProvider);
    final config = ref.watch(promptAssistantConfigProvider);
    final agentSettings = ref.watch(agentSettingsProvider);
    final webAccess = ref.watch(webAccessConfigProvider);
    _controller
      ..attachOverlayContext(context)
      ..observe(state)
      ..syncComposerText(state.composerText);
    final commands = _coordinator.commands(context, state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewData = AgentChatPanelViewData(
          state: state,
          config: config,
          agentSettings: agentSettings,
          webAccess: webAccess,
          mobile: widget.mobile,
          fullScreen: widget.fullScreen,
          compactMobile: widget.mobile && constraints.maxHeight < 480,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          onClose: widget.onClose,
          onOpenSettings: widget.onOpenSettings,
          mobileHeaderWrapper: widget.mobileHeaderWrapper,
        );
        return SafeArea(
          top: widget.mobile,
          bottom: widget.mobile,
          child: AgentResourceDropRegion(
            onDrop: commands.addPendingResource,
            child: Column(
              children: [
                AgentChatHeader(viewData: viewData, commands: commands),
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
            ),
          ),
        );
      },
    );
  }
}
