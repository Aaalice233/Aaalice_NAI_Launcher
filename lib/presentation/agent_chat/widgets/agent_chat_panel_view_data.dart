import 'package:flutter/material.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/windowing/agent_chat_layout_contract.dart';
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
    required this.width,
    required this.height,
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
  final double width;
  final double height;
  final VoidCallback? onClose;
  final VoidCallback? onOpenSettings;
  final Widget Function(Widget child)? mobileHeaderWrapper;

  bool get running => state.status == AgentChatRunStatus.running;
  AgentChatWidthClass get widthClass =>
      AgentChatLayoutContract.widthClassFor(width);
  bool get compactWidth => widthClass == AgentChatWidthClass.compact;
  bool get stackComposerControls =>
      AgentChatLayoutContract.stackComposerControls(width, running: running);
  double get userBubbleMaxWidth =>
      AgentChatLayoutContract.userBubbleMaxWidth(width);
  double get assistantMaxWidth =>
      AgentChatLayoutContract.assistantMaxWidth(width);
  bool get sessionActionsEnabled => canManageAgentChatSessions(state);
  bool get controlsLocked => running || state.sessionTransitioning;
  bool get canSend =>
      state.routeReady && state.initialized && !state.sessionTransitioning;
  bool get isEmpty =>
      state.messages.isEmpty &&
      !(running ||
          state.streamingMessage != null ||
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
    required this.selectThinkingLevel,
    required this.selectPermissionMode,
    required this.setWebAccessEnabled,
    required this.pickImages,
    required this.send,
    required this.sendFollowUp,
    required this.stop,
    required this.dismissError,
    required this.retryLastMessage,
    required this.resolveApproval,
    required this.useSuggestion,
    required this.copyUserMessage,
    required this.copyAssistantMessage,
    required this.editLastUserMessage,
    required this.editQueuedMessage,
    required this.removeQueuedMessage,
    required this.clearQueuedMessages,
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
  final Future<void> Function(ThinkingLevel level) selectThinkingLevel;
  final Future<void> Function(AgentPermissionMode mode) selectPermissionMode;
  final Future<void> Function(bool enabled) setWebAccessEnabled;
  final Future<void> Function() pickImages;
  final Future<void> Function() send;
  final Future<void> Function() sendFollowUp;
  final VoidCallback stop;
  final VoidCallback dismissError;
  final Future<void> Function() retryLastMessage;
  final bool Function(String toolCallId, bool approved) resolveApproval;
  final void Function(String suggestion) useSuggestion;
  final Future<void> Function(UserMessage message) copyUserMessage;
  final Future<void> Function(AssistantMessage message) copyAssistantMessage;
  final Future<void> Function(UserMessage message) editLastUserMessage;
  final Future<void> Function(AgentQueuedMessage message) editQueuedMessage;
  final void Function(AgentQueuedMessage message) removeQueuedMessage;
  final VoidCallback clearQueuedMessages;
  final Future<void> Function(AgentChatResourceReference reference)
  addPendingResource;
  final Future<void> Function(int index) removePendingResource;
}
