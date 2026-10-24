import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';
import 'image_card_controller.dart';
import 'image_card_frame.dart';
import 'image_card_models.dart';
import 'image_card_stream_preview.dart';
import 'image_postprocess_indicator.dart';

const _streamProgressForeground = Colors.white;

/// Shared 24 FPS clock for all active [ImageCardGenerating] instances.
/// Avoids running multiple unconstrained 240Hz VSync Tickers that force
/// full-window D3D11/ANGLE redraws 240 times per second on Windows desktop.
class _SharedGenerationAnimationClock extends ChangeNotifier {
  _SharedGenerationAnimationClock._();
  static final _SharedGenerationAnimationClock instance =
      _SharedGenerationAnimationClock._();

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _listenerCount = 0;

  int get elapsedMs => _stopwatch.elapsedMilliseconds;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listenerCount++;
    if (_listenerCount == 1) {
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 42), (_) {
        notifyListeners();
      });
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_listenerCount > 0) {
      _listenerCount--;
      if (_listenerCount == 0) {
        _timer?.cancel();
        _timer = null;
        _stopwatch.stop();
      }
    }
  }
}

class ImageCardGenerating extends StatelessWidget {
  const ImageCardGenerating({
    super.key,
    required this.data,
    required this.controller,
  });

  final ImageCardViewData data;
  final ImageCardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPreview = data.streamPreview?.isNotEmpty == true;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final cardContent = Container(
      decoration: BoxDecoration(
        color: hasPreview ? null : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(ImageCardFrame.defaultRadius),
      ),
      child: hasPreview
          ? _preview(context)
          : data.postprocessPhase != null
          ? ImagePostprocessIndicator(phase: data.postprocessPhase!)
          : _loading(context, theme),
    );

    if (reducedMotion || controller.glowAnimation == null) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: _CachedBreathingGlow(
                color: theme.colorScheme.primary,
                staticOpacity: 0.06,
              ),
            ),
            RepaintBoundary(child: cardContent),
          ],
        ),
      );
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: _CachedBreathingGlow(color: theme.colorScheme.primary),
          ),
          RepaintBoundary(child: cardContent),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final progress = data.progress ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ImageCardFrame.defaultRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _streamPreview(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          if (data.postprocessPhase != null)
            ImagePostprocessIndicator(phase: data.postprocessPhase!)
          else
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: _SmoothGeneratingSpinner(
                        key: const ValueKey('stream-generation-progress-ring'),
                        value: progress > 0
                            ? progress
                            : MediaQuery.disableAnimationsOf(context)
                            ? 0.72
                            : null,
                        strokeWidth: 2,
                        backgroundColor: _streamProgressForeground.withValues(
                          alpha: 0.24,
                        ),
                        color: _streamProgressForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${data.currentImage ?? 0}/${data.totalImages ?? 0}',
                    key: const ValueKey('stream-generation-progress-count'),
                    style: _progressStyle(),
                  ),
                  const SizedBox(width: 8),
                  if (progress > 0)
                    Text(
                      '${(progress * 100).toInt()}%',
                      key: const ValueKey('stream-generation-progress-percent'),
                      style: _progressStyle(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _streamPreview() => ImageCardStreamPreview(
    previewBytes: data.streamPreview!,
    placement: data.focusedPreviewPlacement,
  );

  Widget _loading(BuildContext context, ThemeData theme) {
    final progress = data.progress ?? 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RepaintBoundary(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: _SmoothGeneratingSpinner(
                    value: progress > 0
                        ? progress
                        : MediaQuery.disableAnimationsOf(context)
                        ? 0.72
                        : null,
                    strokeWidth: 2.5,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : theme.appTheme.fastDuration,
              child: Text(
                '${data.currentImage ?? 0}',
                key: ValueKey(data.currentImage ?? 0),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  height: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '/',
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  height: 1,
                ),
              ),
            ),
            Text(
              '${data.totalImages ?? 0}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _progressStyle() => const TextStyle(
    color: _streamProgressForeground,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    shadows: [
      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
    ],
  );
}

/// Renders the exact 18px Gaussian blur glow around a 12px rounded rectangle
/// by baking the blur once into a 9-slice [ui.Image] texture and drawing it
/// with vertex alpha modulation (zero Canvas::saveLayer and zero per-frame
/// GaussianBlur1D / GrDirectContext::deleteBackendTexture calls).
class _CachedBreathingGlow extends StatelessWidget {
  const _CachedBreathingGlow({required this.color, this.staticOpacity});

  final Color color;
  final double? staticOpacity;

  static int? _cachedColorValue;
  static ui.Image? _cachedGlowImage;

  static const double _pad = 36.0;
  static const int _texSize = 160;
  static const Rect _centerSlice = Rect.fromLTRB(64, 64, 96, 96);

  static ui.Image _ensureGlowImage(Color baseColor) {
    final argb = baseColor.toARGB32();
    if (_cachedGlowImage != null && _cachedColorValue == argb) {
      return _cachedGlowImage!;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(
        _pad,
        _pad,
        _texSize - _pad,
        _texSize - _pad,
      ),
      const Radius.circular(12),
    );
    final paint = BoxShadow(
      color: Color(argb),
      blurRadius: 18,
    ).toPaint();
    canvas.drawRRect(rrect, paint);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_texSize, _texSize);
    picture.dispose();
    _cachedGlowImage?.dispose();
    _cachedGlowImage = image;
    _cachedColorValue = argb;
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final image = _ensureGlowImage(color);
    return CustomPaint(
      painter: _BreathingGlowNinePatchPainter(
        image: image,
        staticOpacity: staticOpacity,
        repaint: staticOpacity == null
            ? _SharedGenerationAnimationClock.instance
            : null,
      ),
    );
  }
}

class _BreathingGlowNinePatchPainter extends CustomPainter {
  _BreathingGlowNinePatchPainter({
    required this.image,
    required this.staticOpacity,
    super.repaint,
  });

  final ui.Image image;
  final double? staticOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity;
    if (staticOpacity != null) {
      opacity = staticOpacity!;
    } else {
      final ms = _SharedGenerationAnimationClock.instance.elapsedMs;
      // 2000ms reverse period -> 4000ms full cycle, matching Curve.easeInOut 0.04..0.10
      final phase = (ms % 4000) / 2000.0;
      final t = phase <= 1.0 ? phase : 2.0 - phase;
      final curved = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
      opacity = 0.04 + (0.10 - 0.04) * curved;
    }

    const pad = _CachedBreathingGlow._pad;
    final dst = Rect.fromLTRB(-pad, -pad, size.width + pad, size.height + pad);
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
      ..filterQuality = FilterQuality.low;
    canvas.drawImageNine(
      image,
      _CachedBreathingGlow._centerSlice,
      dst,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BreathingGlowNinePatchPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.staticOpacity != staticOpacity;
}

/// Indeterminate/determinate circular progress indicator driven by
/// [_SharedGenerationAnimationClock] (24 FPS) instead of a 240Hz VSync Ticker.
class _SmoothGeneratingSpinner extends StatelessWidget {
  const _SmoothGeneratingSpinner({
    super.key,
    required this.value,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.color,
  });

  final double? value;
  final double strokeWidth;
  final Color backgroundColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SmoothGeneratingSpinnerPainter(
        value: value,
        strokeWidth: strokeWidth,
        backgroundColor: backgroundColor,
        color: color,
        repaint: value == null
            ? _SharedGenerationAnimationClock.instance
            : null,
      ),
    );
  }
}

class _SmoothGeneratingSpinnerPainter extends CustomPainter {
  _SmoothGeneratingSpinnerPainter({
    required this.value,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.color,
    super.repaint,
  });

  final double? value;
  final double strokeWidth;
  final Color backgroundColor;
  final Color color;

  static const Curve _headCurve = Interval(
    0.0,
    0.5,
    curve: Curves.fastOutSlowIn,
  );
  static const Curve _tailCurve = Interval(
    0.5,
    1.0,
    curve: Curves.fastOutSlowIn,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (backgroundColor.a > 0) {
      final trackPaint = Paint()
        ..color = backgroundColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    }

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = value == null ? StrokeCap.square : StrokeCap.butt;

    if (value != null) {
      const startAngle = -math.pi / 2;
      final sweepAngle = value!.clamp(0.0, 1.0) * math.pi * 2;
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
      return;
    }

    final ms = _SharedGenerationAnimationClock.instance.elapsedMs;
    final cycle = (ms % 1333) / 1333.0;
    final headValue = _headCurve.transform(cycle);
    final tailValue = _tailCurve.transform(cycle);
    final rotation = ((ms % 2222) / 2222.0) * math.pi * 2;

    final startAngle =
        -math.pi / 2 + rotation + tailValue * 1.5 * math.pi;
    final sweepAngle = math.max(
      0.15,
      (headValue - tailValue) * 1.5 * math.pi,
    );
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SmoothGeneratingSpinnerPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.color != color;
}
