import 'package:flutter/material.dart';

import '../../../../core/agent/agent_types.dart';
import '../../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/web_access_provider.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../providers/agent_chat_notifier.dart';

@immutable
class AgentChatPanelViewData {
  const AgentChatPanelViewData({
    required this.state,
    required this.config,
    required this.agentSettings,
    required this.webAccess,
    required this.mobile,
    required this.fullScreen,
    required this.compactMobile,
    required this.onClose,
    required this.onOpenSettings,
    required this.mobileHeaderWrapper,
  });

  final AgentChatState state;
  final PromptAssistantConfigState config;
  final AgentSettingsState agentSettings;
  final WebAccessConfigState webAccess;
  final bool mobile;
  final bool fullScreen;
  final bool compactMobile;
  final VoidCallback? onClose;
  final VoidCallback? onOpenSettings;
  final Widget Function(Widget child)? mobileHeaderWrapper;

  bool get running => state.status == AgentChatRunStatus.running;
  bool get sessionActionsEnabled => canManageAgentChatSessions(state);
  bool get controlsLocked => running || state.sessionTransitioning;
  bool get canSend =>
      state.routeReady && state.initialized && !state.sessionTransitioning;
  bool get isEmpty =>
      state.messages.isEmpty &&
      !(running ||
          state.streamingText.isNotEmpty ||
          state.activities.isNotEmpty);
}

enum AgentChatMoreAction { newSession, rename, compact, delete }

@immutable
class AgentChatPanelCommands {
  const AgentChatPanelCommands({
    required this.collapse,
    required this.detach,
    required this.newSession,
    required this.selectSession,
    required this.renameSession,
    required this.deleteSession,
    required this.moreAction,
    required this.selectModel,
    required this.selectPermissionMode,
    required this.setWebAccessEnabled,
    required this.pickImages,
    required this.send,
    required this.stop,
    required this.dismissError,
    required this.resolveApproval,
    required this.useSuggestion,
    required this.copyUserMessage,
    required this.editLastUserMessage,
    required this.addPendingResource,
    required this.removePendingResource,
  });

  final VoidCallback collapse;
  final Future<void> Function() detach;
  final Future<void> Function() newSession;
  final Future<void> Function(String sessionId) selectSession;
  final Future<void> Function(String sessionId) renameSession;
  final Future<void> Function(String sessionId) deleteSession;
  final Future<void> Function(AgentChatMoreAction action) moreAction;
  final Future<void> Function(String providerId, String model) selectModel;
  final Future<void> Function(AgentPermissionMode mode) selectPermissionMode;
  final Future<void> Function(bool enabled) setWebAccessEnabled;
  final Future<void> Function() pickImages;
  final Future<void> Function() send;
  final VoidCallback stop;
  final VoidCallback dismissError;
  final void Function(bool approved) resolveApproval;
  final void Function(String suggestion) useSuggestion;
  final Future<void> Function(UserMessage message) copyUserMessage;
  final Future<void> Function(UserMessage message) editLastUserMessage;
  final Future<void> Function(AgentChatResourceReference reference)
  addPendingResource;
  final Future<void> Function(int index) removePendingResource;
}
