import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../tag_editor_view.dart';

/// Reveals a clipped editor before scrolling its content. Once visible, wheel
/// input stays in the editor even at its boundaries; touch drags stay native.
class PromptScrollCoordinator extends StatefulWidget {
  const PromptScrollCoordinator({
    super.key,
    required this.tagMode,
    required this.textWheelAdjustmentActive,
    required this.child,
  });

  final bool tagMode;
  final bool Function() textWheelAdjustmentActive;
  final Widget child;

  @override
  State<PromptScrollCoordinator> createState() =>
      _PromptScrollCoordinatorState();
}

class _PromptScrollCoordinatorState extends State<PromptScrollCoordinator> {
  ScrollableState? _textScroll;
  ScrollableState? _tagScroll;
  Drag? _trackpadDrag;
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
  }

  @override
  void dispose() {
    _trackpad.dispose();
    _cancelTrackpad();
    super.dispose();
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
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      _scroll(event.scrollDelta.dy);
      resolved.respond(allowPlatformDefault: false);
    });
  }

  void _scroll(double delta) {
    if (!mounted) return;
    final scroll = _activeScroll;
    if (scroll == null) return;
    final remaining = _reveal(delta);
    final position = scroll.position;
    final sign = position.axisDirection == AxisDirection.up ? -1 : 1;
    position.pointerScroll(remaining * sign);
  }

  void _startTrackpad(DragStartDetails details) {
    final scroll = _activeScroll;
    if (scroll == null) return;
    _trackpadDrag = scroll.position.drag(details, () => _trackpadDrag = null);
  }

  void _updateTrackpad(DragUpdateDetails details) {
    final drag = _trackpadDrag;
    if (drag == null) return;
    final remaining = _reveal(-details.primaryDelta!);
    drag.update(
      DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: Offset(0, -remaining),
        primaryDelta: -remaining,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
    );
  }

  void _endTrackpad(DragEndDetails details) {
    final drag = _trackpadDrag;
    _trackpadDrag = null;
    drag?.end(details);
  }

  void _cancelTrackpad() {
    final drag = _trackpadDrag;
    _trackpadDrag = null;
    drag?.cancel();
  }

  double _reveal(double delta) {
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
      final viewport = scroll.context.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return true;
      final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
      final clipped = remaining < 0
          ? math.min(0.0, editor.top - visible.top)
          : math.max(0.0, editor.bottom - visible.bottom);
      final requested = remaining < 0
          ? math.max(remaining, clipped)
          : math.min(remaining, clipped);
      if (requested == 0) return true;
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
