/// Glassmorphism Effect - Frosted glass
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class GlassmorphismEffect extends BaseEffectModule {
  const GlassmorphismEffect();

  @override
  bool get enableGlassmorphism => true;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => TextureType.none;

  @override
  Color? get glowColor => null;

  @override
  double get blurStrength => 12.0;
}
