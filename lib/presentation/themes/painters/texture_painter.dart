/// TexturePainter - Procedural texture generation for theme overlays
///
/// A CustomPainter that generates various texture patterns programmatically
/// without requiring external image assets. Supports 4 texture types:
/// - [TextureType.paperGrain] - Random dots for paper-like texture
/// - [TextureType.dotMatrix] - Regular grid of evenly-spaced dots
/// - [TextureType.halftone] - Gradient-sized dots for print media effect
/// - [TextureType.grunge] - Irregular noise and scratches for distressed look
///
/// Reference:
/// - Paper grain: docs/UI设计提示词合集/第七套UI.txt:77-81
/// - Halftone/Grunge: docs/UI设计提示词合集/第二套UI.txt:54-61
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme_modules.dart';

/// A [CustomPainter] that renders procedural texture patterns.
///
/// The painter generates textures entirely through code, ensuring no
/// external image assets are required. All textures are deterministic
/// when the same [seed] is used.
///
/// Example usage:
/// ```dart
/// CustomPaint(
///   painter: TexturePainter(
///     type: TextureType.paperGrain,
///     color: Colors.brown,
///     opacity: 0.1,
///   ),
///   child: MyWidget(),
/// )
/// ```
class TexturePainter extends CustomPainter {
  /// The type of texture to render.
  final TextureType type;

  /// The color of the texture pattern.
  /// Defaults to a neutral gray.
  final Color color;

  /// The opacity of the texture overlay (0.0 - 1.0).
  /// Lower values create subtle textures.
  final double opacity;

  /// The density multiplier for the texture pattern.
  /// 1.0 is standard density, higher values create denser patterns.
  final double density;

  /// Random seed for consistent texture generation.
  /// Same seed produces identical patterns.
  final int seed;

  /// Creates a TexturePainter with the specified configuration.
  const TexturePainter({
    this.type = TextureType.none,
    this.color = const Color(0xFF8B8B8B),
    this.opacity = 0.1,
    this.density = 1.0,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (type == TextureType.none || opacity <= 0) return;

    switch (type) {
      case TextureType.none:
        return;
      case TextureType.paperGrain:
        _paintPaperGrain(canvas, size);
      case TextureType.dotMatrix:
        _paintDotMatrix(canvas, size);
      case TextureType.halftone:
        _paintHalftone(canvas, size);
      case TextureType.grunge:
        _paintGrunge(canvas, size);
    }
  }

  /// Paints a paper grain texture with random small dots.
  ///
  /// Creates a subtle paper-like texture by drawing randomly positioned
  /// small circles. Based on CSS: radial-gradient(#e5e0d8 1px, transparent 1px)
  /// with backgroundSize: 24px 24px (from 第七套UI.txt:77-81).
  void _paintPaperGrain(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Grid-based approach for even distribution
    // Base spacing is 24px as per design spec, adjusted by density
    final spacing = 24.0 / density;
    const dotRadius = 0.8; // Small dots for subtle grain

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Add slight randomness to position within grid cell
        final offsetX = x + (random.nextDouble() - 0.5) * spacing * 0.8;
        final offsetY = y + (random.nextDouble() - 0.5) * spacing * 0.8;

        // Random size variation for natural feel
        final radius = dotRadius * (0.5 + random.nextDouble() * 0.5);

        // Only draw ~70% of dots for natural variation
        if (random.nextDouble() > 0.3) {
          canvas.drawCircle(Offset(offsetX, offsetY), radius, paint);
        }
      }
    }
  }

  /// Paints a regular dot matrix pattern.
  ///
  /// Creates a grid of evenly spaced dots, similar to LED matrix displays
  /// or perforated patterns.
  void _paintDotMatrix(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Regular grid spacing adjusted by density
    final spacing = 16.0 / density;
    const dotRadius = 1.5;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  /// Paints a halftone pattern with gradient-sized dots.
  ///
  /// Creates a print-media effect where dot sizes vary based on position,
  /// simulating halftone printing techniques used in comics and newspapers.
  /// Reference: 第二套UI.txt:57 - "halftone patterns for printed, comic-book feel"
  void _paintHalftone(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Larger spacing for halftone effect
    final spacing = 12.0 / density;
    const maxRadius = 3.0;
    const minRadius = 0.5;

    // Calculate center for radial gradient effect
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxDistance = math.sqrt(centerX * centerX + centerY * centerY);

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        // Calculate distance from center (normalized 0-1)
        final dx = x - centerX;
        final dy = y - centerY;
        final distance = math.sqrt(dx * dx + dy * dy) / maxDistance;

        // Dot size varies based on distance from center
        // Larger dots at center, smaller at edges
        final sizeMultiplier = 1.0 - (distance * 0.7);
        final radius = minRadius + (maxRadius - minRadius) * sizeMultiplier;

        // Add slight randomness for organic feel
        final jitterX = (random.nextDouble() - 0.5) * 1.0;
        final jitterY = (random.nextDouble() - 0.5) * 1.0;

        canvas.drawCircle(
          Offset(x + jitterX, y + jitterY),
          radius * (0.8 + random.nextDouble() * 0.4),
          paint,
        );
      }
    }
  }

  /// Paints a grunge texture with irregular noise and scratches.
  ///
  /// Creates a distressed, worn look with random particles, lines,
  /// and splatters. Reference: 第二套UI.txt:55 - "scratched film, dust, and ink splatters"
  void _paintGrunge(Canvas canvas, Size size) {
    final random = math.Random(seed);

    // Layer 1: Random dust particles
    _paintDustParticles(canvas, size, random);

    // Layer 2: Random scratches/lines
    _paintScratches(canvas, size, random);

    // Layer 3: Ink splatters (larger irregular shapes)
    _paintSplatters(canvas, size, random);
  }

  /// Draws random dust particles for grunge texture.
  void _paintDustParticles(Canvas canvas, Size size, math.Random random) {
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.fill;

    // Number of particles scales with area and density
    final particleCount = (size.width * size.height / 400 * density).round();

    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.3 + random.nextDouble() * 1.2;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  /// Draws random scratches/lines for grunge texture.
  void _paintScratches(Canvas canvas, Size size, math.Random random) {
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 + random.nextDouble() * 0.5
      ..strokeCap = StrokeCap.round;

    // Number of scratches
    final scratchCount = (10 * density).round();

    for (int i = 0; i < scratchCount; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;

      // Short to medium length scratches
      final length = 10 + random.nextDouble() * 40;
      final angle = random.nextDouble() * math.pi * 2;

      final endX = startX + math.cos(angle) * length;
      final endY = startY + math.sin(angle) * length;

      // Create slightly curved scratch using path
      final path = Path();
      path.moveTo(startX, startY);

      // Add slight curve
      final midX = (startX + endX) / 2 + (random.nextDouble() - 0.5) * 5;
      final midY = (startY + endY) / 2 + (random.nextDouble() - 0.5) * 5;
      path.quadraticBezierTo(midX, midY, endX, endY);

      canvas.drawPath(path, paint);
    }
  }

  /// Draws ink splatters for grunge texture.
  void _paintSplatters(Canvas canvas, Size size, math.Random random) {
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.3)
      ..style = PaintingStyle.fill;

    // Fewer but larger splatters
    final splatterCount = (5 * density).round();

    for (int i = 0; i < splatterCount; i++) {
      final centerX = random.nextDouble() * size.width;
      final centerY = random.nextDouble() * size.height;

      // Draw splatter as cluster of overlapping circles
      final clusterSize = 3 + random.nextInt(5);
      for (int j = 0; j < clusterSize; j++) {
        final offsetX = centerX + (random.nextDouble() - 0.5) * 8;
        final offsetY = centerY + (random.nextDouble() - 0.5) * 8;
        final radius = 1 + random.nextDouble() * 3;

        canvas.drawCircle(Offset(offsetX, offsetY), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TexturePainter oldDelegate) {
    return type != oldDelegate.type ||
        color != oldDelegate.color ||
        opacity != oldDelegate.opacity ||
        density != oldDelegate.density ||
        seed != oldDelegate.seed;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TexturePainter &&
        other.type == type &&
        other.color == color &&
        other.opacity == opacity &&
        other.density == density &&
        other.seed == seed;
  }

  @override
  int get hashCode => Object.hash(type, color, opacity, density, seed);
}
