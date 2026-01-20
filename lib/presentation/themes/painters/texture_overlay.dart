/// TextureOverlay - Reusable widget for texture overlays
///
/// A widget that overlays a procedural texture on top of its child.
/// Uses [TexturePainter] internally to render the texture pattern.
///
/// Example usage:
/// ```dart
/// TextureOverlay(
///   type: TextureType.paperGrain,
///   opacity: 0.1,
///   child: Card(
///     child: Text('Content with paper texture'),
///   ),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../core/theme_modules.dart';
import 'texture_painter.dart';

/// A widget that applies a texture overlay on top of its child.
///
/// The texture is rendered using [TexturePainter] and positioned
/// to cover the entire child widget area.
///
/// For [TextureType.none], the overlay is not rendered at all,
/// making it safe to use conditionally without performance impact.
class TextureOverlay extends StatelessWidget {
  /// The child widget to overlay the texture on.
  final Widget child;

  /// The type of texture to apply.
  final TextureType type;

  /// The color of the texture pattern.
  /// If null, uses the default color from [TexturePainter].
  final Color? color;

  /// The opacity of the texture overlay (0.0 - 1.0).
  /// Default is 0.1 for subtle effect.
  final double opacity;

  /// The density multiplier for the texture pattern.
  /// 1.0 is standard density.
  final double density;

  /// Random seed for consistent texture generation.
  final int seed;

  /// Creates a TextureOverlay widget.
  ///
  /// The [child] parameter is required and will be rendered beneath
  /// the texture overlay.
  ///
  /// Set [type] to [TextureType.none] to disable the overlay entirely.
  const TextureOverlay({
    super.key,
    required this.child,
    this.type = TextureType.none,
    this.color,
    this.opacity = 0.1,
    this.density = 1.0,
    this.seed = 42,
  });

  @override
  Widget build(BuildContext context) {
    // Skip overlay entirely for none type or zero opacity
    if (type == TextureType.none || opacity <= 0) {
      return child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: TexturePainter(
                type: type,
                color: color ?? const Color(0xFF8B8B8B),
                opacity: opacity,
                density: density,
                seed: seed,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Extension methods for easy texture overlay application.
extension TextureOverlayExtension on Widget {
  /// Wraps this widget with a [TextureOverlay].
  ///
  /// Example:
  /// ```dart
  /// Card(child: content).withTexture(TextureType.paperGrain)
  /// ```
  Widget withTexture(
    TextureType type, {
    Color? color,
    double opacity = 0.1,
    double density = 1.0,
    int seed = 42,
  }) {
    return TextureOverlay(
      type: type,
      color: color,
      opacity: opacity,
      density: density,
      seed: seed,
      child: this,
    );
  }
}
