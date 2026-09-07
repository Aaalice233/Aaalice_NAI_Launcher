import 'package:flutter/material.dart';
import 'horizontal_action_strip.dart';

/// Keeps a mode selector on one row without clipping large text or translations.
class HorizontalSegmentedControl extends StatelessWidget {
  const HorizontalSegmentedControl({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => HorizontalActionStrip(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: child,
      ),
    ),
  );
}
