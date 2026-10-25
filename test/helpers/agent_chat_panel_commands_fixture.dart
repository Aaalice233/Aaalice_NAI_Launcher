import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel_view_data.dart';

/// Panel commands that do nothing, for widgets that only need them wired.
AgentChatPanelCommands inertAgentChatPanelCommands({
  Future<void> Function(Message message, int messageIndex)? editUserMessage,
  Future<ResolvedAgentResource?> Function(AgentChatResourceReference reference)?
  resolveResourcePreview,
}) => AgentChatPanelCommands(
  collapse: () {},
  newSession: () async {},
  selectSession: (_) async {},
  renameSession: (_) async {},
  deleteSession: (_) async {},
  moreAction: (_) async {},
  selectModel: (_, _) async {},
  selectThinkingLevel: (_) async {},
  selectPermissionMode: (_) async {},
  setWebAccessEnabled: (_) async {},
  pickImages: () async {},
  pasteClipboardImage: () async => false,
  attachImageFiles: (_) async {},
  attachCurrentCanvas: () async {},
  openReferenceGallery: () async {},
  openResourceLibrary: () async {},
  resolveResourcePreview: resolveResourcePreview ?? (_) async => null,
  send: () async {},
  sendFollowUp: () async {},
  stop: () {},
  dismissError: () {},
  retryLastMessage: () async {},
  resolveApproval: (_, _) => false,
  useSuggestion: (_) {},
  copyUserMessage: (_) async {},
  editUserMessage: editUserMessage ?? (_, _) async {},
  cancelUserMessageEdit: () {},
  copyAssistantMessage: (_) async {},
  editQueuedMessage: (_) async {},
  removeQueuedMessage: (_) async {},
  clearQueuedMessages: () async {},
  addPendingResource: (_) async {},
  removePendingResource: (_) async {},
);
