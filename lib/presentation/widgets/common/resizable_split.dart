import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../adaptive/interaction_policy.dart';
import 'horizontal_resize_handle.dart';
import 'vertical_resize_handle.dart';

enum ResizableSplitUnit { fraction, logicalPixels }

/// Stores the trailing pane extent of a [ResizableSplit]. Pointer updates only
/// mark the split for relayout, so both pane subtrees keep their identity.
class ResizableSplitController extends ChangeNotifier {
  ResizableSplitController.fraction(double value)
    : unit = ResizableSplitUnit.fraction,
      _value = value;

  ResizableSplitController.logicalPixels(double value)
    : unit = ResizableSplitUnit.logicalPixels,
      _value = value;

  final ResizableSplitUnit unit;
  double _value;
  double _available = 0;
  double _minimumTrailing = 0;
  double _maximumTrailing = 0;

  double get value => _value;

  void setValue(double value) {
    if (value == _value) return;
    _value = value;
    notifyListeners();
  }

  /// Positive [delta] moves the divider toward the trailing pane.
  void dragBy(double delta) {
    if (_available <= 0 || delta == 0) return;
    final current = _preferredTrailing(
      _available,
    ).clamp(_minimumTrailing, _maximumTrailing).toDouble();
    final next = (current - delta)
        .clamp(_minimumTrailing, _maximumTrailing)
        .toDouble();
    if (next == current) return;
    _value = unit == ResizableSplitUnit.fraction ? next / _available : next;
    notifyListeners();
  }

  double _preferredTrailing(double available) =>
      unit == ResizableSplitUnit.fraction ? _value * available : _value;

  double _resolveTrailing(
    double available,
    double minimumLeading,
    double minimumTrailing,
  ) {
    _available = available;
    if (available <= 0) {
      _minimumTrailing = 0;
      _maximumTrailing = 0;
      return 0;
    }
    final required = minimumLeading + minimumTrailing;
    if (required > available) {
      // Share scarce space by the minimum ratio so neither pane overflows.
      final trailing = required == 0
          ? available / 2
          : available * minimumTrailing / required;
      _minimumTrailing = trailing;
      _maximumTrailing = trailing;
      return trailing;
    }
    _minimumTrailing = minimumTrailing;
    _maximumTrailing = available - minimumLeading;
    return _preferredTrailing(
      available,
    ).clamp(_minimumTrailing, _maximumTrailing).toDouble();
  }
}

/// Two panes separated by a draggable, keyboard-adjustable divider.
class ResizableSplit extends StatefulWidget {
  const ResizableSplit({
    super.key,
    required this.axis,
    required this.controller,
    required this.leading,
    required this.trailing,
    required this.minimumLeadingExtent,
    required this.minimumTrailingExtent,
    required this.resizeLabel,
    this.onResizeEnd,
    this.dividerKey,
  });

  static const double keyboardStep = 16;

  final Axis axis;
  final ResizableSplitController controller;
  final Widget leading;
  final Widget trailing;
  final double minimumLeadingExtent;
  final double minimumTrailingExtent;
  final String resizeLabel;
  final VoidCallback? onResizeEnd;
  final Key? dividerKey;

  @override
  State<ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<ResizableSplit> {
  final _focusNode = FocusNode(debugLabel: 'resizable-split-divider');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _step(double delta) {
    widget.controller.dragBy(delta);
    widget.onResizeEnd?.call();
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final horizontal = widget.axis == Axis.horizontal;
    final key = event.logicalKey;
    if (key ==
        (horizontal
            ? LogicalKeyboardKey.arrowLeft
            : LogicalKeyboardKey.arrowUp)) {
      _step(-ResizableSplit.keyboardStep);
    } else if (key ==
        (horizontal
            ? LogicalKeyboardKey.arrowRight
            : LogicalKeyboardKey.arrowDown)) {
      _step(ResizableSplit.keyboardStep);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final policy = context.interactionPolicy;
    final highlighted = _focused && policy.keyboardNavigationActive;
    final handle = widget.axis == Axis.horizontal
        ? ResizeHandle(
            onDragStart: _focusNode.requestFocus,
            onDrag: widget.controller.dragBy,
            onDragEnd: widget.onResizeEnd,
          )
        : VerticalResizeHandle(
            onDragStart: _focusNode.requestFocus,
            onDrag: widget.controller.dragBy,
            onDragEnd: widget.onResizeEnd,
            focused: highlighted,
          );
    final divider = Focus(
      key: widget.dividerKey,
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: Semantics(
        label: widget.resizeLabel,
        onIncrease: () => _step(-ResizableSplit.keyboardStep),
        onDecrease: () => _step(ResizableSplit.keyboardStep),
        child: ColoredBox(
          color: highlighted
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: handle,
        ),
      ),
    );
    return CustomMultiChildLayout(
      delegate: _ResizableSplitLayout(
        axis: widget.axis,
        controller: widget.controller,
        minimumLeading: widget.minimumLeadingExtent,
        minimumTrailing: widget.minimumTrailingExtent,
      ),
      children: [
        LayoutId(id: _SplitSlot.leading, child: widget.leading),
        LayoutId(id: _SplitSlot.divider, child: divider),
        LayoutId(id: _SplitSlot.trailing, child: widget.trailing),
      ],
    );
  }
}

enum _SplitSlot { leading, divider, trailing }

class _ResizableSplitLayout extends MultiChildLayoutDelegate {
  _ResizableSplitLayout({
    required this.axis,
    required this.controller,
    required this.minimumLeading,
    required this.minimumTrailing,
  }) : super(relayout: controller);

  final Axis axis;
  final ResizableSplitController controller;
  final double minimumLeading;
  final double minimumTrailing;

  @override
  void performLayout(Size size) {
    final horizontal = axis == Axis.horizontal;
    final mainExtent = horizontal ? size.width : size.height;
    final crossExtent = horizontal ? size.height : size.width;
    final dividerSize = layoutChild(
      _SplitSlot.divider,
      horizontal
          ? BoxConstraints(
              maxWidth: mainExtent,
              minHeight: crossExtent,
              maxHeight: crossExtent,
            )
          : BoxConstraints(
              minWidth: crossExtent,
              maxWidth: crossExtent,
              maxHeight: mainExtent,
            ),
    );
    final dividerExtent = horizontal ? dividerSize.width : dividerSize.height;
    final available = math.max(0.0, mainExtent - dividerExtent);
    final trailing = controller._resolveTrailing(
      available,
      minimumLeading,
      minimumTrailing,
    );
    final leading = available - trailing;

    Size paneSize(double extent) =>
        horizontal ? Size(extent, crossExtent) : Size(crossExtent, extent);
    Offset offsetAt(double extent) =>
        horizontal ? Offset(extent, 0) : Offset(0, extent);

    layoutChild(_SplitSlot.leading, BoxConstraints.tight(paneSize(leading)));
    positionChild(_SplitSlot.leading, Offset.zero);
    positionChild(_SplitSlot.divider, offsetAt(leading));
    layoutChild(_SplitSlot.trailing, BoxConstraints.tight(paneSize(trailing)));
    positionChild(_SplitSlot.trailing, offsetAt(leading + dividerExtent));
  }

  @override
  bool shouldRelayout(_ResizableSplitLayout oldDelegate) =>
      oldDelegate.axis != axis ||
      oldDelegate.controller != controller ||
      oldDelegate.minimumLeading != minimumLeading ||
      oldDelegate.minimumTrailing != minimumTrailing;
}
