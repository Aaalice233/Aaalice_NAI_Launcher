import 'package:flutter/material.dart';

/// Local brand artwork shared by model and provider identity widgets.
class AiBrandIcon extends StatelessWidget {
  const AiBrandIcon({
    super.key,
    required this.assetName,
    this.size = 18,
    this.color,
    this.fallback = Icons.smart_toy_outlined,
  });

  final String? assetName;
  final double size;
  final Color? color;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final asset = assetName;
    final foreground = color ?? Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: asset == null
          ? Icon(fallback, size: size, color: foreground)
          : Image.asset(
              'assets/icons/ai_brands/$asset.png',
              width: size,
              height: size,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              fit: BoxFit.contain,
              color: asset.endsWith('-color') ? null : foreground,
              excludeFromSemantics: true,
            ),
    );
  }
}
