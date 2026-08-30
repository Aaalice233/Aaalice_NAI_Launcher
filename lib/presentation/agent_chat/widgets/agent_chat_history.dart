import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox, ScrollCacheExtent;

import '../../../core/utils/localization_extension.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_turn.dart';

typedef AgentChatTurnBuilder =
    Widget Function(
      BuildContext context,
      AgentChatTurnModel turn,
      bool current,
    );

/// Turn-virtualized transcript viewport.
///
/// SliverList owns variable-height geometry and only asks for visible turns
/// plus [cacheExtent] overscan. Collapsed history and item transcripts are not
/// inserted into the element tree until explicitly requested.
class AgentChatThreadViewport extends StatefulWidget {
  const AgentChatThreadViewport({
    super.key,
    required this.sessionId,
    required this.turns,
    required this.controller,
    required this.horizontalPadding,
    required this.maxWidth,
    required this.mobile,
    required this.hasEarlier,
    required this.historyLoading,
    required this.prependAnchorEntryId,
    required this.onLoadEarlier,
    required this.live,
    required this.turnBuilder,
  });

  final String sessionId;
  final List<AgentChatTurnModel> turns;
  final AgentChatPanelController controller;
  final double horizontalPadding;
  final double maxWidth;
  final bool mobile;
  final bool hasEarlier;
  final bool historyLoading;
  final String? prependAnchorEntryId;
  final Future<void> Function()? onLoadEarlier;
  final Widget live;
  final AgentChatTurnBuilder turnBuilder;

  @override
  State<AgentChatThreadViewport> createState() =>
      _AgentChatThreadViewportState();
}

class _AgentChatThreadViewportState extends State<AgentChatThreadViewport> {
  static const _retainedTurnCount = 6;
  static const _historyPageSize = 8;
  static const _overscanExtent = 900.0;
  static const _estimatedTurnHeight = 180.0;

  final Map<Object, GlobalKey> _turnKeys = {};
  final Map<Object, double> _measuredHeights = {};
  late int _visibleTurnCount;
  int _anchorRestoreGeneration = 0;

  @override
  void initState() {
    super.initState();
    _visibleTurnCount = _initialVisibleCount;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
  }

  @override
  void didUpdateWidget(covariant AgentChatThreadViewport oldWidget) {
    final sameSession = oldWidget.sessionId == widget.sessionId;
    final anchors = sameSession && !widget.controller.followingLatest
        ? _captureVisibleAnchors()
        : const <_ViewportAnchor>[];
    super.didUpdateWidget(oldWidget);
    if (!sameSession) {
      _anchorRestoreGeneration++;
      _visibleTurnCount = _initialVisibleCount;
      _turnKeys.clear();
      _measuredHeights.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    } else {
      if (widget.turns.length < _visibleTurnCount) {
        _visibleTurnCount = widget.turns.length;
      } else if (widget.turns.length > oldWidget.turns.length &&
          _visibleTurnCount >= oldWidget.turns.length) {
        final added = widget.turns.length - oldWidget.turns.length;
        final prepended =
            widget.prependAnchorEntryId != null &&
            widget.prependAnchorEntryId != oldWidget.prependAnchorEntryId;
        final revealCount = prepended && added > _historyPageSize
            ? _historyPageSize
            : added;
        _visibleTurnCount = (_visibleTurnCount + revealCount).clamp(
          0,
          widget.turns.length,
        );
      }
      if (anchors.isNotEmpty) _scheduleAnchorRestore(anchors);
    }
  }

  int get _initialVisibleCount =>
      widget.turns.length.clamp(0, _retainedTurnCount);

  int get _hiddenCount => widget.turns.length - _visibleTurnCount;

  void _saveOffset(String sessionId) {
    widget.controller.saveSessionOffset(sessionId);
  }

  void _restoreOffset() {
    if (!mounted) return;
    widget.controller.restoreSessionOffset(widget.sessionId);
  }

  Object _identityFor(AgentChatTurnModel turn) =>
      turn.timeline?.id ?? turn.userMessage ?? turn;

  GlobalKey _keyFor(AgentChatTurnModel turn) =>
      _turnKeys.putIfAbsent(_identityFor(turn), GlobalKey.new);

  List<_ViewportAnchor> _captureVisibleAnchors() {
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return const [];
    }
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    final anchors = <_ViewportAnchor>[];
    for (final key in _turnKeys.values) {
      final anchorContext = key.currentContext;
      final renderObject = anchorContext?.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (bottom <= viewportTop || top >= viewportBottom) continue;
      anchors.add(_ViewportAnchor(key: key, top: top));
    }
    anchors.sort((a, b) {
      final aDistance = (a.top - viewportTop).abs();
      final bDistance = (b.top - viewportTop).abs();
      return aDistance.compareTo(bDistance);
    });
    return anchors;
  }

  void _scheduleAnchorRestore(List<_ViewportAnchor> anchors) {
    final generation = ++_anchorRestoreGeneration;
    final interactionRevision = widget.controller.viewportInteractionRevision;
    final sessionId = widget.sessionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _anchorRestoreGeneration ||
          widget.sessionId != sessionId ||
          widget.controller.followingLatest) {
        return;
      }
      for (final anchor in anchors) {
        final anchorContext = anchor.key.currentContext;
        final renderObject = anchorContext?.findRenderObject();
        if (renderObject is! RenderBox ||
            !renderObject.attached ||
            !renderObject.hasSize) {
          continue;
        }
        final currentTop = renderObject.localToGlobal(Offset.zero).dy;
        widget.controller.restorePausedViewportAnchor(
          visualDelta: currentTop - anchor.top,
          expectedInteractionRevision: interactionRevision,
        );
        return;
      }
    });
  }

  Future<void> _jumpTo(AgentChatTurnModel turn) async {
    final index = widget.turns.indexOf(turn);
    if (index < 0) return;
    if (index == widget.turns.length - 1) {
      widget.controller.followLatest();
      return;
    }
    widget.controller.pauseFollowingLatest();
    final context = _keyFor(turn).currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
      return;
    }
    final scroll = widget.controller.scrollController;
    if (!scroll.hasClients) return;
    var estimatedOffset = 0.0;
    for (var later = widget.turns.length - 1; later > index; later--) {
      estimatedOffset +=
          _measuredHeights[_identityFor(widget.turns[later])] ??
          _estimatedTurnHeight;
    }
    await scroll.animateTo(
      estimatedOffset.clamp(0, scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showEarlier() async {
    if (_hiddenCount == 0) {
      if (!widget.historyLoading) await widget.onLoadEarlier?.call();
      return;
    }
    final scroll = widget.controller.scrollController;
    final before = scroll.hasClients ? scroll.offset : null;
    setState(() {
      _visibleTurnCount = (_visibleTurnCount + _historyPageSize).clamp(
        0,
        widget.turns.length,
      );
    });
    // In reverse geometry older turns are appended beyond the current anchor.
    // Keep the exact pixel anchor if the framework performs any correction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (before == null || !scroll.hasClients) return;
      widget.controller.jumpToPreservingFollow(before);
    });
  }

  @override
  void dispose() {
    _saveOffset(widget.sessionId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleStart = widget.turns.length - _visibleTurnCount;
    final showEarlier = _hiddenCount > 0 || widget.hasEarlier;
    final itemCount = 1 + _visibleTurnCount + (showEarlier ? 1 : 0);
    final visibleTurns = widget.turns
        .skip(visibleStart)
        .toList(growable: false);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: widget.controller.handleScrollNotification,
          // Keyboard and scrollbar track moves are driven scroll activities,
          // so arm their user intent before notifications change the offset.
          child: Focus(
            onKeyEvent: widget.controller.handleViewportKeyEvent,
            child: Listener(
              onPointerDown: (_) =>
                  widget.controller.beginPotentialUserScroll(),
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  widget.controller.beginPotentialUserScroll();
                }
              },
              onPointerUp: (_) => widget.controller.cancelPotentialUserScroll(),
              onPointerCancel: (_) =>
                  widget.controller.cancelPotentialUserScroll(),
              child: CustomScrollView(
                key: PageStorageKey('agent-chat-thread-${widget.sessionId}'),
                controller: widget.controller.scrollController,
                reverse: true,
                scrollCacheExtent: const ScrollCacheExtent.pixels(
                  _overscanExtent,
                ),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.horizontalPadding,
                      vertical: 12,
                    ),
                    sliver: SliverList.builder(
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _bounded(widget.live);
                        }
                        final reverseTurnIndex = index - 1;
                        if (reverseTurnIndex < _visibleTurnCount) {
                          final turnIndex =
                              widget.turns.length - 1 - reverseTurnIndex;
                          final turn = widget.turns[turnIndex];
                          final identity = _identityFor(turn);
                          return _MeasureSize(
                            key: _keyFor(turn),
                            onChange: (size) =>
                                _measuredHeights[identity] = size.height,
                            child: RepaintBoundary(
                              key: ValueKey(
                                'agent-turn-${turn.timeline?.id ?? turnIndex}',
                              ),
                              child: _bounded(
                                widget.turnBuilder(
                                  context,
                                  turn,
                                  turnIndex == widget.turns.length - 1,
                                ),
                              ),
                            ),
                          );
                        }
                        return _bounded(
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextButton.icon(
                              key: const ValueKey(
                                'agent-chat-earlier-messages',
                              ),
                              onPressed: widget.historyLoading
                                  ? null
                                  : _showEarlier,
                              icon: widget.historyLoading
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.7,
                                      ),
                                    )
                                  : const Icon(Icons.history_rounded, size: 17),
                              label: Text(
                                widget.historyLoading
                                    ? context.l10n.common_loading
                                    : _hiddenCount > 0
                                    ? context.l10n.agentChat_earlierMessages(
                                        _hiddenCount,
                                      )
                                    : context
                                          .l10n
                                          .agentChat_loadEarlierMessages,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!widget.mobile &&
            widget.horizontalPadding >= 24 &&
            visibleTurns.length > 1)
          Positioned(
            left: 2,
            top: 16,
            bottom: 16,
            child: _TurnGutter(turns: visibleTurns, onSelected: _jumpTo),
          ),
      ],
    );
  }

  Widget _bounded(Widget child) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: child,
    ),
  );
}

class _TurnGutter extends StatelessWidget {
  const _TurnGutter({required this.turns, required this.onSelected});

  final List<AgentChatTurnModel> turns;
  final ValueChanged<AgentChatTurnModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 38,
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: turns.length,
          itemBuilder: (context, index) => Tooltip(
            message: context.l10n.agentChat_turnNavigation(
              index + 1,
              _preview(turns[index].preview),
            ),
            child: InkResponse(
              key: ValueKey('agent-turn-gutter-${turns[index].ordinal}'),
              onTap: () => onSelected(turns[index]),
              radius: 18,
              child: SizedBox.square(
                dimension: 32,
                child: Center(
                  child: Container(
                    width: index == turns.length - 1 ? 8 : 6,
                    height: index == turns.length - 1 ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == turns.length - 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _preview(String text) {
    if (text.isEmpty) return '…';
    return text.length <= 36 ? text : '${text.substring(0, 36)}…';
  }
}

class _ViewportAnchor {
  const _ViewportAnchor({required this.key, required this.top});

  final GlobalKey key;
  final double top;
}

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({super.key, required this.onChange, required this.child});

  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size != null && size != _oldSize) {
        _oldSize = size;
        widget.onChange(size);
      }
    });
    return widget.child;
  }
}
