import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../tag_editor_view.dart';

/// Reveals a clipped editor before scrolling its content, then hands the
/// leftover back to the page once the editor idles at its own boundary.
/// A focused editor keeps its boundary; touch drags stay native.
class PromptScrollCoordinator extends StatefulWidget {
  const PromptScrollCoordinator({
    super.key,
    required this.tagMode,
    required this.textWheelAdjustmentActive,
    required this.focused,
    required this.child,
  });

  final bool tagMode;
  final bool Function() textWheelAdjustmentActive;
  final bool Function() focused;
  final Widget child;

  @override
  State<PromptScrollCoordinator> createState() =>
      _PromptScrollCoordinatorState();
}

class _PromptScrollCoordinatorState extends State<PromptScrollCoordinator> {
  // Wheel events under this gap belong to one run of the user's hand.
  static const _runGap = Duration(milliseconds: 150);

  ScrollableState? _textScroll;
  ScrollableState? _tagScroll;
  Drag? _trackpadDrag;
  ScrollPosition? _trackpadPosition;
  Duration? _editorScrolledAt;
  Duration? _runWheelAt;
  bool _runIsOurs = false;
  bool _editorTookWheel = false;
  late final VerticalDragGestureRecognizer _trackpad;

  @override
  void initState() {
    super.initState();
    _trackpad =
        VerticalDragGestureRecognizer(
            supportedDevices: {PointerDeviceKind.trackpad},
          )
          ..dragStartBehavior = DragStartBehavior.down
          ..onStart = _startTrackpad
          ..onUpdate = _updateTrackpad
          ..onEnd = _endTrackpad
          ..onCancel = _cancelTrackpad;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_trackRun);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_trackRun);
    _trackpad.dispose();
    _cancelTrackpad();
    super.dispose();
  }

  /// Wheel events elsewhere never reach the hit test, so the run they belong to
  /// is only visible from a global route. It runs after [_wheel] has decided.
  void _trackRun(PointerEvent event) {
    if (event is! PointerScrollEvent) return;
    _runWheelAt = event.timeStamp;
    _runIsOurs = _editorTookWheel;
    _editorTookWheel = false;
  }

  /// True while a run that started outside the editor is still going: the
  /// editor must not steal it just because the page slid under the cursor.
  bool _foreignRun(Duration timeStamp) {
    final wheelAt = _runWheelAt;
    return wheelAt != null && !_runIsOurs && timeStamp - wheelAt < _runGap;
  }

  ScrollableState? get _activeScroll {
    final scroll = widget.tagMode ? _tagScroll : _textScroll;
    if (scroll == null ||
        !scroll.mounted ||
        !scroll.position.hasContentDimensions ||
        scroll.position.maxScrollExtent <= scroll.position.minScrollExtent ||
        !scroll.position.physics.shouldAcceptUserOffset(scroll.position)) {
      return null;
    }
    return scroll;
  }

  bool get _modified {
    final keys = HardwareKeyboard.instance;
    return keys.isControlPressed ||
        keys.isAltPressed ||
        keys.isMetaPressed ||
        keys.isShiftPressed;
  }

  bool _metrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final scroll = Scrollable.maybeOf(notification.context);
    if (notification.context
            .findAncestorWidgetOfExactType<SingleChildScrollView>()
            ?.key ==
        TagEditorView.scrollViewKey) {
      _tagScroll = scroll;
    } else if (notification.context
            .findAncestorStateOfType<EditableTextState>() !=
        null) {
      _textScroll = scroll;
    }
    return false;
  }

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()) {
      return;
    }
    // Weight shortcuts and horizontal scrolling retain their existing owners.
    if (_modified || _activeScroll == null) return;
    if (!widget.tagMode && widget.textWheelAdjustmentActive()) return;
    if (widget.tagMode &&
        TagEditorView.claimsWeightWheel(_tagScroll!.context, event.position)) {
      return;
    }
    // Declining here would hand the event to the editor's own Scrollable, which
    // sits below this box in the hit test. Yielding means scrolling the page.
    final foreign = _foreignRun(event.timeStamp);
    _editorTookWheel = !foreign;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final delta = event.scrollDelta.dy;
      if (!foreign || _scrollAncestors(delta, clipOnly: false) == delta) {
        _scroll(delta, event.timeStamp);
      }
      resolved.respond(allowPlatformDefault: false);
    });
  }

  void _scroll(double delta, Duration timeStamp) {
    if (!mounted) return;
    final scroll = _activeScroll;
    if (scroll == null) return;
    final position = scroll.position;
    final sign = position.axisDirection == AxisDirection.up ? -1 : 1;
    var remaining = _scrollAncestors(delta, clipOnly: true);
    final before = position.pixels;
    position.pointerScroll(remaining * sign);
    final consumed = (position.pixels - before) * sign;
    remaining -= consumed;
    _handOff(remaining, timeStamp, moved: consumed != 0);
  }

  /// Gives the page what the editor could not take, once the editor has sat at
  /// its boundary for [_runGap]. While the caret is in the editor the page
  /// stays put instead, so typing is never interrupted by the panel moving.
  void _handOff(double remaining, Duration? timeStamp, {required bool moved}) {
    if (moved) _editorScrolledAt = timeStamp;
    if (remaining == 0 || moved || widget.focused() || _latched(timeStamp)) {
      return;
    }
    _scrollAncestors(remaining, clipOnly: false);
  }

  bool _latched(Duration? timeStamp) {
    final scrolledAt = _editorScrolledAt;
    if (scrolledAt == null || timeStamp == null) return false;
    return timeStamp - scrolledAt < _runGap;
  }

  void _startTrackpad(DragStartDetails details) {
    final scroll = _activeScroll;
    if (scroll == null) return;
    final position = scroll.position;
    _trackpadPosition = position;
    _trackpadDrag = position.drag(details, () {
      _trackpadDrag = null;
      _trackpadPosition = null;
    });
  }

  void _updateTrackpad(DragUpdateDetails details) {
    final drag = _trackpadDrag;
    final position = _trackpadPosition;
    if (drag == null || position == null) return;
    final sign = position.axisDirection == AxisDirection.up ? -1 : 1;
    var remaining = _scrollAncestors(-details.primaryDelta!, clipOnly: true);
    final before = position.pixels;
    drag.update(
      DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: Offset(0, -remaining),
        primaryDelta: -remaining,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
    );
    final consumed = (position.pixels - before) * sign;
    remaining -= consumed;
    _handOff(remaining, details.sourceTimeStamp, moved: consumed != 0);
  }

  void _endTrackpad(DragEndDetails details) {
    final drag = _trackpadDrag;
    _trackpadDrag = null;
    _trackpadPosition = null;
    drag?.end(details);
  }

  void _cancelTrackpad() {
    final drag = _trackpadDrag;
    _trackpadDrag = null;
    _trackpadPosition = null;
    drag?.cancel();
  }

  /// Scrolls ancestors by [delta] and returns what none of them took.
  /// [clipOnly] caps each ancestor at the amount still hiding an editor edge.
  double _scrollAncestors(double delta, {required bool clipOnly}) {
    final box = context.findRenderObject()! as RenderBox;
    var editor = box.localToGlobal(Offset.zero) & box.size;
    var remaining = delta;
    context.visitAncestorElements((element) {
      if (remaining == 0) return false;
      if (element is! StatefulElement || element.state is! ScrollableState) {
        return true;
      }
      final scroll = element.state as ScrollableState;
      final position = scroll.position;
      if (position.axis != Axis.vertical ||
          !position.hasContentDimensions ||
          !position.physics.shouldAcceptUserOffset(position)) {
        return true;
      }
      var requested = remaining;
      if (clipOnly) {
        final viewport = scroll.context.findRenderObject();
        if (viewport is! RenderBox || !viewport.hasSize) return true;
        final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
        final clipped = remaining < 0
            ? math.min(0.0, editor.top - visible.top)
            : math.max(0.0, editor.bottom - visible.bottom);
        requested = remaining < 0
            ? math.max(remaining, clipped)
            : math.min(remaining, clipped);
        if (requested == 0) return true;
      }
      final sign = position.axisDirection == AxisDirection.up ? -1 : 1;
      final before = position.pixels;
      position.pointerScroll(requested * sign);
      final consumed = (position.pixels - before) * sign;
      remaining -= consumed;
      editor = editor.shift(Offset(0, -consumed));
      return true;
    });
    return remaining;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: _metrics,
        child: _WheelPriority(
          onSignal: _wheel,
          onTrackpadStart: (event) {
            if (!_modified && _activeScroll != null) {
              _trackpad.gestureSettings = MediaQuery.maybeGestureSettingsOf(
                context,
              );
              _trackpad.addPointerPanZoom(event);
            }
          },
          child: widget.child,
        ),
      );
}

/// Registers before descendant Scrollables so revealing the outer viewport and
/// scrolling the editor are one resolved event, never two competing handlers.
class _WheelPriority extends SingleChildRenderObjectWidget {
  const _WheelPriority({
    required this.onSignal,
    required this.onTrackpadStart,
    required super.child,
  });
  final PointerSignalEventListener onSignal;
  final ValueChanged<PointerPanZoomStartEvent> onTrackpadStart;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _WheelPriorityBox(onSignal, onTrackpadStart);

  @override
  void updateRenderObject(
    BuildContext context,
    _WheelPriorityBox renderObject,
  ) {
    renderObject.onSignal = onSignal;
    renderObject.onTrackpadStart = onTrackpadStart;
  }
}

class _WheelPriorityBox extends RenderProxyBox {
  _WheelPriorityBox(this.onSignal, this.onTrackpadStart);
  PointerSignalEventListener onSignal;
  ValueChanged<PointerPanZoomStartEvent> onTrackpadStart;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerSignalEvent) onSignal(event);
    if (event is PointerPanZoomStartEvent) onTrackpadStart(event);
  }
}
