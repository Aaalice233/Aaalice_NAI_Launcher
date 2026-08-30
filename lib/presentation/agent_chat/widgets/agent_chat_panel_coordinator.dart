import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';

import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../providers/agent_chat_notifier.dart';
import '../services/agent_chat_session_controller.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_chat_resource_widgets.dart';

/// Translates typed UI commands into notifier, session, model, permission and
/// attachment operations. Widgets never reach into Riverpod or panel State.
class AgentChatPanelCoordinator {
  AgentChatPanelCoordinator({
    required WidgetRef ref,
    required AgentChatPanelController controller,
    required bool Function() isMounted,
  }) : _ref = ref,
       _controller = controller,
       _isMounted = isMounted;

  final WidgetRef _ref;
  final AgentChatPanelController _controller;
  final bool Function() _isMounted;

  AgentChatPanelCommands commands(
    BuildContext context,
    AgentChatState state, {
    AgentChatResourceReference? currentCanvasReference,
  }) {
    return AgentChatPanelCommands(
      collapse: () => _ref
          .read(layoutStateNotifierProvider.notifier)
          .setRightPanelExpanded(false),
      loadEarlierHistory: () =>
          _ref.read(agentChatNotifierProvider.notifier).loadEarlierHistory(),
      newSession: () => _notifier.newSession(),
      selectSession: (sessionId) => _notifier.switchSession(sessionId),
      renameSession: (sessionId) => _renameSession(context, sessionId),
      deleteSession: (sessionId) => _deleteSession(context, sessionId),
      moreAction: (action) => _handleMoreAction(context, state, action),
      selectModel: (providerId, model) =>
          _notifier.selectChatModel(providerId, model),
      selectThinkingLevel: _notifier.setThinkingLevel,
      selectPermissionMode: _notifier.setPermissionMode,
      setWebAccessEnabled: (enabled) => _ref
          .read(agentSettingsProvider.notifier)
          .setWebAccessEnabled(enabled),
      pickImages: () => _pickImages(context),
      attachCurrentCanvas: () =>
          _attachCurrentCanvas(context, currentCanvasReference),
      openReferenceGallery: () => AgentChatResourcePicker.showReferenceGallery(
        context: context,
        ref: _ref,
        onSelected: _notifier.addPendingResource,
      ),
      openResourceLibrary: () => AgentChatResourcePicker.showResourceLibrary(
        context: context,
        ref: _ref,
        onSelected: _notifier.addPendingResource,
      ),
      resolveResourcePreview: _notifier.resolveResourcePreview,
      send: () => _send(context),
      sendFollowUp: () => _send(context, followUp: true),
      stop: _notifier.abort,
      dismissError: _notifier.dismissError,
      retryLastMessage: _retryLastMessage,
      resolveApproval: _notifier.resolveToolApproval,
      useSuggestion: _controller.setSuggestion,
      copyUserMessage: (message) => _copyUserMessage(context, message),
      editUserMessage: (message, messageIndex) =>
          _editUserMessage(state, message, messageIndex),
      cancelUserMessageEdit: _cancelUserMessageEdit,
      copyAssistantMessage: (message) =>
          _copyAssistantMessage(context, message),
      editQueuedMessage: _editQueuedMessage,
      removeQueuedMessage: _notifier.removeQueuedMessage,
      clearQueuedMessages: _notifier.clearQueuedMessages,
      addPendingResource: _notifier.addPendingResource,
      removePendingResource: _notifier.removePendingResource,
    );
  }

  AgentChatNotifier get _notifier =>
      _ref.read(agentChatNotifierProvider.notifier);

  Future<void> _send(BuildContext context, {bool followUp = false}) async {
    if (!await _notifier.validatePendingResourcesForSend()) {
      if (!context.mounted) return;
      AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
      return;
    }
    final text = _controller.inputController.text.trim();
    final images = _controller.pendingImages;
    final content = _controller.buildInlineUserContent(text, images);
    if (content.isEmpty) return;
    final editingMessageIndex = _controller.editingUserMessageIndex;
    AgentChatRewindCheckpoint? checkpoint;
    if (editingMessageIndex != null) {
      if (!await _notifier.prepareEditedSend()) return;
      checkpoint = await _notifier.beginEditedMessageRewind();
      if (checkpoint == null || !_isMounted()) return;
    }
    _controller.followLatest();
    var accepted = false;
    final sent = await _notifier.sendContent(
      content,
      followUp: followUp,
      onAccepted: () async {
        accepted = true;
        if (!_isMounted()) return;
        _controller.takePendingImages();
        await _notifier.clearComposerText();
      },
    );
    if (!_isMounted()) return;
    if (!accepted && !sent && checkpoint != null) {
      await _notifier.restoreEditedMessageRewind(checkpoint);
      if (!_isMounted()) return;
      _controller.restoreDraft(text, images);
    } else if (accepted) {
      _controller.finishEditingUserMessage();
    }
    _controller.inputFocus.requestFocus();
  }

  Future<void> _pickImages(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !_isMounted()) return;
    for (final file in result.files) {
      if (file.size > _maxInlineImageBytes) {
        if (!_isMounted() || !context.mounted) return;
        _showPickError(
          context,
          context.l10n.agentChat_imageTooLarge(file.name, 20),
        );
        continue;
      }
      final bytes = await _readImageBytes(file);
      if (!_isMounted()) return;
      if (bytes == null) continue;
      if (bytes.length > _maxInlineImageBytes) {
        if (!_isMounted() || !context.mounted) return;
        _showPickError(
          context,
          context.l10n.agentChat_imageTooLarge(file.name, 20),
        );
        continue;
      }
      final mimeType = detectImageMime(bytes);
      if (mimeType == null) {
        if (!_isMounted() || !context.mounted) return;
        _showPickError(
          context,
          context.l10n.agentChat_unsupportedImageFormat(file.name),
        );
        continue;
      }
      _controller.addPendingImage(
        PendingAgentChatImage(
          name: file.name,
          bytes: bytes,
          mimeType: mimeType,
        ),
      );
    }
    if (_isMounted()) _controller.inputFocus.requestFocus();
  }

  static const int _maxInlineImageBytes = 20 * 1024 * 1024;

  Future<void> _attachCurrentCanvas(
    BuildContext context,
    AgentChatResourceReference? reference,
  ) async {
    if (reference == null) return;
    final unavailableMessage = context.l10n.agentChat_resourceUnavailable;
    final canvasLabel = context.l10n.agentChat_currentCanvas;
    try {
      if (!await _notifier
          .resolveResourcePreview(reference)
          .then((value) => value?.bytes?.isNotEmpty == true)) {
        throw StateError(unavailableMessage);
      }
      await _notifier.addPendingResource(
        AgentChatResourceReference(
          kind: reference.kind,
          source: reference.source,
          resourceId: reference.resourceId,
          display: {'name': canvasLabel},
        ),
      );
      if (_isMounted()) _controller.inputFocus.requestFocus();
    } on Object catch (error) {
      if (_isMounted() && context.mounted) {
        AppToast.error(
          context,
          context.l10n.agentChat_addResourceFailed('$error'),
        );
      }
    }
  }

  Future<void> _copyUserMessage(
    BuildContext context,
    UserMessage message,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: _editableTextForUserMessage(message)),
    );
    if (_isMounted() && context.mounted) {
      AppToast.info(context, context.l10n.common_copied);
    }
  }

  Future<void> _editUserMessage(
    AgentChatState state,
    Message sourceMessage,
    int messageIndex,
  ) async {
    final lastUserIndex = state.messages.lastIndexWhere(
      (candidate) =>
          candidate is UserMessage ||
          candidate is HarnessCustomMessage &&
              candidate.customType == 'agentResourcePrompt',
    );
    final safe =
        state.status != AgentChatRunStatus.running &&
        !state.sessionTransitioning &&
        state.queuedMessages.isEmpty &&
        state.pendingResources.isEmpty &&
        messageIndex == lastUserIndex;
    if (!safe) return;
    final UserMessage message;
    final references = <AgentChatResourceReference>[];
    if (sourceMessage is UserMessage) {
      message = sourceMessage;
    } else if (sourceMessage is HarnessCustomMessage &&
        sourceMessage.customType == 'agentResourcePrompt') {
      message = UserMessage(
        content: sourceMessage.content.skip(1).toList(growable: false),
        timestamp: sourceMessage.timestamp,
      );
      final encoded = sourceMessage.details is Map
          ? (sourceMessage.details as Map)['references']
          : null;
      if (encoded is List) {
        for (final value in encoded) {
          if (value is Map) {
            references.add(
              AgentChatResourceReferenceCodec.decodeJsonMap(
                Map<String, dynamic>.from(value),
              ),
            );
          }
        }
      }
    } else {
      return;
    }
    final draft = _draftForUserMessage(message);
    if (draft == null || !_isMounted()) return;
    for (final reference in references) {
      await _notifier.addPendingResource(reference);
    }
    await _notifier.validatePendingResourcesForSend();
    if (!_isMounted()) return;
    _controller.beginEditingUserMessage(messageIndex, draft.text, draft.images);
    _controller.inputFocus.requestFocus();
  }

  void _cancelUserMessageEdit() {
    _controller.cancelEditingUserMessage();
    unawaited(_notifier.clearPendingResources());
  }

  Future<void> _editQueuedMessage(AgentQueuedMessage queued) async {
    final removed = _notifier.removeQueuedMessage(queued);
    if (removed == null || !_isMounted()) return;
    UserMessage? userMessage;
    if (removed is UserMessage) {
      userMessage = removed;
    } else if (removed is HarnessCustomMessage &&
        removed.customType == 'agentResourcePrompt') {
      userMessage = UserMessage(
        content: removed.content.skip(1).toList(growable: false),
        timestamp: removed.timestamp,
      );
      final details = removed.details;
      final references = details is Map ? details['references'] : null;
      if (references is List) {
        for (final value in references) {
          if (value is Map) {
            await _notifier.addPendingResource(
              AgentChatResourceReferenceCodec.decodeJsonMap(
                Map<String, dynamic>.from(value),
              ),
            );
          }
        }
      }
    }
    if (userMessage == null || !_isMounted()) return;
    final draft = _draftForUserMessage(userMessage);
    if (draft == null) return;
    _controller.restoreDraft(draft.text, draft.images);
    _controller.inputFocus.requestFocus();
  }

  Future<void> _copyAssistantMessage(
    BuildContext context,
    AssistantMessage message,
  ) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (_isMounted() && context.mounted) {
      AppToast.info(context, context.l10n.common_copied);
    }
  }

  Future<void> _retryLastMessage() async {
    final message = await _notifier.rewindLastUserMessage();
    if (message == null || !_isMounted()) return;
    _controller.followLatest();
    await _notifier.sendContent(message.content);
  }

  _AgentChatMessageDraft? _draftForUserMessage(UserMessage message) {
    final images = <PendingAgentChatImage>[];
    for (final block in message.content) {
      if (block is! UserImageContent) continue;
      final source = block.image.source;
      final bytes = source.bytes;
      final mimeType = source.mimeType;
      if (bytes == null || mimeType == null || mimeType.isEmpty) return null;
      final imageNumber = images.length + 1;
      final extension = switch (mimeType) {
        'image/jpeg' => 'jpg',
        'image/svg+xml' => 'svg',
        _ => mimeType.split('/').last,
      };
      images.add(
        PendingAgentChatImage(
          name: 'image$imageNumber.$extension',
          bytes: bytes,
          mimeType: mimeType,
        ),
      );
    }
    return _AgentChatMessageDraft(
      text: _editableTextForUserMessage(message),
      images: images,
    );
  }

  String _editableTextForUserMessage(UserMessage message) {
    final buffer = StringBuffer();
    var imageNumber = 0;
    for (final block in message.content) {
      if (block is UserTextContent) {
        buffer.write(block.text);
      } else if (block is UserImageContent) {
        imageNumber++;
        final current = buffer.toString();
        if (current.isNotEmpty && !RegExp(r'\s$').hasMatch(current)) {
          buffer.write(' ');
        }
        buffer.write('[image$imageNumber]');
      }
    }
    return buffer.toString();
  }

  Future<Uint8List?> _readImageBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return File(path).readAsBytes();
  }

  void _showPickError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ),
      );
  }

  Future<void> _renameSession(BuildContext context, String sessionId) async {
    final l10n = context.l10n;
    final summary = _ref
        .read(agentChatNotifierProvider)
        .sessions
        .where((session) => session.id == sessionId)
        .firstOrNull;
    final name = await ThemedInputDialog.show(
      context: context,
      title: l10n.common_rename,
      labelText: l10n.agentChat_renameHint,
      initialValue: summary == null || summary.name.isEmpty
          ? null
          : summary.name,
    );
    if (name == null || !_isMounted()) return;
    await _notifier.renameSession(sessionId, name);
  }

  Future<void> _deleteSession(BuildContext context, String sessionId) async {
    final l10n = context.l10n;
    final summary = _ref
        .read(agentChatNotifierProvider)
        .sessions
        .where((session) => session.id == sessionId)
        .firstOrNull;
    final confirmed = await ThemedConfirmDialog.showDelete(
      context: context,
      itemName: summary == null || summary.name.isEmpty
          ? l10n.agentChat_untitled
          : summary.name,
    );
    if (!confirmed || !_isMounted()) return;
    await _notifier.deleteSession(sessionId);
  }

  Future<void> _handleMoreAction(
    BuildContext context,
    AgentChatState state,
    AgentChatMoreAction action,
  ) async {
    switch (action) {
      case AgentChatMoreAction.newSession:
        await _notifier.newSession();
      case AgentChatMoreAction.rename:
        await _renameSession(context, state.activeSessionId);
      case AgentChatMoreAction.compact:
        await _notifier.compactNow();
      case AgentChatMoreAction.delete:
        await _deleteSession(context, state.activeSessionId);
    }
  }
}

class _AgentChatMessageDraft {
  const _AgentChatMessageDraft({required this.text, required this.images});

  final String text;
  final List<PendingAgentChatImage> images;
}
