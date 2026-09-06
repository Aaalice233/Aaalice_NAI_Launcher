import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import 'decoded_memory_image.dart';

/// Synchronized before/after image comparison with a draggable divider.
class ImageComparisonView extends StatefulWidget {
  const ImageComparisonView({
    super.key,
    required this.sourceImageBytes,
    required this.generatedImageBytes,
    this.fit = BoxFit.cover,
  });

  final Uint8List sourceImageBytes;
  final Uint8List generatedImageBytes;
  final BoxFit fit;

  @override
  State<ImageComparisonView> createState() => _ImageComparisonViewState();
}

class _ImageComparisonViewState extends State<ImageComparisonView> {
  static const _keyboardStep = 0.05;
  static const _doubleTapScale = 2.0;
  static const _dividerLineWidth = 2.0;
  static const _dividerHitWidth = 48.0;
  static const _dividerThumbSize = 32.0;
  static const _dividerIconSize = 20.0;
  static const _dividerElevation = 2.0;

  final _comparisonKey = GlobalKey();
  final _dividerFocusNode = FocusNode(
    debugLabel: 'generation-image-comparison-divider',
  );
  final _transformationController = TransformationController();

  double _position = 0.5;
  bool _dividerFocused = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void didUpdateWidget(covariant ImageComparisonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sourceImageBytes, widget.sourceImageBytes) ||
        !identical(oldWidget.generatedImageBytes, widget.generatedImageBytes)) {
      _position = 0.5;
      _transformationController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _dividerFocusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _setPosition(double position) {
    final next = position.clamp(0.0, 1.0);
    if (next == _position) return;
    setState(() => _position = next);
  }

  void _setPositionFromGlobal(Offset globalPosition) {
    final renderObject = _comparisonKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final localPosition = renderObject.globalToLocal(globalPosition);
    _setPosition(localPosition.dx / renderObject.size.width);
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.0) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('generation-image-comparison'),
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 4,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              key: _comparisonKey,
              fit: StackFit.expand,
              children: [
                // Keep the image regions disjoint so transparent pixels reveal
                // the card underlay instead of the image on the opposite side.
                ClipRect(
                  key: const ValueKey('generation-comparison-generated-clip'),
                  clipper: _ComparisonClipper(
                    _position,
                    side: _ComparisonSide.generated,
                  ),
                  child: DecodedMemoryImage(
                    key: const ValueKey('generation-comparison-generated'),
                    bytes: widget.generatedImageBytes,
                    fit: widget.fit,
                  ),
                ),
                ClipRect(
                  key: const ValueKey('generation-comparison-source-clip'),
                  clipper: _ComparisonClipper(
                    _position,
                    side: _ComparisonSide.source,
                  ),
                  child: DecodedMemoryImage(
                    key: const ValueKey('generation-comparison-source'),
                    bytes: widget.sourceImageBytes,
                    fit: widget.fit,
                  ),
                ),
                AnimatedBuilder(
                  animation: _transformationController,
                  builder: (context, _) => _buildDivider(
                    context,
                    constraints.maxWidth,
                    _transformationController.value.getMaxScaleOnAxis(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context, double width, double scale) {
    final colors = Theme.of(context).colorScheme;
    final inverseScale = scale <= 0 ? 1.0 : 1 / scale;
    final lineWidth = _dividerLineWidth * inverseScale;
    final interactionPolicy = context.interactionPolicy;
    final paintedHitWidth =
        interactionPolicy.prefersTouchPresentation &&
            _dividerHitWidth < interactionPolicy.minimumControlExtent
        ? interactionPolicy.minimumControlExtent
        : _dividerHitWidth;
    // This subtree is scaled by InteractiveViewer, so inverse-scale the local
    // hit box to preserve the required physical touch target.
    final hitWidth = (paintedHitWidth * inverseScale).clamp(0.0, width);
    final dividerX = width * _position;
    final hitLeft = (dividerX - hitWidth / 2).clamp(
      0.0,
      (width - hitWidth).clamp(0.0, double.infinity),
    );
    final percent = (_position * 100).round();

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: dividerX - lineWidth / 2,
          top: 0,
          bottom: 0,
          width: lineWidth,
          child: IgnorePointer(
            child: ColoredBox(
              key: const ValueKey('generation-comparison-divider-line'),
              color: colors.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ),
        Positioned(
          left: hitLeft,
          top: 0,
          bottom: 0,
          width: hitWidth,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _setPosition(_position - _keyboardStep),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _setPosition(_position + _keyboardStep),
            },
            child: Focus(
              focusNode: _dividerFocusNode,
              onFocusChange: (focused) {
                if (_dividerFocused != focused) {
                  setState(() => _dividerFocused = focused);
                }
              },
              child: Semantics(
                slider: true,
                label: context.l10n.generation_imageComparisonDivider,
                value: '$percent%',
                increasedValue:
                    '${((_position + _keyboardStep).clamp(0, 1) * 100).round()}%',
                decreasedValue:
                    '${((_position - _keyboardStep).clamp(0, 1) * 100).round()}%',
                onIncrease: () => _setPosition(_position + _keyboardStep),
                onDecrease: () => _setPosition(_position - _keyboardStep),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    key: const ValueKey('generation-comparison-divider-handle'),
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      _dividerFocusNode.requestFocus();
                      _setPositionFromGlobal(details.globalPosition);
                    },
                    onHorizontalDragStart: (details) {
                      _dividerFocusNode.requestFocus();
                      _setPositionFromGlobal(details.globalPosition);
                    },
                    onHorizontalDragUpdate: (details) =>
                        _setPositionFromGlobal(details.globalPosition),
                    child: Center(
                      child: Material(
                        key: const ValueKey(
                          'generation-comparison-divider-thumb',
                        ),
                        color: _dividerFocused
                            ? colors.primary
                            : colors.surfaceContainerHigh,
                        elevation: _dividerElevation * inverseScale,
                        shape: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: _dividerThumbSize * inverseScale,
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: _dividerIconSize * inverseScale,
                            color: _dividerFocused
                                ? colors.onPrimary
                                : colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ComparisonSide { source, generated }

class _ComparisonClipper extends CustomClipper<Rect> {
  const _ComparisonClipper(this.position, {required this.side});

  final double position;
  final _ComparisonSide side;

  @override
  Rect getClip(Size size) {
    final dividerX = size.width * position;
    return switch (side) {
      _ComparisonSide.generated => Rect.fromLTRB(0, 0, dividerX, size.height),
      _ComparisonSide.source => Rect.fromLTRB(
        dividerX,
        0,
        size.width,
        size.height,
      ),
    };
  }

  @override
  bool shouldReclip(covariant _ComparisonClipper oldClipper) =>
      oldClipper.position != position || oldClipper.side != side;
}
