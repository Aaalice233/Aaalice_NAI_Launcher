import 'package:flutter/material.dart';

/// A neutral surround keeps image viewing independent of the application theme.
/// Transparency checkers and user-selected image backdrops are painted above it.
class ImageViewportSurface extends StatelessWidget {
  const ImageViewportSurface({super.key, required this.child});

  static const background = Color(0xFF141414);
  static const foreground = Color(0xFFF0F0F0);
  static const mutedForeground = Color(0xFFBDBDBD);

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: foreground),
      child: IconTheme.merge(
        data: const IconThemeData(color: foreground),
        child: child,
      ),
    ),
  );
}
