/// None Effect - No special effects
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/effect_module.dart';

class NoneEffect extends BaseEffectModule {
  const NoneEffect();

  @override
  bool get enableGlassmorphism => false;

  @override
  bool get enableNeonGlow => false;

  @override
  TextureType get textureType => TextureType.none;

  @override
  Color? get glowColor => null;

  @override
  double get blurStrength => 0.0;
}
