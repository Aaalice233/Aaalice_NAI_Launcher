/// Glow Shadow - Neon/cyberpunk glowing effect
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';

class GlowShadow extends BaseShadowModule {
  /// The glow color for the neon effect
  final Color glowColor;

  /// Creates a glow shadow with a custom color
  const GlowShadow({this.glowColor = const Color(0xFFFF2975)});

  @override
  List<BoxShadow> get elevation1 => [
        BoxShadow(
          color: glowColor.withOpacity(0.3),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];

  @override
  List<BoxShadow> get elevation2 => [
        BoxShadow(
          color: glowColor.withOpacity(0.4),
          blurRadius: 16,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: glowColor.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: -2,
        ),
      ];

  @override
  List<BoxShadow> get elevation3 => [
        BoxShadow(
          color: glowColor.withOpacity(0.5),
          blurRadius: 24,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: glowColor.withOpacity(0.3),
          blurRadius: 16,
          spreadRadius: -4,
        ),
      ];

  @override
  List<BoxShadow> get cardShadow => elevation2;
}
