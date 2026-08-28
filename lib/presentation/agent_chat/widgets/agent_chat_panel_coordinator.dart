import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/agent/agent_types.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/windowing/agent_window_runtime.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';

import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_view_data.dart';

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

  AgentChatPanelCommands commands(BuildContext context, AgentChatState state) {
    return AgentChatPanelCommands(
      collapse: () => _ref
          .read(layoutStateNotifierProvider.notifier)
          .setRightPanelExpanded(false),
      detach: () async {
        try {
          await AgentWindowRuntime.instance.open();
        } on Object catch (error, stackTrace) {
          AppLogger.e(
            'Failed to open detached Agent window',
            error,
            stackTrace,
            'AgentWindow',
          );
          if (context.mounted) {
            AppToast.error(context, context.l10n.agentChat_detachWindowFailed);
          }
          return;
        }
        _ref
            .read(layoutStateNotifierProvider.notifier)
            .setRightPanelExpanded(false);
      },
      newSession: () => _notifier.newSession(),
      selectSession: (sessionId) => _notifier.switchSession(sessionId),
      renameSession: (sessionId) => _renameSession(context, sessionId),
      deleteSession: (sessionId) => _deleteSession(context, sessionId),
      moreAction: (action) => _handleMoreAction(context, state, action),
      selectModel: (providerId, model) =>
          _notifier.selectChatModel(providerId, model),
      selectPermissionMode: _notifier.setPermissionMode,
      setWebAccessEnabled: (enabled) => _ref
          .read(agentSettingsProvider.notifier)
          .setWebAccessEnabled(enabled),
      pickImages: () => _pickImages(context),
      send: () => _send(context, state),
      stop: _notifier.abort,
      dismissError: _notifier.dismissError,
      resolveApproval: _notifier.resolveToolApproval,
      useSuggestion: _controller.setSuggestion,
      copyUserMessage: (message) => _copyUserMessage(context, message),
      editLastUserMessage: (message) => _editLastUserMessage(context, message),
      addPendingResource: _notifier.addPendingResource,
      removePendingResource: _notifier.removePendingResource,
    );
  }

  AgentChatNotifier get _notifier =>
      _ref.read(agentChatNotifierProvider.notifier);

  Future<void> _send(BuildContext context, AgentChatState state) async {
    if (!await _notifier.validatePendingResourcesForSend()) {
      if (!context.mounted) return;
      AppToast.error(context, context.l10n.agentChat_resourceUnavailable);
      return;
    }
    final text = _controller.inputController.text.trim();
    final images = _controller.pendingImages;
    final content = _controller.buildInlineUserContent(text, images);
    if (content.isEmpty) return;
    _controller.takePendingImages();
    await _notifier.clearComposerText();
    await _notifier.sendContent(content);
    if (_isMounted()) _controller.inputFocus.requestFocus();
  }

  Future<void> _pickImages(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !_isMounted()) return;
    for (final file in result.files) {
      final bytes = await _readImageBytes(file);
      if (!_isMounted()) return;
      if (bytes == null) continue;
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

  Future<void> _editLastUserMessage(
    BuildContext context,
    UserMessage message,
  ) async {
    final draft = _draftForUserMessage(message);
    if (draft == null) return;
    final rewound = await _notifier.rewindLastUserMessage();
    if (!_isMounted() ||
        !context.mounted ||
        rewound == null ||
        rewound.timestamp != message.timestamp) {
      return;
    }
    _controller.restoreDraft(draft.text, draft.images);
    _controller.inputFocus.requestFocus();
    _controller.scrollToBottom(force: true);
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
