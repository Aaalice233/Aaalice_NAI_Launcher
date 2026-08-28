import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';

import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
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
      newSession: () => _notifier.newSession(),
      selectSession: (sessionId) => _notifier.switchSession(sessionId),
      renameSession: (sessionId) => _renameSession(context, sessionId),
      deleteSession: (sessionId) => _deleteSession(context, sessionId),
      moreAction: (action) => _handleMoreAction(context, state, action),
      selectModel: (providerId, model) =>
          _notifier.selectChatModel(providerId, model),
      selectPermissionMode: _notifier.setPermissionMode,
      pickImages: () => _pickImages(context),
      send: _send,
      stop: _notifier.abort,
      dismissError: _notifier.dismissError,
      resolveApproval: _notifier.resolveToolApproval,
      useSuggestion: _controller.setSuggestion,
    );
  }

  AgentChatNotifier get _notifier =>
      _ref.read(agentChatNotifierProvider.notifier);

  Future<void> _send() async {
    final text = _controller.inputController.text.trim();
    final images = _controller.pendingImages;
    final content = _controller.buildInlineUserContent(text, images);
    if (content.isEmpty) return;
    _controller.takePendingImages();
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
