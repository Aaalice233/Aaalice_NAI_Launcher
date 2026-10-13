import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderBox, RenderProxyBox, ScrollCacheExtent;

import '../../../core/utils/localization_extension.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_transcript_geometry.dart';
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
    required this.compactLayout,
    required this.hasEarlier,
    required this.historyLoading,
    required this.prependAnchorEntryId,
    required this.geometryRevision,
    required this.onLoadEarlier,
    required this.live,
    required this.turnBuilder,
  });

  final String sessionId;
  final List<AgentChatTurnModel> turns;
  final AgentChatPanelController controller;
  final double horizontalPadding;
  final double maxWidth;
  final bool compactLayout;
  final bool hasEarlier;
  final bool historyLoading;
  final String? prependAnchorEntryId;
  final Object geometryRevision;
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
  static const _fullMeasureExtent = 100000.0;

  final Map<Object, GlobalKey> _turnKeys = {};
  final Map<Object, double> _measuredHeights = {};
  late int _visibleTurnCount;
  double? _liveExtent;
  double? _earlierButtonExtent;
  bool _measureWholeWindow = true;
  bool _frameEndRefreshScheduled = false;
  double? _measuredCrossExtent;
  bool _remeasureAfterResize = false;
  late final AgentChatPausedDriftCorrection _pausedDrift =
      AgentChatPausedDriftCorrection(
        isEnabled: _canCorrectPausedDrift,
        minimumCorrection: _minimumDriftCorrection,
      );

  @override
  void initState() {
    super.initState();
    _visibleTurnCount = _initialVisibleCount;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
  }

  @override
  void didUpdateWidget(covariant AgentChatThreadViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _visibleTurnCount = _initialVisibleCount;
      _turnKeys.clear();
      _measuredHeights.clear();
      _liveExtent = null;
      _earlierButtonExtent = null;
      _pausedDrift.clear();
      _measureWholeWindow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    } else {
      final previousVisibleTurnCount = _visibleTurnCount;
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
      if (widget.turns.length > oldWidget.turns.length ||
          _visibleTurnCount > previousVisibleTurnCount) {
        _measureWholeWindow = true;
      }
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
      turn.timeline?.id ?? turn.ordinal;

  GlobalKey _keyFor(AgentChatTurnModel turn) =>
      _turnKeys.putIfAbsent(_identityFor(turn), GlobalKey.new);

  // Layout is final here; a build-phase capture still sees the previous layout
  // and would read a wheel offset applied in between as content drift.
  void _scheduleFrameEndRefresh() {
    if (_frameEndRefreshScheduled) return;
    _frameEndRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameEndRefreshScheduled = false;
      if (!mounted) return;
      _trackCrossAxisExtent();
      _refreshPausedDriftAnchor();
    });
  }

  void _refreshPausedDriftAnchor() {
    final controller = widget.controller;
    if (controller.followingLatest || !controller.scrollController.hasClients) {
      _pausedDrift.clear();
      return;
    }
    final anchors = _captureVisibleAnchors();
    if (anchors.isEmpty) {
      _pausedDrift.clear();
      return;
    }
    final anchor = anchors.first;
    final renderObject = anchor.key.currentContext?.findRenderObject();
    _pausedDrift.track(
      () => AgentChatPausedDriftCorrection.topEdgeOf(
        renderObject,
        _measuredHeights[anchor.identity],
      ),
    );
  }

  // Keep-alive turns outside the cache keep heights from the old width; wait
  // for the width to settle so a drag resize does not lay out every turn.
  void _trackCrossAxisExtent() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final extent = box.size.width;
    // Minimizing reports zero size without changing any turn layout.
    if (extent <= 0) return;
    final previous = _measuredCrossExtent;
    _measuredCrossExtent = extent;
    if (previous == null) return;
    if (extent != previous) {
      _remeasureAfterResize = true;
      _scheduleFrameEndRefresh();
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    if (_remeasureAfterResize && !_measureWholeWindow) {
      _remeasureAfterResize = false;
      setState(() => _measureWholeWindow = true);
    }
  }

  void _scheduleMeasureWindowReset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_measureWholeWindow) return;
      setState(() => _measureWholeWindow = false);
    });
  }

  bool _canCorrectPausedDrift() {
    final controller = widget.controller;
    if (controller.followingLatest || controller.userScrolling) return false;
    final scroll = controller.scrollController;
    // Driven and ballistic activities overwrite pixels with absolute values.
    return scroll.hasClients && !scroll.position.isScrollingNotifier.value;
  }

  double _minimumDriftCorrection() {
    final scroll = widget.controller.scrollController;
    if (!scroll.hasClients) return double.negativeInfinity;
    final position = scroll.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return double.negativeInfinity;
    }
    return position.minScrollExtent - position.pixels;
  }

  List<_ViewportAnchor> _captureVisibleAnchors() {
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return const [];
    }
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    final anchors = <_ViewportAnchor>[];
    for (final turn in widget.turns) {
      final identity = _identityFor(turn);
      final key = _turnKeys[identity];
      final renderObject = key?.currentContext?.findRenderObject();
      if (key == null ||
          renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (bottom <= viewportTop || top >= viewportBottom) continue;
      anchors.add(_ViewportAnchor(key: key, identity: identity, top: top));
    }
    anchors.sort((a, b) {
      final aDistance = (a.top - viewportTop).abs();
      final bDistance = (b.top - viewportTop).abs();
      return aDistance.compareTo(bDistance);
    });
    return anchors;
  }

  Future<void> _jumpTo(AgentChatTurnModel turn) async {
    final index = widget.turns.indexOf(turn);
    if (index < 0) return;
    if (index == widget.turns.length - 1) {
      widget.controller.followLatest();
      return;
    }
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    widget.controller.pauseFollowingLatest();
    final targetContext = _keyFor(turn).currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
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
    final targetOffset = estimatedOffset
        .clamp(0, scroll.position.maxScrollExtent)
        .toDouble();
    if (disableAnimations) {
      scroll.jumpTo(targetOffset);
      return;
    }
    await scroll.animateTo(
      targetOffset,
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
      _measureWholeWindow = true;
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
    _scheduleFrameEndRefresh();
    if (_measureWholeWindow) _scheduleMeasureWindowReset();
    final visibleStart = widget.turns.length - _visibleTurnCount;
    final showEarlier = _hiddenCount > 0 || widget.hasEarlier;
    final itemCount = 1 + _visibleTurnCount + (showEarlier ? 1 : 0);
    final visibleTurns = widget.turns
        .skip(visibleStart)
        .toList(growable: false);
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            _scheduleFrameEndRefresh();
            return widget.controller.handleScrollMetricsNotification(
              notification,
            );
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _scheduleFrameEndRefresh();
              return widget.controller.handleScrollNotification(notification);
            },
            // Keyboard and scrollbar track moves are driven scroll activities,
            // so arm their user intent before notifications change the offset.
            child: Focus(
              onKeyEvent: widget.controller.handleViewportKeyEvent,
              child: Listener(
                onPointerDown: (_) =>
                    widget.controller.beginPotentialUserScroll(),
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    widget.controller.beginPotentialWheelScroll();
                  }
                },
                onPointerUp: (_) =>
                    widget.controller.cancelPotentialUserScroll(),
                onPointerCancel: (_) =>
                    widget.controller.cancelPotentialUserScroll(),
                child: CustomScrollView(
                  key: ValueKey('agent-chat-thread-${widget.sessionId}'),
                  controller: widget.controller.scrollController,
                  reverse: true,
                  scrollCacheExtent: ScrollCacheExtent.pixels(
                    _measureWholeWindow ? _fullMeasureExtent : _overscanExtent,
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.horizontalPadding,
                        vertical: 12,
                      ),
                      sliver: AgentChatDriftCorrectingSliver(
                        drift: _pausedDrift,
                        sliver: SliverList(
                          delegate: AgentChatTranscriptChildDelegate(
                            _buildItem,
                            childCount: itemCount,
                            measuredExtentOf: _measuredExtentAt,
                            unmeasuredExtent: _unmeasuredTurnExtent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!widget.compactLayout &&
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

  Widget _buildItem(BuildContext context, int index) {
    if (index == 0) {
      return _MeasureSize(
        onChange: (size) => _liveExtent = size.height,
        child: _bounded(widget.live),
      );
    }
    final reverseTurnIndex = index - 1;
    if (reverseTurnIndex < _visibleTurnCount) {
      final turnIndex = widget.turns.length - 1 - reverseTurnIndex;
      final turn = widget.turns[turnIndex];
      final identity = _identityFor(turn);
      return _RetainedTurn(
        child: _MeasureSize(
          key: _keyFor(turn),
          onChange: (size) => _measuredHeights[identity] = size.height,
          child: RepaintBoundary(
            key: ValueKey('agent-turn-${turn.timeline?.id ?? turn.ordinal}'),
            child: _bounded(
              widget.turnBuilder(
                context,
                turn,
                turnIndex == widget.turns.length - 1,
              ),
            ),
          ),
        ),
      );
    }
    return _MeasureSize(
      onChange: (size) => _earlierButtonExtent = size.height,
      child: _bounded(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextButton.icon(
            key: const ValueKey('agent-chat-earlier-messages'),
            onPressed: widget.historyLoading ? null : _showEarlier,
            icon: widget.historyLoading
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.7,
                      value: MediaQuery.disableAnimationsOf(context)
                          ? 0.75
                          : null,
                    ),
                  )
                : const Icon(Icons.history_rounded, size: 17),
            label: Text(
              widget.historyLoading
                  ? context.l10n.common_loading
                  : _hiddenCount > 0
                  ? context.l10n.agentChat_earlierMessages(_hiddenCount)
                  : context.l10n.agentChat_loadEarlierMessages,
            ),
          ),
        ),
      ),
    );
  }

  double? _measuredExtentAt(int index) {
    if (index == 0) return _liveExtent;
    final reverseTurnIndex = index - 1;
    if (reverseTurnIndex >= _visibleTurnCount) return _earlierButtonExtent;
    final turnIndex = widget.turns.length - 1 - reverseTurnIndex;
    if (turnIndex < 0 || turnIndex >= widget.turns.length) return null;
    return _measuredHeights[_identityFor(widget.turns[turnIndex])];
  }

  double _unmeasuredTurnExtent() =>
      AgentChatTranscriptChildDelegate.medianExtent(
        widget.turns
            .map((turn) => _measuredHeights[_identityFor(turn)])
            .whereType<double>(),
        whenEmpty: _estimatedTurnHeight,
      );

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

class _RetainedTurn extends StatefulWidget {
  const _RetainedTurn({required this.child});

  final Widget child;

  @override
  State<_RetainedTurn> createState() => _RetainedTurnState();
}

class _RetainedTurnState extends State<_RetainedTurn>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ViewportAnchor {
  const _ViewportAnchor({
    required this.key,
    required this.identity,
    required this.top,
  });

  final GlobalKey key;
  final Object identity;
  final double top;
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({super.key, required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this._onChange);

  ValueChanged<Size> _onChange;
  Size? _reportedSize;

  set onChange(ValueChanged<Size> value) => _onChange = value;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reportedSize) return;
    _reportedSize = size;
    _onChange(size);
  }
}
