/// None Divider - No visible dividers
///
/// For themes that use whitespace or color blocks instead of lines:
/// - Flat Design
/// - Fluid Saturated
/// - Bold Retro
/// - Midnight Editorial
library;

import 'package:flutter/material.dart';
import '../../core/divider_module.dart';

/// A divider module that renders nothing.
///
/// Used for themes where separation is achieved through
/// whitespace, color blocking, or other non-linear means.
class NoneDividerModule implements DividerModule {
  const NoneDividerModule();

  @override
  bool get useDivider => false;

  @override
  double get thickness => 0;

  @override
  Color get dividerColor => Colors.transparent;

  @override
  BoxDecoration? get horizontalDecoration => null;

  @override
  BoxDecoration? get verticalDecoration => null;

  @override
  BoxDecoration panelBorder({
    bool top = false,
    bool right = false,
    bool bottom = false,
    bool left = false,
  }) {
    return const BoxDecoration();
  }
}
