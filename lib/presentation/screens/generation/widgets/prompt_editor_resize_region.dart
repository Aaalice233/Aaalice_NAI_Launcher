import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/vertical_resize_handle.dart';

/// Keeps manual sizing local to the editor and reuses its mounted child while
/// pointer events change only the height constraint.
class PromptEditorResizeRegion extends StatefulWidget {
  const PromptEditorResizeRegion({
    super.key,
    required this.enabled,
    required this.builder,
    this.initialHeight,
    this.onHeightChanged,
  });

  final double? initialHeight;
  final ValueChanged<double?>? onHeightChanged;
  final bool enabled;
  final Widget Function(bool manualHeight) builder;

  @override
  State<PromptEditorResizeRegion> createState() =>
      _PromptEditorResizeRegionState();
}

class _PromptEditorResizeRegionState extends State<PromptEditorResizeRegion> {
  final _editorKey = GlobalKey();
  late final _height = ValueNotifier<double?>(widget.initialHeight);
  double? _dragHeight;

  double get _renderedHeight => _editorKey.currentContext!.size!.height;

  void _resize(double delta, double minimum, double maximum) {
    final next = ((_dragHeight ?? _renderedHeight) + delta)
        .clamp(minimum, maximum)
        .toDouble();
    if (_dragHeight != null) _dragHeight = next;
    final wasManual = _height.value != null;
    _height.value = next;
    if (!wasManual) setState(() {});
    if (_dragHeight == null) widget.onHeightChanged?.call(next);
  }

  void _reset() {
    _dragHeight = null;
    _height.value = null;
    widget.onHeightChanged?.call(null);
    setState(() {});
  }

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(widget.enabled && _height.value != null);
    final policy = context.interactionPolicy;
    final handleHeight = policy.prefersTouchPresentation
        ? policy.minimumControlExtent
        : 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maximum = math.max(0.0, constraints.maxHeight - handleHeight);
        final minimum = math.min(
          maximum,
          math.max(96.0, MediaQuery.textScalerOf(context).scale(24) + 24),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              fit: widget.enabled ? FlexFit.loose : FlexFit.tight,
              child: ValueListenableBuilder<double?>(
                valueListenable: _height,
                child: child,
                builder: (context, height, editor) => SizedBox(
                  key: _editorKey,
                  height: widget.enabled
                      ? height?.clamp(minimum, maximum).toDouble()
                      : null,
                  child: editor,
                ),
              ),
            ),
            if (widget.enabled)
              _buildHandle(context, handleHeight, minimum, maximum),
          ],
        );
      },
    );
  }

  Widget _buildHandle(
    BuildContext context,
    double handleHeight,
    double minimum,
    double maximum,
  ) {
    void resize(double delta) => _resize(delta, minimum, maximum);
    final label = context.l10n.prompt_resizeHeight;
    return TextFieldTapRegion(
      child: Semantics(
        label: label,
        onIncrease: () => resize(24),
        onDecrease: () => resize(-24),
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyUpEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              resize(24);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              resize(-24);
            } else if (event.logicalKey == LogicalKeyboardKey.home) {
              _reset();
            } else {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: Builder(
            builder: (context) => Tooltip(
              message: label,
              child: GestureDetector(
                onDoubleTap: _reset,
                child: VerticalResizeHandle(
                  key: const ValueKey('generation-prompt-height-handle'),
                  height: handleHeight,
                  focused: Focus.of(context).hasFocus,
                  onDragStart: () => _dragHeight = _renderedHeight,
                  onDragEnd: () {
                    _dragHeight = null;
                    widget.onHeightChanged?.call(_height.value);
                  },
                  onDrag: resize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
