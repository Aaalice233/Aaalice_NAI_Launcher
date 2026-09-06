import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import 'image_viewport_surface.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/image_comparison_preferences_provider.dart';
import 'image_comparison_toolbar.dart';

/// Synchronized before/after image comparison with a draggable divider.
class ImageComparisonView extends ConsumerStatefulWidget {
  const ImageComparisonView({
    super.key,
    required this.sourceImageBytes,
    required this.generatedImageBytes,
    this.fit = BoxFit.cover,
    this.showPixelScaleControls = false,
    this.viewportHeight,
  });

  final Uint8List sourceImageBytes;
  final Uint8List generatedImageBytes;
  final BoxFit fit;
  final bool showPixelScaleControls;
  final double? viewportHeight;

  @override
  ConsumerState<ImageComparisonView> createState() =>
      _ImageComparisonViewState();
}

class _ImageComparisonViewState extends ConsumerState<ImageComparisonView> {
  static const _keyboardStep = 0.05;
  static const _doubleTapScale = 2.0;
  static const _dividerLineWidth = 1.0;
  static const _dividerHitWidth = 48.0;
  static const _dividerThumbSize = 28.0;
  static const _dividerIconSize = 16.0;
  static const _dividerElevation = 2.0;

  final _viewportKey = GlobalKey();
  final _dividerFocusNode = FocusNode(
    debugLabel: 'generation-image-comparison-divider',
  );
  final _transformationController = TransformationController();

  final _dividerPosition = ValueNotifier<double>(0.5);
  final _viewportChanges = ValueNotifier<Size?>(null);
  late final Listenable _dividerChanges;
  late final Listenable _toolbarChanges;
  double get _position => _dividerPosition.value;
  bool get _followMouse => ref.read(imageComparisonFollowMouseProvider);
  Offset? _mousePosition;
  bool _dividerFocused = false;
  TapDownDetails? _doubleTapDetails;
  Size? _generatedSize;
  Size? _viewportSize;

  @override
  void initState() {
    super.initState();
    _dividerChanges = Listenable.merge([
      _dividerPosition,
      _transformationController,
    ]);
    _transformationController.addListener(_followMouseAfterTransform);
    _toolbarChanges = Listenable.merge([
      _transformationController,
      _viewportChanges,
    ]);
    _readGeneratedSize();
  }

  void _readGeneratedSize() {
    final info = widget.showPixelScaleControls
        ? img
              .findDecoderForData(widget.generatedImageBytes)
              ?.startDecode(widget.generatedImageBytes)
        : null;
    _generatedSize = info == null
        ? null
        : Size(info.width.toDouble(), info.height.toDouble());
  }

  @override
  void didUpdateWidget(covariant ImageComparisonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sourceImageBytes, widget.sourceImageBytes) ||
        !identical(oldWidget.generatedImageBytes, widget.generatedImageBytes) ||
        oldWidget.showPixelScaleControls != widget.showPixelScaleControls) {
      // A new enhancement of the same source must not change the viewport.
      if (!identical(oldWidget.sourceImageBytes, widget.sourceImageBytes)) {
        _dividerPosition.value = 0.5;
        _transformationController.value = Matrix4.identity();
      }
      _readGeneratedSize();
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_followMouseAfterTransform);
    _dividerPosition.dispose();
    _viewportChanges.dispose();
    _dividerFocusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _setPosition(double position) {
    final next = position.clamp(0.0, 1.0);
    if (next == _position) return;
    _dividerPosition.value = next;
  }

  void _setPositionFromGlobal(Offset globalPosition) {
    final renderObject = _viewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    // Convert from the fixed viewport into image coordinates. This also works
    // in the transform listener before the next frame updates render objects.
    final localPosition = _transformationController.toScene(
      renderObject.globalToLocal(globalPosition),
    );
    _setPosition(localPosition.dx / renderObject.size.width);
  }

  void _followMouseAfterTransform() {
    final position = _mousePosition;
    if (_followMouse && position != null) _setPositionFromGlobal(position);
  }

  void _onHover(PointerHoverEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    _mousePosition = event.position;
    if (_followMouse) _setPositionFromGlobal(event.position);
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (widget.showPixelScaleControls) {
      _setScale((currentScale - 1).abs() < 0.001 ? _actualPixelScale : 1);
      return;
    }
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Column(
      mainAxisSize: widget.viewportHeight == null
          ? MainAxisSize.max
          : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.viewportHeight == null)
          Expanded(child: _buildViewport(context))
        else
          SizedBox(
            height: widget.viewportHeight,
            child: _buildViewport(context),
          ),
        AnimatedBuilder(
          animation: _toolbarChanges,
          builder: (context, _) => ImageComparisonToolbar(
            followMouse: ref.watch(imageComparisonFollowMouseProvider),
            onFollowMouseChanged: (value) => ref
                .read(imageComparisonFollowMouseProvider.notifier)
                .setEnabled(value),
            showZoom: widget.showPixelScaleControls,
            scale: _transformationController.value.getMaxScaleOnAxis(),
            actualPixelScale: _actualPixelScale,
            canUseActualPixels: _generatedSize != null,
            onScaleChanged: (scale) => _setScale(
              scale.clamp(
                math.min(1, _actualPixelScale),
                math.max(4, _actualPixelScale * 4),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  double get _actualPixelScale {
    final imageSize = _generatedSize;
    final viewport = _viewportSize;
    if (imageSize == null || viewport == null || viewport.isEmpty) return 1;
    final destination = applyBoxFit(
      widget.fit,
      imageSize,
      viewport,
    ).destination;
    return imageSize.width /
        (destination.width * MediaQuery.devicePixelRatioOf(context));
  }

  void _setScale(double scale) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width * (1 - scale) / 2,
        viewport.height * (1 - scale) / 2,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }

  Widget _buildViewport(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_viewportSize != size) {
        _viewportSize = size;
        // The footer is laid out before the flexible viewport. Publish the
        // resolved size after layout without rebuilding the image subtree.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _viewportChanges.value = _viewportSize;
        });
      }
      return ColoredBox(
        color: ImageViewportSurface.background,
        child: MouseRegion(
          key: _viewportKey,
          onHover: _onHover,
          onExit: (_) => _mousePosition = null,
          child: _buildComparison(context),
        ),
      );
    },
  );

  Widget _buildComparison(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('generation-image-comparison'),
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        onInteractionStart: (_) => _mousePosition = null,
        minScale: math.min(1, _actualPixelScale),
        maxScale: math.max(4, _actualPixelScale * 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Keep the image regions disjoint so transparent pixels reveal
                // the card underlay instead of the image on the opposite side.
                ClipRect(
                  key: const ValueKey('generation-comparison-generated-clip'),
                  clipper: _ComparisonClipper(
                    _dividerPosition,
                    side: _ComparisonSide.generated,
                  ),
                  // A comparison is a detail viewer: decoding a thumbnail here
                  // permanently loses detail when InteractiveViewer zooms in.
                  child: RepaintBoundary(
                    child: Image.memory(
                      key: const ValueKey('generation-comparison-generated'),
                      widget.generatedImageBytes,
                      fit: widget.fit,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                ClipRect(
                  key: const ValueKey('generation-comparison-source-clip'),
                  clipper: _ComparisonClipper(
                    _dividerPosition,
                    side: _ComparisonSide.source,
                  ),
                  child: RepaintBoundary(
                    child: Image.memory(
                      key: const ValueKey('generation-comparison-source'),
                      widget.sourceImageBytes,
                      fit: widget.fit,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _dividerChanges,
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
    final showFocus =
        _dividerFocused && interactionPolicy.keyboardNavigationActive;
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
                  cursor: _followMouse
                      ? MouseCursor.defer
                      : SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    key: const ValueKey('generation-comparison-divider-handle'),
                    behavior: HitTestBehavior.translucent,
                    // Hover places the divider under the mouse. Its recognizers
                    // must leave mouse drags to the viewport in follow mode.
                    supportedDevices: _followMouse
                        ? {
                            for (final kind in PointerDeviceKind.values)
                              if (kind != PointerDeviceKind.mouse) kind,
                          }
                        : null,
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
                        color: showFocus
                            ? colors.primary
                            : colors.surfaceContainerHigh,
                        elevation: _dividerElevation * inverseScale,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            14 * inverseScale,
                          ),
                        ),
                        child: SizedBox(
                          width: _dividerThumbSize * inverseScale,
                          height: 40 * inverseScale,
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: _dividerIconSize * inverseScale,
                            color: showFocus
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
  _ComparisonClipper(this.position, {required this.side})
    : super(reclip: position);

  final ValueListenable<double> position;
  final _ComparisonSide side;

  @override
  Rect getClip(Size size) {
    final dividerX = size.width * position.value;
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
