import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/windowing/agent_chat_layout_contract.dart';
import '../../../core/windowing/agent_chat_shared_widgets.dart';
import '../../widgets/common/draggable_memory_image.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_chat_history.dart';
import 'agent_chat_tool_widgets.dart';
import 'agent_chat_turn.dart';

class AgentChatMessages extends StatelessWidget {
  const AgentChatMessages({
    super.key,
    required this.viewData,
    required this.commands,
    required this.controller,
  });

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;
  final AgentChatPanelController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = viewData.state;
    if (!state.initialized || state.sessionContentLoading) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: context.l10n.common_loading,
          child: const SizedBox(
            key: ValueKey('agent-chat-session-loading'),
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (viewData.isEmpty && !state.routeReady) {
      return _setupHint(context, theme);
    }
    if (viewData.isEmpty) {
      return _hero(context, theme);
    }
    final lastAssistantMessageIndex = state.messages.lastIndexWhere(
      (message) =>
          message is AssistantMessage &&
          message.toolCalls.isEmpty &&
          message.stopReason != StopReason.toolUse &&
          message.text.trim().isNotEmpty,
    );
    final lastUserMessageIndex = state.messages.lastIndexWhere(
      (message) =>
          message is UserMessage ||
          message is HarnessCustomMessage &&
              message.customType == 'agentResourcePrompt',
    );
    final canEditLastUserMessage =
        !viewData.running &&
        !state.sessionTransitioning &&
        state.queuedMessages.isEmpty &&
        state.pendingResources.isEmpty;
    final thread = AgentChatThreadModel.fromMessages(
      state.messages,
      timeline: state.turns,
    );
    final streaming = state.streamingMessage;
    final streamingUsesTools =
        streaming != null &&
        (streaming.toolCalls.isNotEmpty ||
            streaming.stopReason == StopReason.toolUse);
    final streamingReasoning = streaming == null
        ? ''
        : [
            streaming.content
                .whereType<AssistantThinkingContent>()
                .map((content) => content.thinking.trim())
                .where((text) => text.isNotEmpty)
                .join('\n\n'),
            if (streamingUsesTools) streaming.text.trim(),
          ].where((text) => text.isNotEmpty).join('\n\n');
    if (thread.turns.isEmpty &&
        (state.streamingMessage != null ||
            state.status == AgentChatRunStatus.running ||
            state.activities.isNotEmpty)) {
      thread.turns.add(
        AgentChatTurnModel(
          ordinal: 0,
          timeline: state.turns.isEmpty ? null : state.turns.last,
        ),
      );
    }
    return Stack(
      children: [
        AgentChatThreadViewport(
          sessionId: state.activeSessionId,
          turns: thread.turns,
          controller: controller,
          horizontalPadding:
              AgentChatLayoutContract.transcriptHorizontalPadding(
                viewData.width,
              ),
          maxWidth: AgentChatLayoutContract.transcriptMaxWidth(viewData.width),
          mobile: viewData.mobile,
          hasEarlier: state.hasEarlierTurns,
          historyLoading: state.historyLoading,
          prependAnchorEntryId: state.prependAnchorEntryId,
          onLoadEarlier: commands.loadEarlierHistory,
          live: const SizedBox.shrink(),
          turnBuilder: (context, turn, current) => Column(
            key: ValueKey('agent-turn-content-${turn.ordinal}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (turn.userMessage != null)
                _messageTile(
                  context,
                  theme,
                  turn.userMessage!,
                  messageIndex: turn.userMessageIndex,
                  isLastAssistantMessage: false,
                  canEditUserMessage:
                      canEditLastUserMessage &&
                      turn.userMessageIndex == lastUserMessageIndex,
                ),
              AgentChatWorkTrail(
                turn: turn,
                running: current && state.status == AgentChatRunStatus.running,
                activities: current ? state.activities : const [],
                streamingReasoning: current ? streamingReasoning : '',
              ),
              for (final result in turn.mediaResults)
                AgentChatToolResultMedia(result: result),
              for (final finalMessage in turn.finalMessages)
                _messageTile(
                  context,
                  theme,
                  finalMessage.message,
                  messageIndex: finalMessage.index,
                  isLastAssistantMessage:
                      finalMessage.index == lastAssistantMessageIndex,
                  showReasoning: false,
                ),
              if (current && streaming != null && !streamingUsesTools)
                _streamingFinalTile(context, theme, streaming),
            ],
          ),
        ),
        if (controller.showJumpToLatest)
          Positioned(
            right: viewData.mobile ? 16 : 10,
            bottom: 10,
            child: FilledButton.tonalIcon(
              key: const ValueKey('agent-chat-jump-to-latest'),
              onPressed: controller.followLatest,
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: Text(context.l10n.agentChat_jumpToLatest),
              style: FilledButton.styleFrom(
                minimumSize: Size(0, viewData.mobile ? 44 : 34),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
      ],
    );
  }

  Widget _hero(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.78);
    final suggestions = [
      l10n.agentChat_suggestion1,
      l10n.agentChat_suggestion2,
      l10n.agentChat_suggestion3,
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icons/Icon.png',
                  width: 64,
                  height: 64,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 30,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.agentChat_heroTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.agentChat_heroSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  children: [
                    for (var index = 0; index < suggestions.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            key: ValueKey('agent-chat-suggestion-$index'),
                            onTap: () =>
                                commands.useSuggestion(suggestions[index]),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    switch (index) {
                                      0 => Icons.tune_rounded,
                                      1 => Icons.image_search_outlined,
                                      _ => Icons.sell_outlined,
                                    },
                                    size: 17,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      suggestions[index],
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.86),
                                            height: 1.35,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 17,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.52),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setupHint(BuildContext context, ThemeData theme) {
    final compact = viewData.compactMobile;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 28,
          vertical: compact ? 12 : 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 52 : 64,
                height: compact ? 52 : 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(compact ? 16 : 20),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: compact ? 26 : 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(height: compact ? 12 : 18),
              Text(
                context.l10n.settings_promptAssistant,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.agentChat_needSetup,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (viewData.onOpenSettings != null) ...[
                SizedBox(height: compact ? 14 : 22),
                FilledButton.icon(
                  key: const ValueKey('agent-chat-open-settings'),
                  onPressed: viewData.onOpenSettings,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(context.l10n.promptAssistant_assistantSettings),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageTile(
    BuildContext context,
    ThemeData theme,
    Message message, {
    required int messageIndex,
    required bool isLastAssistantMessage,
    bool showReasoning = true,
    bool canEditUserMessage = false,
    Message? editSourceMessage,
  }) {
    if (message is HarnessCustomMessage &&
        message.customType == 'agentResourcePrompt') {
      return _messageTile(
        context,
        theme,
        UserMessage(
          content: message.content.skip(1).toList(growable: false),
          timestamp: message.timestamp,
        ),
        messageIndex: messageIndex,
        isLastAssistantMessage: isLastAssistantMessage,
        showReasoning: showReasoning,
        canEditUserMessage: canEditUserMessage,
        editSourceMessage: message,
      );
    }
    if (message is UserMessage) {
      final hasText = message.text.trim().isNotEmpty;
      final hovered = controller.hoveredUserMessageIndex == messageIndex;
      final actionsFocused = controller.focusedUserMessageIndex == messageIndex;
      final sentAt = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(
          DateTime.fromMillisecondsSinceEpoch(message.timestamp),
        ),
        alwaysUse24HourFormat: true,
      );
      return MouseRegion(
        key: ValueKey('agent-user-message-$messageIndex'),
        onEnter: (_) => controller.setHoveredUserMessageIndex(messageIndex),
        onExit: (_) {
          if (controller.hoveredUserMessageIndex == messageIndex) {
            controller.setHoveredUserMessageIndex(null);
          }
        },
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  key: ValueKey('agent-user-message-bubble-$messageIndex'),
                  constraints: BoxConstraints(
                    minWidth: hasText ? 44 : 0,
                    maxWidth: viewData.userBubbleMaxWidth,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (message.images.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: hasText ? 6 : 0),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.end,
                              children: [
                                for (final image in message.images)
                                  _userImage(
                                    theme,
                                    image,
                                    maxWidth: viewData.userBubbleMaxWidth - 24,
                                  ),
                              ],
                            ),
                          ),
                        if (hasText)
                          Text(
                            message.text,
                            key: ValueKey(
                              'agent-user-message-text-$messageIndex',
                            ),
                            textAlign: TextAlign.center,
                            style:
                                (viewData.mobile
                                        ? theme.textTheme.bodyMedium
                                        : theme.textTheme.bodySmall)
                                    ?.copyWith(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      height: 1.45,
                                    ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sentAt,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.58),
                                fontSize: 9,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.done_all_rounded,
                              size: 11,
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.58),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Focus(
                  onFocusChange: (focused) =>
                      controller.setFocusedUserMessageIndex(
                        focused ? messageIndex : null,
                      ),
                  child: SizedBox(
                    height: viewData.mobile ? 48 : 32,
                    child: AnimatedOpacity(
                      key: ValueKey('agent-user-message-actions-$messageIndex'),
                      opacity: viewData.mobile || hovered || actionsFocused
                          ? 1
                          : 0,
                      duration: const Duration(milliseconds: 120),
                      child: IgnorePointer(
                        ignoring:
                            !viewData.mobile && !hovered && !actionsFocused,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canEditUserMessage)
                              _MessageActionButton(
                                key: ValueKey(
                                  'agent-user-message-edit-$messageIndex',
                                ),
                                tooltip: context.l10n.common_edit,
                                icon: Icons.edit_outlined,
                                largeHitArea: viewData.mobile,
                                onPressed: controller.isEditingUserMessage
                                    ? null
                                    : () => commands.editUserMessage(
                                        editSourceMessage ?? message,
                                        messageIndex,
                                      ),
                              ),
                            _MessageActionButton(
                              key: ValueKey(
                                'agent-user-message-copy-$messageIndex',
                              ),
                              tooltip: context.l10n.common_copy,
                              icon: Icons.copy_all_outlined,
                              largeHitArea: viewData.mobile,
                              onPressed: () =>
                                  commands.copyUserMessage(message),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (message is AssistantMessage) {
      final thinking = message.content
          .whereType<AssistantThinkingContent>()
          .map((content) => content.thinking)
          .join();
      if (message.text.trim().isEmpty && thinking.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: viewData.assistantMaxWidth.clamp(0, 680),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showReasoning && thinking.trim().isNotEmpty)
                  AgentChatReasoningTile(thinking: thinking),
                if (message.text.trim().isNotEmpty)
                  _assistantMarkdown(message.text),
                if (message.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatMessageTime(context, message.timestamp),
                    key: ValueKey('agent-assistant-message-time-$messageIndex'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AssistantActionBar(
                    messageIndex: messageIndex,
                    onCopy: () => commands.copyAssistantMessage(message),
                    onRetry: isLastAssistantMessage && !viewData.running
                        ? commands.retryLastMessage
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    if (message is ToolResultMessage) {
      return AgentChatToolResultTile(result: message);
    }
    return const SizedBox.shrink();
  }

  Widget _userImage(
    ThemeData theme,
    ImageContent image, {
    required double maxWidth,
  }) {
    final source = image.source;
    final bytes = controller.bytesForMessageImage(source);
    final Size size;
    final Widget imageWidget;
    if (bytes != null) {
      size = controller.displaySizeForMessageImage(source, bytes);
      imageWidget = Image.memory(
        bytes,
        width: size.width,
        height: size.height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _brokenImage(theme),
      );
    } else if (source.url case final url?) {
      size = const Size(180, 140);
      imageWidget = Image.network(
        url,
        width: size.width,
        height: size.height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _brokenImage(theme),
      );
    } else {
      size = const Size(160, 120);
      imageWidget = _brokenImage(theme);
    }
    final scale = size.width > maxWidth ? maxWidth / size.width : 1.0;
    final displaySize = Size(size.width * scale, size.height * scale);
    final content = SizedBox(
      width: displaySize.width,
      height: displaySize.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageWidget,
      ),
    );
    if (bytes == null) return content;
    return DraggableMemoryImage(
      imageBytes: bytes,
      fileName: _agentChatImageFileName(source.mimeType, 'attachment'),
      localData: _agentChatImageDragLocalData,
      feedbackWidth: 200,
      child: content,
    );
  }

  Widget _markdownImage(Uri uri, String? alt) {
    Uint8List? dataBytes;
    if (uri.scheme.toLowerCase() == 'data') {
      try {
        final key = uri.toString();
        dataBytes = controller.markdownDataImageBytes.putIfAbsent(
          key,
          () => uri.data!.contentAsBytes(),
        );
      } catch (_) {}
    }
    return AgentChatMarkdownImage(uri: uri, alt: alt, dataBytes: dataBytes);
  }

  Widget _assistantMarkdown(String text) => AgentChatMarkdownContent(
    key: ValueKey('agent-assistant-markdown-${text.hashCode}'),
    text: text,
    touchOptimized: viewData.mobile,
    imageBuilder: (uri, _, alt) => _markdownImage(uri, alt),
  );

  Widget _brokenImage(ThemeData theme) => ColoredBox(
    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    child: Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 20,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    ),
  );

  Widget _streamingFinalTile(
    BuildContext context,
    ThemeData theme,
    AssistantMessage streaming,
  ) {
    if (streaming.text.trim().isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      key: const ValueKey('agent-streaming-final'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: viewData.assistantMaxWidth.clamp(0, 680),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _assistantMarkdown(streaming.text),
              const SizedBox(height: 8),
              _StreamingStatus(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMessageTime(BuildContext context, int timestamp) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp)),
      alwaysUse24HourFormat: true,
    );

class _StreamingStatus extends StatelessWidget {
  const _StreamingStatus({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: context.l10n.agentChat_phaseResponding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.agentChat_phaseResponding,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantActionBar extends StatelessWidget {
  const _AssistantActionBar({
    required this.messageIndex,
    required this.onCopy,
    required this.onRetry,
  });

  final int messageIndex;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: ValueKey('agent-assistant-message-actions-$messageIndex'),
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MessageActionButton(
            key: ValueKey('agent-assistant-message-copy-$messageIndex'),
            tooltip: context.l10n.common_copy,
            icon: Icons.copy_all_outlined,
            largeHitArea: true,
            onPressed: onCopy,
          ),
          _MessageActionButton(
            key: ValueKey('agent-assistant-message-retry-$messageIndex'),
            tooltip: context.l10n.common_retry,
            icon: Icons.refresh_rounded,
            largeHitArea: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

const Map<String, Object> _agentChatImageDragLocalData = {
  'source': 'agent_chat_internal',
};

String _agentChatImageFileName(String? mimeType, String stem) {
  final extension = switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    'image/bmp' => 'bmp',
    _ => 'png',
  };
  return '$stem.$extension';
}

class _MessageActionButton extends StatelessWidget {
  const _MessageActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.largeHitArea = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool largeHitArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimension = largeHitArea ? 48.0 : 32.0;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
      disabledColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
      constraints: BoxConstraints.tightFor(width: dimension, height: dimension),
      padding: EdgeInsets.zero,
      // Agent density changes spacing, not accessible pointer target sizes.
      visualDensity: VisualDensity.standard,
    );
  }
}
