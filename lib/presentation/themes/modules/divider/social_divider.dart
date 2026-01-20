/// Social Divider - Flat, no-shadow borders
/// 
/// For social app style themes:
/// - Social / Discord
library;

import 'package:flutter/material.dart';
import '../../core/divider_module.dart';

/// A divider module with flat, Discord-style dividers.
/// 
/// Simple solid borders without shadows or effects,
/// common in social media applications.
class SocialDividerModule extends BaseDividerModule {
  final Color _dividerColor;

  const SocialDividerModule({
    required Color color,
  }) : _dividerColor = color;

  /// Discord style - dark gray divider
  factory SocialDividerModule.discord() {
    return const SocialDividerModule(
      color: Color(0xFF2F3136), // Discord dark divider
    );
  }

  @override
  double get thickness => 1.0;

  @override
  Color get dividerColor => _dividerColor;
}
