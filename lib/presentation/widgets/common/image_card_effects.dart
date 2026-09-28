import 'dart:math' as math;

import 'package:flutter/material.dart';

class ImageCardEffects extends StatelessWidget {
  const ImageCardEffects({
    super.key,
    required this.glowColor,
    required this.glowIntensity,
    required this.glossProgress,
  });

  final Color glowColor;
  final double glowIntensity;
  final double glossProgress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: ImageCardEdgeGlowPainter(
              glowColor: glowColor,
              intensity: glowIntensity,
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: ImageCardGlossPainter(progress: glossProgress),
            ),
          ),
        ],
      ),
    );
  }
}

class ImageCardEdgeGlowPainter extends CustomPainter {
  ImageCardEdgeGlowPainter({required this.glowColor, required this.intensity});

  final Color glowColor;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (var index = 0; index < 3; index++) {
      final inset = (index + 1) * 1.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(inset),
          Radius.circular(math.max(0, 12 - inset)),
        ),
        Paint()
          ..color = glowColor.withValues(
            alpha: 0.12 * intensity * (3 - index) / 3,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, (3 - index) * 2),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..color = glowColor.withValues(alpha: 0.25 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    final highlightPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.3 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    const cornerOffset = 16.0;
    for (final corner in [
      const Offset(cornerOffset, cornerOffset),
      Offset(size.width - cornerOffset, cornerOffset),
      Offset(cornerOffset, size.height - cornerOffset),
      Offset(size.width - cornerOffset, size.height - cornerOffset),
    ]) {
      canvas.drawCircle(corner, 3, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ImageCardEdgeGlowPainter oldDelegate) =>
      oldDelegate.glowColor != glowColor || oldDelegate.intensity != intensity;
}

class ImageCardGlossPainter extends CustomPainter {
  ImageCardGlossPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shaderRect = Rect.fromLTWH(
      size.width * progress - size.width * 0.5,
      size.height * progress - size.height * 0.5,
      size.width,
      size.height,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0, 0.35, 0.5, 0.65, 1],
        ).createShader(shaderRect),
    );

    final pearlShaderRect = Rect.fromLTWH(
      size.width * progress - size.width * 0.6,
      size.height * progress - size.height * 0.6,
      size.width * 1.2,
      size.height * 1.2,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            const Color(0xFFB8E6F5).withValues(alpha: 0.03),
            const Color(0xFFFFF5E1).withValues(alpha: 0.05),
            const Color(0xFFE6B8F5).withValues(alpha: 0.03),
            Colors.transparent,
          ],
          stops: const [0, 0.3, 0.5, 0.7, 1],
        ).createShader(pearlShaderRect)
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(covariant ImageCardGlossPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
