import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as md;

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_messages.dart';
import '../../../core/utils/localization_extension.dart';
import '../../widgets/common/draggable_memory_image.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_chat_tool_widgets.dart';

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
    var lastUserMessageIndex = -1;
    for (var index = state.messages.length - 1; index >= 0; index--) {
      final message = state.messages[index];
      if (message is UserMessage ||
          (message is HarnessCustomMessage &&
              message.customType == 'agentResourcePrompt')) {
        lastUserMessageIndex = index;
        break;
      }
    }
    final items = _transcriptItems(state.messages);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: controller.handleScrollNotification,
          child: ListView.builder(
            controller: controller.scrollController,
            reverse: true,
            padding: EdgeInsets.symmetric(
              horizontal: viewData.mobile ? 16 : 10,
              vertical: viewData.mobile ? 12 : 8,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, itemIndex) {
              if (itemIndex == 0) {
                return _liveTile(context, theme, state);
              }
              final item = items[items.length - itemIndex];
              if (item.toolResults != null) {
                return AgentChatToolResultGroup(results: item.toolResults!);
              }
              return _messageTile(
                context,
                theme,
                item.message!,
                messageIndex: item.messageIndex,
                isLastUserMessage: item.messageIndex == lastUserMessageIndex,
              );
            },
          ),
        ),
        if (controller.showJumpToLatest)
          Positioned(
            right: viewData.mobile ? 16 : 10,
            bottom: 10,
            child: FilledButton.tonalIcon(
              key: const ValueKey('agent-chat-jump-to-latest'),
              onPressed: () => controller.scrollToBottom(force: true),
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

  List<_AgentTranscriptItem> _transcriptItems(List<Message> messages) {
    final items = <_AgentTranscriptItem>[];
    var index = 0;
    while (index < messages.length) {
      final message = messages[index];
      if (message is AssistantMessage &&
          !_hasVisibleAssistantContent(message) &&
          message.toolCalls.isNotEmpty &&
          index + 1 < messages.length &&
          messages[index + 1] is ToolResultMessage) {
        index++;
        continue;
      }
      if (message is ToolResultMessage) {
        final results = <ToolResultMessage>[];
        final firstIndex = index;
        while (index < messages.length) {
          final candidate = messages[index];
          if (candidate is ToolResultMessage) {
            results.add(candidate);
            index++;
            continue;
          }
          if (candidate is AssistantMessage &&
              !_hasVisibleAssistantContent(candidate) &&
              candidate.toolCalls.isNotEmpty &&
              index + 1 < messages.length &&
              messages[index + 1] is ToolResultMessage) {
            index++;
            continue;
          }
          break;
        }
        items.add(
          _AgentTranscriptItem.toolResults(results, messageIndex: firstIndex),
        );
        continue;
      }
      items.add(_AgentTranscriptItem.message(message, messageIndex: index));
      index++;
    }
    return items;
  }

  bool _hasVisibleAssistantContent(AssistantMessage message) =>
      message.text.trim().isNotEmpty ||
      message.content.whereType<AssistantThinkingContent>().any(
        (content) => content.thinking.trim().isNotEmpty,
      );

  Widget _hero(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
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
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icons/Icon.png',
                      width: 44,
                      height: 44,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.smart_toy_outlined,
                          size: 26,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l10n.agentChat_heroTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.agentChat_heroSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final suggestion in suggestions)
                  ActionChip(
                    label: Text(
                      suggestion,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    tooltip: suggestion,
                    visualDensity: viewData.mobile
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                    onPressed: () => commands.useSuggestion(suggestion),
                  ),
              ],
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
    required bool isLastUserMessage,
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
        isLastUserMessage: isLastUserMessage,
      );
    }
    if (message is UserMessage) {
      final hasText = message.text.trim().isNotEmpty;
      final hovered = controller.hoveredUserMessageIndex == messageIndex;
      final canEdit = isLastUserMessage && viewData.sessionActionsEnabled;
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
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
                                _userImage(theme, image),
                            ],
                          ),
                        ),
                      if (hasText)
                        Text(
                          message.text,
                          style:
                              (viewData.mobile
                                      ? theme.textTheme.bodyMedium
                                      : theme.textTheme.bodySmall)
                                  ?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    height: 1.45,
                                  ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: viewData.mobile ? 44 : 22,
                  child: AnimatedOpacity(
                    key: ValueKey('agent-user-message-actions-$messageIndex'),
                    opacity: viewData.mobile || hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: IgnorePointer(
                      ignoring: !viewData.mobile && !hovered,
                      child: ExcludeSemantics(
                        excluding: !viewData.mobile && !hovered,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sentAt,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.58),
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 5),
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
                            if (isLastUserMessage)
                              _MessageActionButton(
                                key: ValueKey(
                                  'agent-user-message-edit-$messageIndex',
                                ),
                                tooltip: context.l10n.common_edit,
                                icon: Icons.edit_outlined,
                                largeHitArea: viewData.mobile,
                                onPressed: canEdit
                                    ? () =>
                                          commands.editLastUserMessage(message)
                                    : null,
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (thinking.trim().isNotEmpty)
            AgentChatReasoningTile(thinking: thinking),
          if (message.text.trim().isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: md.MarkdownBody(
                data: message.text,
                selectable: true,
                imageBuilder: (uri, _, alt) => _markdownImage(theme, uri, alt),
                styleSheet: md.MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p:
                      (viewData.mobile
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodySmall)
                          ?.copyWith(height: 1.55),
                  code:
                      (viewData.mobile
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodySmall)
                          ?.copyWith(
                            fontFamily: 'monospace',
                            backgroundColor: theme
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.6),
                          ),
                  codeblockDecoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (message.text.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: _MessageActionButton(
                key: ValueKey('agent-assistant-message-copy-$messageIndex'),
                tooltip: context.l10n.common_copy,
                icon: Icons.copy_all_outlined,
                largeHitArea: viewData.mobile,
                onPressed: () => commands.copyAssistantMessage(message),
              ),
            ),
        ],
      );
    }
    if (message is ToolResultMessage) {
      return AgentChatToolResultTile(result: message);
    }
    return const SizedBox.shrink();
  }

  Widget _userImage(ThemeData theme, ImageContent image) {
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
    final content = SizedBox(
      width: size.width,
      height: size.height,
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

  Widget _markdownImage(ThemeData theme, Uri uri, String? alt) {
    Widget image;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      image = Image.network(
        uri.toString(),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _brokenImage(theme),
      );
    } else if (scheme == 'data') {
      try {
        final key = uri.toString();
        final bytes = controller.markdownDataImageBytes.putIfAbsent(
          key,
          () => uri.data!.contentAsBytes(),
        );
        image = Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _brokenImage(theme),
        );
      } catch (_) {
        image = _brokenImage(theme);
      }
    } else if (scheme == 'resource') {
      image = Image.asset(
        uri.path,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _brokenImage(theme),
      );
    } else {
      try {
        final file = scheme == 'file'
            ? File.fromUri(uri)
            : File(uri.toFilePath(windows: Platform.isWindows));
        image = Image.file(
          file,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _brokenImage(theme),
        );
      } catch (_) {
        image = _brokenImage(theme);
      }
    }
    return Semantics(
      label: alt,
      image: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 220),
        child: AspectRatio(
          aspectRatio: 320 / 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
        ),
      ),
    );
  }

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

  Widget _liveTile(
    BuildContext context,
    ThemeData theme,
    AgentChatState state,
  ) {
    final runningActivities = state.activities
        .where((activity) => activity.status == AgentToolActivityStatus.running)
        .toList();
    final hasActivities = runningActivities.isNotEmpty;
    final streaming = state.streamingMessage;
    final hasStreaming = streaming != null;
    final running = state.status == AgentChatRunStatus.running;
    if (!hasActivities && !hasStreaming && !running) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final activity in runningActivities)
          AgentChatToolActivityTile(activity: activity),
        if (streaming != null) ...[
          if (streaming.content
              .whereType<AssistantThinkingContent>()
              .map((content) => content.thinking)
              .join()
              .trim()
              .isNotEmpty)
            AgentChatReasoningTile(
              thinking: streaming.content
                  .whereType<AssistantThinkingContent>()
                  .map((content) => content.thinking)
                  .join(),
              live: streaming.text.isEmpty,
            ),
          if (streaming.text.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                streaming.text,
                style:
                    (viewData.mobile
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodySmall)
                        ?.copyWith(height: 1.55),
              ),
            ),
        ],
        if (running && !hasStreaming && !hasActivities)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.agentChat_thinking,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
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
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkResponse(
        onTap: onPressed,
        radius: largeHitArea ? 24 : 14,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: SizedBox.square(
          dimension: largeHitArea ? 44 : 22,
          child: Center(
            child: Icon(
              icon,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: enabled ? 0.72 : 0.28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentTranscriptItem {
  const _AgentTranscriptItem._({
    required this.messageIndex,
    this.message,
    this.toolResults,
  });

  factory _AgentTranscriptItem.message(
    Message message, {
    required int messageIndex,
  }) => _AgentTranscriptItem._(messageIndex: messageIndex, message: message);

  factory _AgentTranscriptItem.toolResults(
    List<ToolResultMessage> results, {
    required int messageIndex,
  }) =>
      _AgentTranscriptItem._(messageIndex: messageIndex, toolResults: results);

  final int messageIndex;
  final Message? message;
  final List<ToolResultMessage>? toolResults;
}
