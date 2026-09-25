import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/providers/web_access_provider.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../providers/generation/image_generation_selectors.dart';
import '../../providers/image_generation_provider.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../providers/agent_chat_notifier.dart';
import '../providers/agent_chat_surface_registry.dart';
import 'agent_chat_composer.dart';
import 'agent_chat_header.dart';
import 'agent_chat_messages.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_coordinator.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_chat_reading_preferences.dart';
import 'agent_resource_drop_region.dart';
import 'agent_chat_status.dart';
import 'agent_chat_question_card.dart';

final _agentChatViewportStoreProvider = Provider<AgentChatViewportStore>(
  (ref) => AgentChatViewportStore(),
);

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
    this.fullScreen = false,
    this.headerWrapper,
    this.onPopOut,
    this.onDock,
    this.focusRequest,
    this.backgroundColor,
  });

  final VoidCallback? onClose;
  final VoidCallback? onOpenSettings;
  final bool fullScreen;
  final Widget Function(Widget child)? headerWrapper;
  final VoidCallback? onPopOut;
  final VoidCallback? onDock;

  /// Moves keyboard focus to the composer when the host asks for it, even if
  /// the request was issued before this panel mounted.
  final AgentChatFocusRequest? focusRequest;

  /// Canvas behind the stacked layout; defaults to the page surface.
  final Color? backgroundColor;

  @override
  ConsumerState<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends ConsumerState<AgentChatPanel> {
  late final AgentChatPanelController _controller;
  late final AgentChatPanelCoordinator _coordinator;
  late final AgentChatPanelCommands _commands = _coordinator.commands(context);

  @override
  void initState() {
    super.initState();
    _controller = AgentChatPanelController(
      viewportStore: ref.read(_agentChatViewportStoreProvider),
      initialSessionId: ref.read(agentChatNotifierProvider).activeSessionId,
    )..addListener(_refresh);
    _controller.inputController.addListener(_syncComposerDraft);
    _coordinator = AgentChatPanelCoordinator(
      ref: ref,
      controller: _controller,
      isMounted: () => mounted,
    );
    widget.focusRequest?.addListener(_scheduleRequestedFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(agentChatNotifierProvider.notifier).ensureInitialized(),
      );
      _applyRequestedFocus();
    });
  }

  @override
  void didUpdateWidget(AgentChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequest != widget.focusRequest) {
      oldWidget.focusRequest?.removeListener(_scheduleRequestedFocus);
      widget.focusRequest?.addListener(_scheduleRequestedFocus);
      _scheduleRequestedFocus();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _syncComposerDraft() {
    ref
        .read(agentChatNotifierProvider.notifier)
        .setComposerText(_controller.inputController.text);
  }

  // Hosts request focus in the frame that reveals them; waiting for layout
  // lets focus land on a composer that is already visible.
  void _scheduleRequestedFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRequestedFocus());
  }

  void _applyRequestedFocus() {
    if (!mounted || widget.focusRequest?.consume() != true) return;
    _controller.inputFocus.requestFocus();
  }

  @override
  void dispose() {
    widget.focusRequest?.removeListener(_scheduleRequestedFocus);
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
    final currentCanvasId = ref.watch(
      imageGenerationNotifierProvider.select(selectCurrentCanvasImageId),
    );
    final currentCanvasReference = currentCanvasId == null
        ? null
        : AgentChatResourceReference(
            kind: AgentChatResourceKind.generatedImage,
            source: 'generation_history',
            resourceId: currentCanvasId,
          );
    _controller
      ..attachOverlayContext(context)
      ..observe(state)
      ..syncComposerText(state.composerText);
    _coordinator.currentCanvasReference = currentCanvasReference;
    final commands = _commands;

    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
        final viewData = AgentChatPanelViewData(
          state: state,
          config: config,
          agentSettings: agentSettings,
          webAccess: webAccess,
          fullScreen: widget.fullScreen,
          compactHeight: constraints.maxHeight <= 520 || keyboardVisible,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          onClose: widget.onClose,
          onOpenSettings: widget.onOpenSettings,
          headerWrapper: widget.headerWrapper,
          onPopOut: widget.onPopOut,
          onDock: widget.onDock,
          currentCanvasReference: currentCanvasReference,
        );
        final useStackedLayout =
            widget.fullScreen ||
            constraints.maxWidth < 600 ||
            viewData.compactHeight;
        final panel = AgentResourceDropRegion(
          onDrop: commands.addPendingResource,
          child: useStackedLayout
              ? _MobileAgentChatLayout(
                  viewData: viewData,
                  commands: commands,
                  controller: _controller,
                  backgroundColor:
                      widget.backgroundColor ??
                      Theme.of(context).colorScheme.surface,
                )
              : _EmbeddedAgentChatLayout(
                  viewData: viewData,
                  commands: commands,
                  controller: _controller,
                ),
        );
        return AgentChatReadingPreferences(
          config: agentSettings.settings.chat,
          desktop: switch (Theme.of(context).platform) {
            TargetPlatform.windows ||
            TargetPlatform.macOS ||
            TargetPlatform.linux => true,
            _ => false,
          },
          child: SafeArea(child: panel),
        );
      },
    );
  }
}

class _EmbeddedAgentChatLayout extends StatelessWidget {
  const _EmbeddedAgentChatLayout({
    required this.viewData,
    required this.commands,
    required this.controller,
  });

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;
  final AgentChatPanelController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AgentChatHeader(viewData: viewData, commands: commands),
      Expanded(
        child: AgentChatMessages(
          viewData: viewData,
          commands: commands,
          controller: controller,
        ),
      ),
      AgentChatStatus(viewData: viewData, commands: commands),
      if (viewData.state.questionRequest case final request?)
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AgentChatQuestionCard(request: request),
          ),
        )
      else if (viewData.state.routeReady)
        AgentChatComposer(
          viewData: viewData,
          commands: commands,
          controller: controller,
        ),
    ],
  );
}

class _MobileAgentChatLayout extends StatelessWidget {
  const _MobileAgentChatLayout({
    required this.viewData,
    required this.commands,
    required this.controller,
    required this.backgroundColor,
  });

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;
  final AgentChatPanelController controller;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('agent-chat-mobile-viewport'),
      color: backgroundColor,
      child: Column(
        children: [
          AgentChatHeader(viewData: viewData, commands: commands),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep decisions adjacent to the composer without allowing a
                // long approval or error to displace input on an IME viewport.
                final statusFraction = viewData.compactHeight ? 0.24 : 0.38;
                final statusMaxHeight = (constraints.maxHeight * statusFraction)
                    .clamp(0.0, 280.0);
                return Column(
                  children: [
                    Expanded(
                      child: AgentChatMessages(
                        viewData: viewData,
                        commands: commands,
                        controller: controller,
                      ),
                    ),
                    _AgentChatStatusViewport(
                      key: const ValueKey('agent-chat-mobile-status-viewport'),
                      maxHeight: statusMaxHeight,
                      viewData: viewData,
                      commands: commands,
                    ),
                    if (viewData.state.questionRequest case final request?)
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AgentChatQuestionCard(request: request),
                        ),
                      )
                    else if (viewData.state.routeReady)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.82,
                        ),
                        child: _composer(),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    // Keep the EditableText under the same element hierarchy when the IME
    // changes the available height. Swapping this wrapper only for the compact
    // layout detached the externally-owned FocusNode and dismissed Android's
    // keyboard immediately after it opened.
    return AgentChatComposer(
      viewData: viewData,
      commands: commands,
      controller: controller,
    );
  }
}

class _AgentChatStatusViewport extends StatelessWidget {
  const _AgentChatStatusViewport({
    super.key,
    required this.maxHeight,
    required this.viewData,
    required this.commands,
  });

  final double maxHeight;
  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(
      primary: false,
      child: AgentChatStatus(viewData: viewData, commands: commands),
    ),
  );
}
