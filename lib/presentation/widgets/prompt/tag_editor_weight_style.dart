import 'package:flutter/material.dart';

/// Weight is a semantic overlay; neutral theme surfaces remain the base layer.
class TagEditorWeightStyle {
  const TagEditorWeightStyle(this.color);

  final Color color;

  Color surface(Color base, {bool group = false}) => Color.alphaBlend(
    color.withValues(alpha: color.a * (group ? 0.42 : 0.58)),
    base,
  );

  Color accent(ThemeData theme) => Color.alphaBlend(
    color.withValues(alpha: theme.brightness == Brightness.dark ? 0.55 : 0.65),
    theme.colorScheme.onSurface,
  );
}
