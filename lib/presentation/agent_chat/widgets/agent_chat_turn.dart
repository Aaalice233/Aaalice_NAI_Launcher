import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/agent/agent_media_display_policy.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import '../models/agent_chat_prompt_envelope.dart';
import '../models/agent_chat_turn_timeline.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_tool_widgets.dart';

/// Immutable display projection for Thread -> Turn -> Item.
///
/// The runtime message list remains untouched. This projection only decides
/// which causal items share a visual turn and which details start collapsed.
class AgentChatThreadModel {
  const AgentChatThreadModel({required this.turns});

  factory AgentChatThreadModel.fromMessages(
    List<Message> messages, {
    List<AgentChatTurnTimeline> timeline = const [],
  }) {
    final turns = <AgentChatTurnModel>[];
    void addMessage(AgentChatTurnModel turn, Message message, int index) {
      if (message is! AssistantMessage && message is! ToolResultMessage) {
        return;
      }
      if (message is AssistantMessage) {
        final toolUse =
            message.toolCalls.isNotEmpty ||
            message.stopReason == StopReason.toolUse;
        if (toolUse) {
          for (final content in message.content) {
            if (content case AssistantThinkingContent(
              :final thinking,
            ) when thinking.trim().isNotEmpty) {
              turn.workItems.add(
                AgentChatTurnItem.reasoning(
                  thinking: thinking.trim(),
                  messageIndex: index,
                  timestamp: message.timestamp,
                ),
              );
            } else if (content case AssistantTextContent(
              :final text,
            ) when text.trim().isNotEmpty) {
              turn.workItems.add(
                AgentChatTurnItem.narration(
                  narration: text.trim(),
                  messageIndex: index,
                  timestamp: message.timestamp,
                ),
              );
            } else if (content case final ToolCallContent call) {
              turn.workItems.add(
                AgentChatTurnItem.tool(
                  call: call,
                  messageIndex: index,
                  timestamp: message.timestamp,
                ),
              );
            }
          }
        } else {
          final thinking = message.content
              .whereType<AssistantThinkingContent>()
              .map((content) => content.thinking.trim())
              .where((text) => text.isNotEmpty)
              .join('\n\n');
          if (thinking.isNotEmpty) {
            turn.workItems.add(
              AgentChatTurnItem.reasoning(
                thinking: thinking,
                messageIndex: index,
                timestamp: message.timestamp,
              ),
            );
          }
          if (message.text.trim().isNotEmpty) {
            turn.finalMessages.add(
              AgentChatIndexedMessage(message: message, index: index),
            );
          }
        }
        return;
      }
      if (message is ToolResultMessage) {
        final match = turn.workItems.lastWhere(
          (item) => item.call?.id == message.toolCallId && item.result == null,
          orElse: AgentChatTurnItem.new,
        );
        if (match.call != null) {
          match.result = message;
          match.completedTimestamp = message.timestamp;
        } else {
          turn.workItems.add(
            AgentChatTurnItem.toolResult(
              result: message,
              messageIndex: index,
              timestamp: message.timestamp,
            ),
          );
        }
      }
    }

    var messageIndex = 0;
    for (final timelineTurn in timeline) {
      final entryCount = timelineTurn.items
          .where((item) => item.kind != AgentChatTimelineItemKind.toolCall)
          .length;
      final requestedEnd = messageIndex + entryCount;
      final end = requestedEnd < messages.length
          ? requestedEnd
          : messages.length;
      int? userIndex;
      for (var index = messageIndex; index < end; index++) {
        if (isVisualUserMessage(messages[index])) {
          userIndex = index;
          break;
        }
      }
      final turn = AgentChatTurnModel(
        ordinal: turns.length,
        userMessage: userIndex == null ? null : messages[userIndex],
        userMessageIndex: userIndex ?? -1,
        timeline: timelineTurn,
      );
      for (var index = messageIndex; index < end; index++) {
        if (index != userIndex) addMessage(turn, messages[index], index);
      }
      turns.add(turn);
      messageIndex = end;
    }

    AgentChatTurnModel? legacyTurn;
    for (var index = messageIndex; index < messages.length; index++) {
      final message = messages[index];
      if (isVisualUserMessage(message)) {
        legacyTurn = AgentChatTurnModel(
          ordinal: turns.length,
          userMessage: message,
          userMessageIndex: index,
        );
        turns.add(legacyTurn);
        continue;
      }
      legacyTurn ??= AgentChatTurnModel(ordinal: turns.length);
      if (!turns.contains(legacyTurn)) turns.add(legacyTurn);
      addMessage(legacyTurn, message, index);
    }
    return AgentChatThreadModel(turns: turns);
  }

  final List<AgentChatTurnModel> turns;
}


class AgentChatTurnModel {
  AgentChatTurnModel({
    required this.ordinal,
    this.userMessage,
    this.userMessageIndex = -1,
    this.timeline,
  });

  final int ordinal;
  final Message? userMessage;
  final int userMessageIndex;
  final AgentChatTurnTimeline? timeline;
  final List<AgentChatTurnItem> workItems = [];
  final List<AgentChatIndexedMessage> finalMessages = [];

  List<ToolResultMessage> get mediaResults => [
    for (final item in workItems)
      if (item.result case final result?
          when agentToolDisplaysMedia(item.toolName))
        result,
  ];

  String get preview {
    final message = userMessage;
    if (message == null) return '';
    return visibleUserMessage(message)?.text.trim() ?? '';
  }
}

class AgentChatIndexedMessage {
  const AgentChatIndexedMessage({required this.message, required this.index});

  final Message message;
  final int index;
}

enum AgentChatTurnItemKind { reasoning, narration, tool }

class AgentChatTurnItem {
  AgentChatTurnItem()
    : kind = AgentChatTurnItemKind.tool,
      thinking = null,
      narration = null,
      call = null,
      result = null,
      messageIndex = -1,
      timestamp = null,
      completedTimestamp = null;

  AgentChatTurnItem.reasoning({
    required this.thinking,
    required this.messageIndex,
    required this.timestamp,
  }) : kind = AgentChatTurnItemKind.reasoning,
       narration = null,
       call = null,
       result = null,
       completedTimestamp = timestamp;

  AgentChatTurnItem.narration({
    required this.narration,
    required this.messageIndex,
    required this.timestamp,
  }) : kind = AgentChatTurnItemKind.narration,
       thinking = null,
       call = null,
       result = null,
       completedTimestamp = timestamp;

  AgentChatTurnItem.tool({
    required this.call,
    required this.messageIndex,
    required this.timestamp,
  }) : kind = AgentChatTurnItemKind.tool,
       thinking = null,
       narration = null,
       result = null,
       completedTimestamp = null;

  AgentChatTurnItem.toolResult({
    required this.result,
    required this.messageIndex,
    required this.timestamp,
  }) : kind = AgentChatTurnItemKind.tool,
       thinking = null,
       narration = null,
       call = null,
       completedTimestamp = timestamp;

  final AgentChatTurnItemKind kind;
  final String? thinking;
  final String? narration;
  final ToolCallContent? call;
  ToolResultMessage? result;
  final int messageIndex;
  final int? timestamp;
  int? completedTimestamp;

  bool get failed => result?.isError ?? false;
  bool get pending => kind == AgentChatTurnItemKind.tool && result == null;
  String get toolName => call?.name ?? result?.toolName ?? '';
}

class AgentChatWorkTrail extends StatefulWidget {
  const AgentChatWorkTrail({
    super.key,
    required this.turn,
    required this.running,
    required this.activities,
    this.streamingReasoning = '',
  });

  final AgentChatTurnModel turn;
  final bool running;
  final List<AgentToolActivity> activities;
  final String streamingReasoning;

  @override
  State<AgentChatWorkTrail> createState() => _AgentChatWorkTrailState();
}

class _AgentChatWorkTrailState extends State<AgentChatWorkTrail> {
  Timer? _elapsedTimer;
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'Agent work trail');
  late bool _expanded;
  bool _userOverrodeExpansion = false;
  bool _restoredExpansion = false;

  String get _storageIdentifier =>
      'agent-work-trail-${widget.turn.timeline?.id ?? widget.turn.ordinal}';

  bool _lifecycleExpanded(AgentChatWorkTrail value) =>
      value.running ||
      value.activities.any(
        (activity) => activity.status == AgentToolActivityStatus.running,
      ) ||
      value.turn.workItems.any((item) => item.pending);

  @override
  void initState() {
    super.initState();
    _expanded = _lifecycleExpanded(widget);
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredExpansion) return;
    _restoredExpansion = true;
    final stored = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _storageIdentifier);
    if (stored is bool) {
      _userOverrodeExpansion = true;
      _expanded = stored;
    }
  }

  @override
  void didUpdateWidget(covariant AgentChatWorkTrail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final turnChanged = oldWidget.turn.ordinal != widget.turn.ordinal;
    if (turnChanged) {
      _userOverrodeExpansion = false;
      _restoredExpansion = false;
      _expanded = _lifecycleExpanded(widget);
    } else if (!_userOverrodeExpansion &&
        _lifecycleExpanded(oldWidget) != _lifecycleExpanded(widget)) {
      _expanded = _lifecycleExpanded(widget);
    }
    _syncTimer();
  }

  void _toggleExpanded() {
    _shortcutFocus.requestFocus();
    setState(() {
      _userOverrodeExpansion = true;
      _expanded = !_expanded;
      PageStorage.maybeOf(
        context,
      )?.writeState(context, _expanded, identifier: _storageIdentifier);
    });
  }

  void _syncTimer() {
    _elapsedTimer?.cancel();
    if (widget.running && _validStartedAt != null) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  int? get _validStartedAt {
    final startedAt = widget.turn.timeline?.startedAt;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (startedAt == null || startedAt <= 0 || startedAt > now) return null;
    return startedAt;
  }

  Duration? get _duration {
    final startedAt = _validStartedAt;
    if (startedAt == null) return null;
    final endedAt = widget.running
        ? DateTime.now().millisecondsSinceEpoch
        : widget.turn.timeline?.completedAt;
    if (endedAt == null || endedAt < startedAt) return null;
    return Duration(milliseconds: endedAt - startedAt);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _shortcutFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCallIds = widget.activities
        .map((activity) => activity.toolCallId)
        .toSet();
    final workItems = widget.turn.workItems
        .where(
          (item) =>
              !activeCallIds.contains(item.call?.id ?? item.result?.toolCallId),
        )
        .toList(growable: false);
    final items = _groupItems(workItems);
    if (items.isEmpty &&
        widget.activities.isEmpty &&
        widget.streamingReasoning.isEmpty &&
        !widget.running &&
        widget.turn.timeline?.status != AgentChatTurnStatus.failed) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    // A recoverable tool failure belongs to that Item. The Turn itself only
    // becomes an error surface when the runtime reports a terminal Turn error.
    final failed = widget.turn.timeline?.status == AgentChatTurnStatus.failed;
    final duration = _duration;
    final title = widget.running
        ? _workingLabel(context, duration)
        : _workedLabel(context, duration);
    final workSurface = widget.running
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.48)
        : theme.colorScheme.secondaryContainer.withValues(alpha: 0.48);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            _toggleExpanded,
      },
      child: Focus(
        focusNode: _shortcutFocus,
        child: Container(
          key: ValueKey('agent-turn-work-${widget.turn.ordinal}'),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: failed
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.2)
                : workSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: _expanded,
                child: InkWell(
                  key: ValueKey(
                    'agent-turn-work-header-${widget.turn.ordinal}',
                  ),
                  onTap: _toggleExpanded,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        if (widget.running)
                          const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.7),
                          )
                        else
                          Icon(
                            failed
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: failed
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          context.l10n.agentChat_workItemCount(
                            items.length +
                                widget.activities.length +
                                (widget.streamingReasoning.isEmpty ? 0 : 1),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 8,
                        bottom: 8,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.turn.timeline?.error != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                                child: Text(
                                  context.l10n.common_error,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            for (final item in items)
                              _WorkItemGroupTile(
                                group: item,
                                live: widget.running,
                              ),
                            for (final activity in widget.activities)
                              AgentChatToolActivityTile(activity: activity),
                            if (widget.streamingReasoning.isNotEmpty)
                              AgentChatReasoningTile(
                                thinking: widget.streamingReasoning,
                                live: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _workingLabel(BuildContext context, Duration? duration) =>
      duration == null
      ? context.l10n.agentChat_working
      : context.l10n.agentChat_workingFor(_formatDuration(duration));

  String _workedLabel(BuildContext context, Duration? duration) =>
      duration == null
      ? context.l10n.agentChat_worked
      : context.l10n.agentChat_workedFor(_formatDuration(duration));
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds < 1) return '${duration.inMilliseconds}ms';
  if (duration.inMinutes < 1) return '${duration.inSeconds}s';
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inMinutes}m ${seconds}s';
}

enum _WorkGroupKind { single, commands, exploration }

class _WorkItemGroup {
  const _WorkItemGroup(this.kind, this.items);

  final _WorkGroupKind kind;
  final List<AgentChatTurnItem> items;
}

List<_WorkItemGroup> _groupItems(List<AgentChatTurnItem> source) {
  final groups = <_WorkItemGroup>[];
  for (var index = 0; index < source.length;) {
    final item = source[index];
    final kind = _groupKind(item);
    if (kind == _WorkGroupKind.single) {
      groups.add(_WorkItemGroup(kind, [item]));
      index++;
      continue;
    }
    final items = <AgentChatTurnItem>[item];
    index++;
    while (index < source.length && _groupKind(source[index]) == kind) {
      items.add(source[index]);
      index++;
    }
    groups.add(
      _WorkItemGroup(items.length > 1 ? kind : _WorkGroupKind.single, items),
    );
  }
  return groups;
}

_WorkGroupKind _groupKind(AgentChatTurnItem item) {
  if (item.kind != AgentChatTurnItemKind.tool || item.pending || item.failed) {
    return _WorkGroupKind.single;
  }
  final name = item.toolName.toLowerCase();
  if (name.contains('exec') ||
      name.contains('shell') ||
      name.contains('command') ||
      name == 'bash') {
    return _WorkGroupKind.commands;
  }
  if (name.contains('read') ||
      name.contains('list') ||
      name.contains('search') ||
      name.contains('find')) {
    return _WorkGroupKind.exploration;
  }
  return _WorkGroupKind.single;
}

class _WorkItemGroupTile extends StatefulWidget {
  const _WorkItemGroupTile({required this.group, required this.live});

  final _WorkItemGroup group;
  final bool live;

  @override
  State<_WorkItemGroupTile> createState() => _WorkItemGroupTileState();
}

class _WorkItemGroupTileState extends State<_WorkItemGroupTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _initiallyExpanded(widget.group);
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    if (group.items.length == 1) {
      final item = group.items.first;
      if (item.kind == AgentChatTurnItemKind.reasoning) {
        return AgentChatReasoningTile(
          thinking: item.thinking!,
          live: widget.live,
        );
      }
      if (item.kind == AgentChatTurnItemKind.narration) {
        return _AgentChatNarrationTile(text: item.narration!);
      }
    }
    final theme = Theme.of(context);
    final pending = group.items.any((item) => item.pending);
    final failed = group.items.any((item) => item.failed);
    final summary = _workGroupSummary(context, group);
    final title = switch (group.kind) {
      _WorkGroupKind.commands => context.l10n.agentChat_ranCommands(
        group.items.length,
      ),
      _WorkGroupKind.exploration => context.l10n.agentChat_exploredItems(
        group.items.length,
      ),
      _WorkGroupKind.single => agentToolLabel(
        context,
        group.items.first.toolName,
      ),
    };
    final toolIcon = switch (group.kind) {
      _WorkGroupKind.commands => Icons.terminal_rounded,
      _WorkGroupKind.exploration => Icons.manage_search_rounded,
      _WorkGroupKind.single => agentToolIcon(group.items.first.toolName),
    };
    final statusColor = failed
        ? theme.colorScheme.error
        : pending
        ? theme.colorScheme.primary
        : agentToolSuccessColor(theme);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: ValueKey(
                'agent-turn-tool-item-${group.items.first.call?.id ?? group.items.first.result?.toolCallId ?? group.items.first.messageIndex}',
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      toolIcon,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary.isEmpty ? title : '$title · $summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (!pending) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        label: failed
                            ? context.l10n.common_error
                            : context.l10n.common_success,
                        child: ExcludeSemantics(
                          child: Icon(
                            failed ? Icons.close_rounded : Icons.check_rounded,
                            key: ValueKey(
                              'agent-turn-tool-status-${group.items.first.call?.id ?? group.items.first.result?.toolCallId ?? group.items.first.messageIndex}',
                            ),
                            size: 16,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              for (final item in group.items) _WorkItemDetails(item: item),
          ],
        ),
        Positioned(
          left: -11,
          top: 16,
          child: IgnorePointer(
            child: Container(
              key: ValueKey(
                'agent-turn-tool-dot-${group.items.first.call?.id ?? group.items.first.result?.toolCallId ?? group.items.first.messageIndex}',
              ),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _initiallyExpanded(_WorkItemGroup _) {
  return false;
}

String _workGroupSummary(BuildContext context, _WorkItemGroup group) {
  if (group.items.any((item) => item.pending)) {
    return context.l10n.agentChat_toolRunning;
  }
  final result = group.items.last.result;
  if (result == null) return '';
  return agentToolResultSummary(context, result, fallback: '');
}

class _AgentChatNarrationTile extends StatelessWidget {
  const _AgentChatNarrationTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: SelectableText(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
    ),
  );
}

class _WorkItemDetails extends StatelessWidget {
  const _WorkItemDetails({required this.item});

  final AgentChatTurnItem item;

  @override
  Widget build(BuildContext context) {
    final call = item.call;
    final result = item.result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (call != null && call.arguments.isNotEmpty)
            _ToolArgumentsTile(
              key: ValueKey('agent-tool-args-${call.id}'),
              text: const JsonEncoder.withIndent('  ').convert(call.arguments),
            ),
          if (result != null) ...[
            AgentChatToolResultTile(
              key: ValueKey('agent-turn-tool-result-${result.toolCallId}'),
              result: result,
              showMedia: false,
              nested: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolArgumentsTile extends StatefulWidget {
  const _ToolArgumentsTile({super.key, required this.text});

  final String text;

  @override
  State<_ToolArgumentsTile> createState() => _ToolArgumentsTileState();
}

class _ToolArgumentsTileState extends State<_ToolArgumentsTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('agent-tool-arguments-toggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.generation_params,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 17,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) _TranscriptText(text: widget.text),
      ],
    );
  }
}

class _TranscriptText extends StatelessWidget {
  const _TranscriptText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        key: PageStorageKey('agent-transcript-${text.hashCode}'),
        child: SelectableText(
          text,
          key: PageStorageKey('agent-transcript-text-${text.hashCode}'),
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
