import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Controls a pane whose width is applied directly during render layout.
///
/// Pointer updates notify only the pane's render object. The surrounding widget
/// tree therefore keeps its identity while the split layout follows the drag.
class ResizablePaneController extends ChangeNotifier {
  ResizablePaneController({required double initialWidth})
    : assert(initialWidth >= 0),
      _preferredWidth = initialWidth,
      _effectiveWidth = initialWidth;

  double _preferredWidth;
  double _effectiveWidth;
  double? _minimumWidth;
  double? _maximumWidth;

  double get width => _effectiveWidth;

  void resizeBy(double delta) {
    final minimumWidth = _minimumWidth ?? 0;
    final maximumWidth = _maximumWidth ?? double.infinity;
    final nextWidth = (_effectiveWidth + delta)
        .clamp(minimumWidth, maximumWidth)
        .toDouble();
    if (nextWidth == _effectiveWidth) return;

    _preferredWidth = nextWidth;
    _effectiveWidth = nextWidth;
    notifyListeners();
  }

  double _resolveWidth(double minimumWidth, double maximumWidth) {
    _minimumWidth = minimumWidth;
    _maximumWidth = maximumWidth;
    _effectiveWidth = _preferredWidth
        .clamp(minimumWidth, maximumWidth)
        .toDouble();
    return _effectiveWidth;
  }
}

/// Constrains [child] to a controller-driven width without rebuilding widgets.
class ResizablePane extends SingleChildRenderObjectWidget {
  const ResizablePane({
    super.key,
    required this.controller,
    required this.minimumWidth,
    required this.maximumWidth,
    required super.child,
  }) : assert(minimumWidth >= 0),
       assert(maximumWidth >= minimumWidth);

  final ResizablePaneController controller;
  final double minimumWidth;
  final double maximumWidth;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderResizablePane(
    controller: controller,
    minimumWidth: minimumWidth,
    maximumWidth: maximumWidth,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final pane = renderObject as _RenderResizablePane;
    pane
      ..controller = controller
      ..minimumWidth = minimumWidth
      ..maximumWidth = maximumWidth;
  }
}

class _RenderResizablePane extends RenderProxyBox {
  _RenderResizablePane({
    required ResizablePaneController controller,
    required double minimumWidth,
    required double maximumWidth,
  }) : _controller = controller,
       _minimumWidth = minimumWidth,
       _maximumWidth = maximumWidth {
    _controller.addListener(_handleWidthChanged);
  }

  ResizablePaneController _controller;
  double _minimumWidth;
  double _maximumWidth;

  ResizablePaneController get controller => _controller;

  set controller(ResizablePaneController value) {
    if (identical(value, _controller)) return;
    _controller.removeListener(_handleWidthChanged);
    _controller = value..addListener(_handleWidthChanged);
    markNeedsLayout();
  }

  double get minimumWidth => _minimumWidth;

  set minimumWidth(double value) {
    if (value == _minimumWidth) return;
    _minimumWidth = value;
    markNeedsLayout();
  }

  double get maximumWidth => _maximumWidth;

  set maximumWidth(double value) {
    if (value == _maximumWidth) return;
    _maximumWidth = value;
    markNeedsLayout();
  }

  void _handleWidthChanged() => markNeedsLayout();

  BoxConstraints _childConstraints() {
    final parentMaximum = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : _maximumWidth;
    final maximum = _maximumWidth.clamp(0, parentMaximum).toDouble();
    final minimum = _minimumWidth.clamp(0, maximum).toDouble();
    final width = _controller._resolveWidth(minimum, maximum);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(_controller.width, 0));
      return;
    }

    child.layout(_childConstraints(), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size.zero);

    final parentMaximum = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : _maximumWidth;
    final maximum = _maximumWidth.clamp(0, parentMaximum).toDouble();
    final minimum = _minimumWidth.clamp(0, maximum).toDouble();
    final width = _controller.width.clamp(minimum, maximum).toDouble();
    return constraints.constrain(
      child.getDryLayout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: constraints.minHeight,
          maxHeight: constraints.maxHeight,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleWidthChanged);
    super.dispose();
  }
}
