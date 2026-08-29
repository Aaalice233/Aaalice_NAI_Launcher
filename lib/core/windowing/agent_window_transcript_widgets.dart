import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../agent/agent_media_display_policy.dart';
import '../agent/agent_tool_presentation.dart';
import 'agent_chat_layout_contract.dart';
import 'agent_chat_shared_widgets.dart';
import 'agent_window_shell_widgets.dart';

typedef _AgentWindowMessageBuilder =
    Widget Function(
      Map<Object?, Object?> message, {
      required bool isLastAssistant,
    });

class AgentWindowMessageList extends StatefulWidget {
  const AgentWindowMessageList({
    required this.messages,
    required this.controller,
    required this.copyText,
    required this.retryLastMessage,
    required this.running,
    this.timeline = const [],
    this.activities = const [],
    this.history = const {},
    this.approvalPending = false,
    this.loadEarlierHistory,
    this.loadLatestHistory,
    super.key,
  });

  final List messages;
  final ScrollController controller;
  final ValueChanged<String> copyText;
  final VoidCallback retryLastMessage;
  final bool running;
  final List timeline;
  final List activities;
  final Map<Object?, Object?> history;
  final bool approvalPending;
  final Future<void> Function()? loadEarlierHistory;
  final Future<void> Function()? loadLatestHistory;

  @override
  State<AgentWindowMessageList> createState() => _AgentWindowMessageListState();
}

class _AgentWindowMessageListState extends State<AgentWindowMessageList> {
  bool _followLatest = true;
  String _lastSignature = '';
  int _visibleTurnCount = 6;
  bool _loadingEarlier = false;
  int _lastTimelineLength = 0;
  String _lastTimelineSignature = '';
  final Map<String, GlobalKey> _turnKeys = {};
  String? _pendingAnchorTurnId;
  double? _pendingAnchorDy;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollChanged);
    _lastSignature = widget.messages.isEmpty
        ? ''
        : '${widget.messages.length}:${widget.messages.last.hashCode}';
    _lastTimelineLength = widget.timeline.length;
    _lastTimelineSignature = _timelineSignature(widget.timeline);
    if (widget.messages.isNotEmpty) {
      _scheduleInitialScroll();
    }
  }

  @override
  void didUpdateWidget(covariant AgentWindowMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scrollChanged);
      widget.controller.addListener(_scrollChanged);
    }
    final signature = widget.messages.isEmpty
        ? ''
        : '${widget.messages.length}:${widget.messages.last.hashCode}';
    if (signature != _lastSignature) {
      _lastSignature = signature;
      if (_followLatest) {
        _scheduleInitialScroll();
      }
    }
    final timelineSignature = _timelineSignature(widget.timeline);
    if (timelineSignature != _lastTimelineSignature) {
      if (widget.timeline.length > _lastTimelineLength && _loadingEarlier) {
        final beforeOffset = widget.controller.hasClients
            ? widget.controller.offset
            : null;
        final beforeExtent = widget.controller.hasClients
            ? widget.controller.position.maxScrollExtent
            : null;
        _visibleTurnCount = math.min(
          widget.timeline.length,
          _visibleTurnCount +
              math.min(8, widget.timeline.length - _lastTimelineLength),
        );
        if (_pendingAnchorTurnId != null && _pendingAnchorDy != null) {
          _restoreTurnAnchor(_pendingAnchorTurnId!, _pendingAnchorDy!);
          _pendingAnchorTurnId = null;
          _pendingAnchorDy = null;
        } else {
          _preservePrependAnchor(beforeOffset, beforeExtent);
        }
      } else if (_loadingEarlier &&
          _pendingAnchorTurnId != null &&
          _pendingAnchorDy != null) {
        _restoreTurnAnchor(_pendingAnchorTurnId!, _pendingAnchorDy!);
        _pendingAnchorTurnId = null;
        _pendingAnchorDy = null;
      }
      _lastTimelineLength = widget.timeline.length;
      _lastTimelineSignature = timelineSignature;
      _loadingEarlier = false;
    }
  }

  String _timelineSignature(List timeline) {
    if (timeline.isEmpty) return '0';
    final first = timeline.first is Map
        ? (timeline.first as Map)['id']?.toString()
        : null;
    final last = timeline.last is Map
        ? (timeline.last as Map)['id']?.toString()
        : null;
    return '${timeline.length}:$first:$last';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollChanged);
    super.dispose();
  }

  void _scrollChanged() {
    if (!widget.controller.hasClients) return;
    final next =
        widget.controller.position.maxScrollExtent - widget.controller.offset <
        96;
    if (next != _followLatest && mounted) setState(() => _followLatest = next);
  }

  void _scheduleInitialScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToLatest(animate: false);
      // Parent status/composer surfaces can settle one frame after the
      // transcript. Follow their final viewport instead of leaving the latest
      // message just outside the lazily-built range.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _followLatest) _scrollToLatest(animate: false);
      });
    });
  }

  void _scrollToLatest({bool animate = true}) {
    if (!mounted || !widget.controller.hasClients) return;
    final target = widget.controller.position.maxScrollExtent;
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      widget.controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.controller.jumpTo(target);
    }
    if (!_followLatest) setState(() => _followLatest = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.messages.isEmpty) {
      final theme = Theme.of(context);
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 21,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.agentChat_heroTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.agentChat_heroSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (widget.timeline.isNotEmpty) return _buildThread(context);
    final items = _groupMessages(widget.messages);
    final lastAssistantItemIndex = items.lastIndexWhere(
      (item) =>
          item is Map<Object?, Object?> &&
          item['role'] == 'assistant' &&
          (item['text']?.toString().trim().isNotEmpty ?? false),
    );
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => ListView.builder(
            controller: widget.controller,
            padding: EdgeInsets.fromLTRB(
              AgentChatLayoutContract.transcriptHorizontalPadding(
                constraints.maxWidth,
              ),
              16,
              AgentChatLayoutContract.transcriptHorizontalPadding(
                constraints.maxWidth,
              ),
              24,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AgentChatLayoutContract.transcriptMaxWidth(
                    constraints.maxWidth,
                  ),
                ),
                child: _buildItem(
                  context,
                  items[index],
                  isLastAssistant: index == lastAssistantItemIndex,
                ),
              ),
            ),
          ),
        ),
        if (!_followLatest || widget.history['hasNewer'] == true)
          Positioned(
            right: 16,
            bottom: 12,
            child: FilledButton.tonalIcon(
              onPressed: _jumpToLatest,
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: Text(l10n.agentChat_jumpToLatest),
            ),
          ),
      ],
    );
  }

  Future<void> _jumpToTurn(
    _AgentWindowTurnModel turn,
    List<_AgentWindowTurnModel> turns,
  ) async {
    final turnContext = _turnKeys[turn.id]?.currentContext;
    if (turnContext != null) {
      await Scrollable.ensureVisible(
        turnContext,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
      return;
    }
    final index = turns.indexOf(turn);
    if (index < 0 || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    final fraction = turns.length <= 1 ? 0.0 : index / (turns.length - 1);
    await widget.controller.animateTo(
      position.maxScrollExtent * fraction,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _turnKeys[turn.id]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context, alignment: 0.18);
      }
    });
  }

  Widget _buildThread(BuildContext context) {
    final turns = _projectTurns(
      widget.messages,
      widget.timeline,
      widget.activities,
    );
    final visibleCount = math.min(_visibleTurnCount, turns.length);
    final visibleStart = turns.length - visibleCount;
    final hiddenCount = visibleStart;
    final hasEarlier = widget.history['hasEarlier'] == true;
    final showEarlier = hiddenCount > 0 || hasEarlier;
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final showRail = turns.length > 1;
            final gutterWidth = constraints.maxWidth >= 760 ? 40.0 : 32.0;
            final horizontalPadding =
                AgentChatLayoutContract.transcriptHorizontalPadding(
                  constraints.maxWidth,
                );
            return ListView.builder(
              controller: widget.controller,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24,
              ),
              itemCount: visibleCount + (showEarlier ? 1 : 0),
              itemBuilder: (context, index) {
                if (showEarlier && index == 0) {
                  return Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: AgentChatLayoutContract.transcriptMaxWidth(
                          constraints.maxWidth,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: showRail ? gutterWidth + 8 : 0,
                          bottom: 10,
                        ),
                        child: TextButton.icon(
                          key: const ValueKey('agent-window-earlier-messages'),
                          onPressed: _loadingEarlier ? null : _showEarlierTurns,
                          icon: _loadingEarlier
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.7,
                                  ),
                                )
                              : const Icon(Icons.history_rounded, size: 17),
                          label: Text(
                            hiddenCount > 0
                                ? l10n.agentChat_earlierMessages(hiddenCount)
                                : l10n.agentChat_loadEarlierMessages,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final turnIndex = visibleStart + index - (showEarlier ? 1 : 0);
                final turn = turns[turnIndex];
                final turnContent = _AgentWindowTurn(
                  key: _turnKeys.putIfAbsent(turn.id, GlobalKey.new),
                  turn: turn,
                  copyText: widget.copyText,
                  retry: widget.retryLastMessage,
                  retryEnabled: !widget.running,
                  latest: turnIndex == turns.length - 1,
                  approvalPending:
                      widget.approvalPending && turnIndex == turns.length - 1,
                  buildMessage: (message, {required isLastAssistant}) =>
                      _buildItem(
                        context,
                        message,
                        isLastAssistant: isLastAssistant,
                      ),
                );
                return Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AgentChatLayoutContract.transcriptMaxWidth(
                        constraints.maxWidth,
                      ),
                    ),
                    child: showRail
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: gutterWidth,
                                child: _AgentWindowTurnRailCell(
                                  turn: turn,
                                  ordinal: turnIndex + 1,
                                  latest: turnIndex == turns.length - 1,
                                  hasPrevious: turnIndex > visibleStart,
                                  hasNext: turnIndex < turns.length - 1,
                                  onSelected: () => _jumpToTurn(turn, turns),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: turnContent),
                            ],
                          )
                        : turnContent,
                  ),
                );
              },
            );
          },
        ),
        if (!_followLatest)
          Positioned(
            right: 16,
            bottom: 12,
            child: FilledButton.tonalIcon(
              onPressed: _scrollToLatest,
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: Text(l10n.agentChat_jumpToLatest),
            ),
          ),
      ],
    );
  }

  Future<void> _showEarlierTurns() async {
    final hidden = widget.timeline.length - _visibleTurnCount;
    final scroll = widget.controller;
    final beforeOffset = scroll.hasClients ? scroll.offset : null;
    final beforeExtent = scroll.hasClients
        ? scroll.position.maxScrollExtent
        : null;
    if (hidden > 0) {
      final anchorIndex = widget.timeline.length - _visibleTurnCount;
      final anchorTurnId = widget.timeline[anchorIndex] is Map
          ? (widget.timeline[anchorIndex] as Map)['id']?.toString()
          : null;
      final anchorDy = anchorTurnId == null ? null : _turnDy(anchorTurnId);
      setState(() {
        _visibleTurnCount = math.min(
          widget.timeline.length,
          _visibleTurnCount + 8,
        );
      });
      if (anchorTurnId != null && anchorDy != null) {
        _restoreTurnAnchor(anchorTurnId, anchorDy);
      } else {
        _preservePrependAnchor(beforeOffset, beforeExtent);
      }
      return;
    }
    if (widget.history['hasEarlier'] != true ||
        widget.loadEarlierHistory == null) {
      return;
    }
    final firstVisibleIndex = math.max(
      0,
      widget.timeline.length - _visibleTurnCount,
    );
    final firstVisible = widget.timeline[firstVisibleIndex];
    if (firstVisible is Map) {
      _pendingAnchorTurnId = firstVisible['id']?.toString();
      if (_pendingAnchorTurnId case final id?) _pendingAnchorDy = _turnDy(id);
    }
    setState(() => _loadingEarlier = true);
    try {
      await widget.loadEarlierHistory!.call();
    } catch (_) {
      if (mounted) setState(() => _loadingEarlier = false);
      rethrow;
    }
  }

  Future<void> _jumpToLatest() async {
    if (widget.history['hasNewer'] == true) {
      await widget.loadLatestHistory?.call();
    }
    if (mounted) _scrollToLatest();
  }

  double? _turnDy(String turnId) {
    final context = _turnKeys[turnId]?.currentContext;
    final box = context?.findRenderObject();
    return box is RenderBox ? box.localToGlobal(Offset.zero).dy : null;
  }

  void _restoreTurnAnchor(String turnId, double beforeDy) {
    void restore(int remainingFrames) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.controller.hasClients) return;
        final afterDy = _turnDy(turnId);
        if (afterDy != null) {
          final position = widget.controller.position;
          widget.controller.jumpTo(
            (widget.controller.offset + afterDy - beforeDy).clamp(
              0,
              position.maxScrollExtent,
            ),
          );
        }
        if (remainingFrames > 1) restore(remainingFrames - 1);
      });
    }

    restore(2);
  }

  void _preservePrependAnchor(double? beforeOffset, double? beforeExtent) {
    if (beforeOffset == null || beforeExtent == null) return;
    void restore(int remainingFrames) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.controller.hasClients) return;
        final position = widget.controller.position;
        final addedExtent = position.maxScrollExtent - beforeExtent;
        widget.controller.jumpTo(
          (beforeOffset + addedExtent).clamp(0, position.maxScrollExtent),
        );
        if (remainingFrames > 1) restore(remainingFrames - 1);
      });
    }

    // Variable-height turns can update the sliver estimate for another frame.
    restore(2);
  }

  List<Object> _groupMessages(List messages) {
    final items = <Object>[];
    var index = 0;
    while (index < messages.length) {
      final message = Map<Object?, Object?>.from(messages[index] as Map);
      if (_isInvisibleToolAssistant(message) &&
          index + 1 < messages.length &&
          (messages[index + 1] as Map)['role'] == 'tool') {
        index++;
        continue;
      }
      if (message['role'] == 'tool') {
        final group = <Map<Object?, Object?>>[];
        while (index < messages.length) {
          final current = Map<Object?, Object?>.from(messages[index] as Map);
          if (current['role'] == 'tool') {
            group.add(current);
            index++;
            continue;
          }
          if (_isInvisibleToolAssistant(current) &&
              index + 1 < messages.length &&
              (messages[index + 1] as Map)['role'] == 'tool') {
            index++;
            continue;
          }
          break;
        }
        items.add(group);
      } else {
        items.add(message);
        index++;
      }
    }
    return items;
  }

  bool _isInvisibleToolAssistant(Map<Object?, Object?> message) =>
      message['role'] == 'assistant' &&
      (message['text']?.toString().trim().isEmpty ?? true) &&
      (message['thinking']?.toString().trim().isEmpty ?? true) &&
      message['stopReason'] == 'toolUse';

  Widget _buildItem(
    BuildContext context,
    Object item, {
    required bool isLastAssistant,
  }) {
    if (item is List<Map<Object?, Object?>>) {
      if (item.length == 1) {
        return _AgentWindowToolResult(
          result: item.single,
          copyText: widget.copyText,
          retry: widget.retryLastMessage,
          retryEnabled: !widget.running,
          showRetry: true,
        );
      }
      return _AgentWindowToolGroup(
        results: item,
        copyText: widget.copyText,
        retry: widget.retryLastMessage,
        retryEnabled: !widget.running,
      );
    }
    final message = item as Map<Object?, Object?>;
    final role = message['role'];
    final text = message['text'] as String? ?? '';
    if (role == 'user') {
      final images = message['images'] is List
          ? message['images'] as List
          : const [];
      final sentAt = _messageTime(context, message['timestamp']);
      return LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                key: ValueKey('agent-window-user-bubble-${text.hashCode}'),
                constraints: BoxConstraints(
                  minWidth: text.isEmpty ? 0 : 44,
                  maxWidth: AgentChatLayoutContract.userBubbleMaxWidth(
                    constraints.maxWidth,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.58),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (text.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectionArea(child: Text(text)),
                      ),
                    for (final image in images)
                      if (image is Map) _AgentWindowImageCard(image: image),
                    if (sentAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sentAt,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(fontSize: 9),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.done_all_rounded, size: 11),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _copyButton(context, text),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
    final thinking = message['thinking'] as String? ?? '';
    final sentAt = _messageTime(context, message['timestamp']);
    final live = message['live'] == true;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AgentChatLayoutContract.assistantMaxWidth(
              constraints.maxWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        'AI',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (constraints.maxWidth >= 420) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(
                            context,
                          )!.settings_promptAssistant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    if (live) ...[
                      const SizedBox(width: 8),
                      const SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                if (thinking.trim().isNotEmpty)
                  _AgentWindowReasoning(thinking: thinking),
                if (text.trim().isNotEmpty)
                  AgentChatMarkdownContent(
                    text: text,
                    touchOptimized: constraints.maxWidth < 600,
                    imageBuilder: (uri, _, alt) =>
                        AgentChatMarkdownImage(uri: uri, alt: alt),
                  ),
                if (sentAt.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    sentAt,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (text.trim().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _copyButton(context, text),
                      if (isLastAssistant && !widget.running)
                        IconButton(
                          key: const ValueKey(
                            'agent-window-retry-last-message',
                          ),
                          tooltip: AppLocalizations.of(context)!.common_retry,
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.retryLastMessage,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _copyButton(BuildContext context, String text) => IconButton(
    tooltip: AppLocalizations.of(context)!.common_copy,
    visualDensity: VisualDensity.compact,
    onPressed: () => widget.copyText(text),
    icon: const Icon(Icons.copy_all_outlined, size: 15),
  );

  String _messageTime(BuildContext context, Object? value) {
    final timestamp = value is num ? value.toInt() : null;
    if (timestamp == null || timestamp <= 0) return '';
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp)),
      alwaysUse24HourFormat: true,
    );
  }
}

class _AgentWindowTurnModel {
  _AgentWindowTurnModel(this.timeline)
    : id = timeline['id']?.toString() ?? 'legacy',
      status = timeline['status']?.toString() ?? 'completed';

  final Map<Object?, Object?> timeline;
  final String id;
  final String status;
  final List<Map<Object?, Object?>> users = [];
  final List<Map<Object?, Object?>> work = [];
  final List<Map<Object?, Object?>> media = [];
  final List<Map<Object?, Object?>> finals = [];
}

class _AgentWindowTurnRailCell extends StatelessWidget {
  const _AgentWindowTurnRailCell({
    required this.turn,
    required this.ordinal,
    required this.latest,
    required this.hasPrevious,
    required this.hasNext,
    required this.onSelected,
  });

  final _AgentWindowTurnModel turn;
  final int ordinal;
  final bool latest;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
    return Tooltip(
      message: AppLocalizations.of(
        context,
      )!.agentChat_turnNavigation(ordinal, _windowTurnPreview(turn)),
      child: Semantics(
        button: true,
        child: InkResponse(
          key: ValueKey('agent-window-turn-gutter-${turn.id}'),
          onTap: onSelected,
          radius: 18,
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (hasPrevious)
                  Positioned(
                    top: 0,
                    width: 1,
                    height: 14,
                    child: ColoredBox(color: trackColor),
                  ),
                if (hasNext)
                  Positioned(
                    top: 22,
                    bottom: 0,
                    width: 1,
                    child: ColoredBox(color: trackColor),
                  ),
                Positioned(
                  top: 12,
                  child: Container(
                    width: latest ? 10 : 8,
                    height: latest ? 10 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: latest
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: latest
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _windowTurnPreview(_AgentWindowTurnModel turn) {
  final text = turn.users
      .map((message) => message['text']?.toString().trim() ?? '')
      .firstWhere((value) => value.isNotEmpty, orElse: () => '…');
  return text.length <= 36 ? text : '${text.substring(0, 36)}…';
}

List<_AgentWindowTurnModel> _projectTurns(
  List messages,
  List timeline,
  List activities,
) {
  final turnTimelines = <String, Map<Object?, Object?>>{};
  for (final value in timeline) {
    if (value is! Map) continue;
    final projected = Map<Object?, Object?>.from(value);
    final id = projected['id']?.toString() ?? 'legacy';
    // Snapshot retries may repeat a turn. Keep the latest lifecycle record so
    // one logical turn can never render two competing work trails.
    turnTimelines[id] = projected;
  }
  final turns = [
    for (final timeline in turnTimelines.values)
      _AgentWindowTurnModel(timeline),
  ];
  final byId = {for (final turn in turns) turn.id: turn};
  final calls = <String, Map<Object?, Object?>>{};
  final results = <String>{};

  for (final value in messages) {
    if (value is! Map) continue;
    final message = Map<Object?, Object?>.from(value);
    var turn = byId[message['turnId']?.toString()];
    if (turn == null && message['live'] == true && turns.isNotEmpty) {
      turn = turns.last;
    }
    if (turn == null) continue;
    switch (message['role']) {
      case 'user':
        turn.users.add(message);
      case 'assistant':
        final toolCalls = message['toolCalls'] is List
            ? message['toolCalls'] as List
            : const [];
        final toolUse =
            toolCalls.isNotEmpty || message['stopReason'] == 'toolUse';
        final thinking = message['thinking']?.toString().trim() ?? '';
        final text = message['text']?.toString().trim() ?? '';
        if (thinking.isNotEmpty) {
          turn.work.add({'kind': 'reasoning', 'text': thinking});
        }
        if (toolUse && text.isNotEmpty) {
          turn.work.add({'kind': 'narration', 'text': text});
        }
        for (final value in toolCalls) {
          if (value is! Map) continue;
          final call = Map<Object?, Object?>.from(value);
          final callId = call['id']?.toString() ?? '';
          final item = <Object?, Object?>{
            'kind': 'tool',
            'toolCallId': callId,
            'toolName': call['name'],
            'args': call['args'],
            'status': 'pending',
          };
          turn.work.add(item);
          if (callId.isNotEmpty) calls[callId] = item;
        }
        if (!toolUse && text.isNotEmpty) {
          turn.finals.add({...message, 'thinking': ''});
        }
      case 'tool':
        final callId = message['toolCallId']?.toString() ?? '';
        if (agentWindowShouldProjectToolMedia(message) &&
            message['images'] is List &&
            (message['images'] as List).isNotEmpty) {
          turn.media.add(message);
        }
        if (callId.isNotEmpty) results.add(callId);
        final call = calls[callId];
        if (call != null) {
          call['result'] = message;
          call['status'] = message['isError'] == true ? 'failed' : 'completed';
        } else {
          turn.work.add({
            'kind': 'tool',
            'toolCallId': callId,
            'toolName': message['toolName'],
            'status': message['isError'] == true ? 'failed' : 'completed',
            'result': message,
          });
        }
    }
  }

  for (final value in activities) {
    if (value is! Map) continue;
    final activity = Map<Object?, Object?>.from(value);
    final callId = activity['toolCallId']?.toString() ?? '';
    if (results.contains(callId)) continue;
    final activityTurnId = activity['turnId']?.toString();
    var turn = byId[activityTurnId];
    if (turn == null && activityTurnId == null) {
      turn = turns.isEmpty ? null : turns.last;
    }
    if (turn == null) continue;
    final call = calls[callId];
    if (call != null) {
      call['activity'] = activity;
      call['status'] = activity['status'];
    } else {
      turn.work.add({
        'kind': 'tool',
        'toolCallId': callId,
        'toolName': activity['toolName'],
        'status': activity['status'],
        'activity': activity,
      });
    }
  }
  return turns;
}

@visibleForTesting
bool agentWindowShouldProjectToolMedia(Map<Object?, Object?> message) =>
    agentToolDisplaysMedia(message['toolName']?.toString() ?? '');

class _AgentWindowTurn extends StatelessWidget {
  const _AgentWindowTurn({
    required this.turn,
    required this.copyText,
    required this.retry,
    required this.retryEnabled,
    required this.latest,
    required this.approvalPending,
    required this.buildMessage,
    super.key,
  });

  final _AgentWindowTurnModel turn;
  final ValueChanged<String> copyText;
  final VoidCallback retry;
  final bool retryEnabled;
  final bool latest;
  final bool approvalPending;
  final _AgentWindowMessageBuilder buildMessage;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final user in turn.users) buildMessage(user, isLastAssistant: false),
      _AgentWindowWorkTrail(
        turn: turn,
        copyText: copyText,
        retry: retry,
        retryEnabled: retryEnabled,
        approvalPending: approvalPending,
      ),
      for (final result in turn.media) _AgentWindowToolMedia(result: result),
      for (var index = 0; index < turn.finals.length; index++)
        buildMessage(
          turn.finals[index],
          isLastAssistant: latest && index == turn.finals.length - 1,
        ),
    ],
  );
}

class _AgentWindowWorkTrail extends StatefulWidget {
  const _AgentWindowWorkTrail({
    required this.turn,
    required this.copyText,
    required this.retry,
    required this.retryEnabled,
    required this.approvalPending,
  });

  final _AgentWindowTurnModel turn;
  final ValueChanged<String> copyText;
  final VoidCallback retry;
  final bool retryEnabled;
  final bool approvalPending;

  @override
  State<_AgentWindowWorkTrail> createState() => _AgentWindowWorkTrailState();
}

class _AgentWindowWorkTrailState extends State<_AgentWindowWorkTrail> {
  Timer? _timer;
  late bool _expanded;
  bool? _manualExpanded;

  bool get _running => widget.turn.status == 'running';
  bool get _failed =>
      widget.turn.status == 'failed' ||
      widget.turn.work.any((item) => item['status'] == 'failed');
  bool get _pending => widget.turn.work.any(
    (item) =>
        item['status'] == 'running' ||
        item['status'] == 'pending' ||
        item['status'] == 'awaitingApproval',
  );
  bool get _mustStayExpanded => _running || _pending || widget.approvalPending;

  bool _mustStayExpandedFor(_AgentWindowWorkTrail value) =>
      value.turn.status == 'running' ||
      value.turn.work.any(
        (item) =>
            item['status'] == 'running' ||
            item['status'] == 'pending' ||
            item['status'] == 'awaitingApproval',
      ) ||
      value.approvalPending;

  @override
  void initState() {
    super.initState();
    _expanded = _mustStayExpanded;
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _AgentWindowWorkTrail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_manualExpanded case final expanded?) {
      _expanded = expanded;
    } else if (_mustStayExpanded) {
      _expanded = true;
    } else if (_mustStayExpandedFor(oldWidget)) {
      _expanded = false;
    }
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (_running && _startedAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  int? get _startedAt {
    final value = widget.turn.timeline['startedAt'];
    final now = DateTime.now().millisecondsSinceEpoch;
    return value is int && value > 0 && value <= now ? value : null;
  }

  Duration? get _duration {
    if (widget.turn.timeline['durationMs'] case final int duration
        when duration >= 0) {
      return Duration(milliseconds: duration);
    }
    final startedAt = _startedAt;
    if (startedAt == null) return null;
    final completedAt = _running
        ? DateTime.now().millisecondsSinceEpoch
        : widget.turn.timeline['completedAt'];
    if (completedAt is! int || completedAt < startedAt) return null;
    return Duration(milliseconds: completedAt - startedAt);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.turn.work.isEmpty &&
        !_running &&
        !_failed &&
        !widget.approvalPending) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final duration = _duration;
    final durationText = duration == null ? null : _formatDuration(duration);
    final l10n = AppLocalizations.of(context)!;
    final title = _running
        ? durationText == null
              ? l10n.agentChat_working
              : l10n.agentChat_workingFor(durationText)
        : durationText == null
        ? l10n.agentChat_worked
        : l10n.agentChat_workedFor(durationText);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: ValueKey('agent-window-turn-work-${widget.turn.id}'),
        color: _failed
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _expanded,
              child: InkWell(
                key: ValueKey(
                  'agent-window-turn-work-header-${widget.turn.id}',
                ),
                onTap: () => setState(() {
                  _expanded = !_expanded;
                  _manualExpanded = _expanded;
                }),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      if (_running)
                        const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.7),
                        )
                      else
                        Icon(
                          _failed
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: _failed
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.turn.timeline['error']
                            case final String error
                            when error.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                            child: Text(
                              error,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        for (final group in _groupWindowWorkItems(
                          widget.turn.work,
                        ))
                          _buildWorkGroup(context, group),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkItem(BuildContext context, Map<Object?, Object?> item) {
    if (item['kind'] == 'reasoning') {
      return _AgentWindowReasoning(
        thinking: item['text']?.toString() ?? '',
        live: _running,
      );
    }
    if (item['kind'] == 'narration') {
      return _AgentWindowNarration(text: item['text']?.toString() ?? '');
    }
    if (item['activity'] case final Map activity) {
      return AgentWindowToolActivityTile(
        activity: activity,
        copyText: widget.copyText,
      );
    }
    final result = item['result'] is Map
        ? Map<Object?, Object?>.from(item['result'] as Map)
        : <Object?, Object?>{
            'toolCallId': item['toolCallId'],
            'toolName': item['toolName'],
            'text': '',
            'details': item['args'],
            'pending': true,
          };
    if (item['args'] != null) {
      result['details'] = {
        'arguments': item['args'],
        if (result['details'] != null) 'result': result['details'],
      };
    }
    return _AgentWindowToolResult(
      result: result,
      copyText: widget.copyText,
      retry: widget.retry,
      retryEnabled: widget.retryEnabled,
      showRetry: result['isError'] == true,
      showMedia: false,
    );
  }

  Widget _buildWorkGroup(BuildContext context, _AgentWindowWorkGroup group) {
    if (group.items.length == 1) {
      return _buildWorkItem(context, group.items.single);
    }
    final l10n = AppLocalizations.of(context)!;
    final title = switch (group.kind) {
      _AgentWindowWorkGroupKind.commands => l10n.agentChat_ranCommands(
        group.items.length,
      ),
      _AgentWindowWorkGroupKind.exploration => l10n.agentChat_exploredItems(
        group.items.length,
      ),
      _AgentWindowWorkGroupKind.single => '',
    };
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(
          'agent-window-work-group-${widget.turn.id}-${group.items.first['toolCallId']}',
        ),
        minTileHeight: 34,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.only(left: 18),
        leading: const Icon(Icons.check_rounded, size: 16),
        title: Text(title, style: Theme.of(context).textTheme.bodySmall),
        children: [
          for (final item in group.items) _buildWorkItem(context, item),
        ],
      ),
    );
  }
}

class _AgentWindowNarration extends StatelessWidget {
  const _AgentWindowNarration({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: SelectableText(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
    ),
  );
}

enum _AgentWindowWorkGroupKind { single, commands, exploration }

class _AgentWindowWorkGroup {
  const _AgentWindowWorkGroup(this.kind, this.items);

  final _AgentWindowWorkGroupKind kind;
  final List<Map<Object?, Object?>> items;
}

List<_AgentWindowWorkGroup> _groupWindowWorkItems(
  List<Map<Object?, Object?>> source,
) {
  final groups = <_AgentWindowWorkGroup>[];
  for (var index = 0; index < source.length;) {
    final item = source[index];
    final kind = _windowWorkGroupKind(item);
    if (kind == _AgentWindowWorkGroupKind.single) {
      groups.add(_AgentWindowWorkGroup(kind, [item]));
      index++;
      continue;
    }
    final items = <Map<Object?, Object?>>[item];
    index++;
    while (index < source.length &&
        _windowWorkGroupKind(source[index]) == kind) {
      items.add(source[index++]);
    }
    groups.add(
      _AgentWindowWorkGroup(
        items.length > 1 ? kind : _AgentWindowWorkGroupKind.single,
        items,
      ),
    );
  }
  return groups;
}

_AgentWindowWorkGroupKind _windowWorkGroupKind(Map<Object?, Object?> item) {
  if (item['kind'] != 'tool' || item['status'] != 'completed') {
    return _AgentWindowWorkGroupKind.single;
  }
  final name = item['toolName']?.toString().toLowerCase() ?? '';
  if (name.contains('exec') ||
      name.contains('shell') ||
      name.contains('command') ||
      name == 'bash') {
    return _AgentWindowWorkGroupKind.commands;
  }
  if (name.contains('read') ||
      name.contains('list') ||
      name.contains('search') ||
      name.contains('find')) {
    return _AgentWindowWorkGroupKind.exploration;
  }
  return _AgentWindowWorkGroupKind.single;
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds < 1) return '${duration.inMilliseconds}ms';
  if (duration.inMinutes < 1) return '${duration.inSeconds}s';
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inMinutes}m ${seconds}s';
}

String _windowToolSummary(
  BuildContext context,
  String raw, {
  required String fallback,
  required bool failed,
}) {
  if (!failed) return AgentToolPresentation.summary(raw, fallback: fallback);
  final status = RegExp(
    r'(?:http|status(?:\s+code)?)\D{0,12}([45]\d\d)',
    caseSensitive: false,
  ).firstMatch(raw)?.group(1);
  final error = AppLocalizations.of(context)!.common_error;
  return status == null ? error : '$error · HTTP $status';
}

String _windowToolLabel(String name) {
  final words = name
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (words.isEmpty) return name;
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

class _AgentWindowReasoning extends StatelessWidget {
  const _AgentWindowReasoning({required this.thinking, this.live = false});

  final String thinking;
  final bool live;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: PageStorageKey('agent-window-reasoning-${thinking.hashCode}-$live'),
      initiallyExpanded: live,
      minTileHeight: 34,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(
        Icons.psychology_alt_outlined,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        AppLocalizations.of(context)!.agentChat_reasoning,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            thinking,
            key: PageStorageKey(
              'agent-window-reasoning-text-${thinking.hashCode}-$live',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AgentWindowToolGroup extends StatelessWidget {
  const _AgentWindowToolGroup({
    required this.results,
    required this.copyText,
    required this.retry,
    required this.retryEnabled,
  });

  final List<Map<Object?, Object?>> results;
  final ValueChanged<String> copyText;
  final VoidCallback retry;
  final bool retryEnabled;

  @override
  Widget build(BuildContext context) {
    final hasError = results.any((result) => result['isError'] == true);
    String? failureSummary;
    for (final result in results) {
      if (result['isError'] == true) {
        failureSummary = _windowToolSummary(
          context,
          result['text']?.toString() ?? '',
          fallback: AppLocalizations.of(context)!.common_error,
          failed: true,
        );
        break;
      }
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: hasError
            ? Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey(
            'agent-window-tool-group-${results.first['toolCallId'] ?? results.length}',
          ),
          initiallyExpanded: false,
          minTileHeight: 38,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          leading: Icon(
            hasError ? Icons.error_outline : Icons.terminal_rounded,
            size: 17,
            color: hasError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            AppLocalizations.of(
              context,
            )!.agentChat_toolGroupCount(results.length),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          subtitle: failureSummary == null
              ? null
              : Text(
                  '${AppLocalizations.of(context)!.common_error} · $failureSummary',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
          children: [
            for (final result in results)
              _AgentWindowToolResult(
                result: result,
                copyText: copyText,
                retry: retry,
                retryEnabled: retryEnabled,
                showRetry: false,
              ),
            if (hasError)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('agent-window-tool-group-retry'),
                  onPressed: retryEnabled ? retry : null,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(AppLocalizations.of(context)!.common_retry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgentWindowToolResult extends StatelessWidget {
  const _AgentWindowToolResult({
    required this.result,
    required this.copyText,
    required this.retry,
    required this.retryEnabled,
    required this.showRetry,
    this.showMedia = true,
  });

  final Map<Object?, Object?> result;
  final ValueChanged<String> copyText;
  final VoidCallback retry;
  final bool retryEnabled;
  final bool showRetry;
  final bool showMedia;

  @override
  Widget build(BuildContext context) {
    final images = result['images'] is List
        ? result['images'] as List
        : const [];
    final text = result['text'] as String? ?? '';
    final toolName = result['toolName']?.toString() ?? '';
    final failed = result['isError'] == true;
    final pending = result['pending'] == true;
    final summary = _windowToolSummary(
      context,
      text,
      fallback: toolName,
      failed: failed,
    );
    final detailSections = <String>[
      AgentToolPresentation.formattedDetails(text),
      if (result['details'] != null)
        AgentToolPresentation.formattedValue(result['details']),
    ].where((value) => value.isNotEmpty).toSet();
    final details = detailSections.join('\n\n');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          key: ValueKey(
            'agent-window-tool-${result['toolCallId'] ?? toolName}',
          ),
          color: failed
              ? Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.22)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey(
              'agent-window-tool-expansion-${result['toolCallId'] ?? toolName}-$pending-$failed',
            ),
            initiallyExpanded: false,
            minTileHeight: 38,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.fromLTRB(32, 0, 10, 8),
            leading: Icon(
              failed
                  ? Icons.error_outline
                  : pending
                  ? Icons.pending_outlined
                  : Icons.check_circle_outline,
              size: 17,
              color: failed
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              _windowToolLabel(toolName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            subtitle: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: failed
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            children: [
              if (details.isNotEmpty)
                AgentToolDetailSurface(
                  text: details,
                  copyTooltip: AppLocalizations.of(context)!.common_copy,
                  onCopy: () => copyText(details),
                  maxHeight: 220,
                  margin: EdgeInsets.zero,
                ),
              if (showMedia)
                for (final image in images)
                  if (image is Map) _AgentWindowImageCard(image: image),
              if (failed && showRetry)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey(
                      'agent-window-tool-retry-${result['toolCallId'] ?? toolName}',
                    ),
                    onPressed: retryEnabled ? retry : null,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(AppLocalizations.of(context)!.common_retry),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentWindowToolMedia extends StatelessWidget {
  const _AgentWindowToolMedia({required this.result});

  final Map<Object?, Object?> result;

  @override
  Widget build(BuildContext context) {
    final images = result['images'] is List
        ? result['images'] as List
        : const [];
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('agent-window-tool-media-${result['toolCallId']}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final image in images)
            if (image is Map)
              SizedBox(width: 180, child: _AgentWindowImageCard(image: image)),
        ],
      ),
    );
  }
}

class _AgentWindowImageCard extends StatelessWidget {
  const _AgentWindowImageCard({required this.image});

  final Map image;

  @override
  Widget build(BuildContext context) {
    Widget Function() imageBuilder;
    if (image['base64'] case final String data) {
      try {
        final bytes = base64Decode(data);
        imageBuilder = () => Image.memory(bytes, fit: BoxFit.contain);
      } on FormatException {
        return const _AgentWindowBrokenImage();
      }
    } else if (image['url'] case final String url
        when _isSafeAgentWindowImageUrl(url)) {
      imageBuilder = () => Image.network(
        url,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _AgentWindowBrokenImage(),
      );
    } else {
      return const _AgentWindowBrokenImage();
    }
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.agentChat_toolGenerateImage,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            _showAgentWindowImagePreview(context, imageBuilder: imageBuilder),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 420),
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: imageBuilder(),
        ),
      ),
    );
  }
}

bool _isSafeAgentWindowImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

class _AgentWindowBrokenImage extends StatelessWidget {
  const _AgentWindowBrokenImage();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_outlined, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.agentChat_resourceUnavailable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Future<void> _showAgentWindowImagePreview(
  BuildContext context, {
  required Widget Function() imageBuilder,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 800),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(dialogContext).colorScheme.surfaceContainerLowest,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 8,
                child: Center(child: imageBuilder()),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: MaterialLocalizations.of(
                    dialogContext,
                  ).closeButtonTooltip,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
