import 'package:flutter/material.dart';

/// Keeps a mode selector on one row without clipping large text or translations.
class HorizontalSegmentedControl extends StatelessWidget {
  const HorizontalSegmentedControl({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: child,
      ),
    ),
  );
}
